from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1


def empty_profile() -> dict[str, Any]:
    return {
        "version": SCHEMA_VERSION,
        "last_updated": date.today().isoformat(),
        "rules": [],
        "lexical_preferences": {"avoid": [], "prefer": []},
        "structural_notes": [],
        "history": [],
    }


class VoiceProfile:
    """Loads, saves, and updates the human-readable voice profile JSON file."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.data: dict[str, Any] = self._load()

    def _load(self) -> dict[str, Any]:
        if not self.path.exists():
            return empty_profile()
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return empty_profile()
        if not isinstance(loaded, dict) or not loaded.get("rules") and "rules" not in loaded:
            return empty_profile()
        loaded.setdefault("version", SCHEMA_VERSION)
        loaded.setdefault("rules", [])
        loaded.setdefault("lexical_preferences", {"avoid": [], "prefer": []})
        loaded.setdefault("structural_notes", [])
        loaded.setdefault("history", [])
        return loaded

    def reload(self) -> None:
        self.data = self._load()

    def save(self) -> None:
        self.data["last_updated"] = date.today().isoformat()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    def is_empty(self) -> bool:
        return not self.data.get("rules") and not self.data.get("lexical_preferences", {}).get(
            "avoid"
        )

    def next_rule_id(self) -> str:
        existing = [r.get("id", "") for r in self.data.get("rules", [])]
        numbers = []
        for rule_id in existing:
            if rule_id.startswith("rule_"):
                try:
                    numbers.append(int(rule_id.split("_", 1)[1]))
                except ValueError:
                    continue
        next_number = (max(numbers) + 1) if numbers else 1
        return f"rule_{next_number:03d}"

    def find_similar_rule(self, description: str) -> dict[str, Any] | None:
        normalized = description.strip().lower()
        for rule in self.data.get("rules", []):
            if rule.get("description", "").strip().lower() == normalized:
                return rule
        return None

    def find_rule_by_id(self, rule_id: str) -> dict[str, Any] | None:
        for rule in self.data.get("rules", []):
            if rule.get("id") == rule_id:
                return rule
        return None

    def rules_context_for_matching(self) -> str:
        """Render existing rules as 'id: description' lines for the classify prompt."""
        rules = self.data.get("rules", [])
        if not rules:
            return "(none yet)"
        return "\n".join(f"- {r.get('id')}: {r.get('description', '')}" for r in rules)

    def apply_rule_updates(
        self, rule_updates: list[dict[str, Any]], article_id: str
    ) -> list[dict[str, Any]]:
        """Apply proposed rule updates from the classifier.

        Returns a list of actions taken, one per absorbed update:
        {"action": "new" | "reinforced", "id": ..., "description": ..., "source_count": ...}
        """
        actions: list[dict[str, Any]] = []
        for update in rule_updates:
            description = (update.get("description") or "").strip()
            if not description:
                continue

            matched_rule_id = (update.get("matched_rule_id") or "").strip()
            existing = (
                self.find_rule_by_id(matched_rule_id) if matched_rule_id else None
            ) or self.find_similar_rule(description)
            if existing is not None:
                existing["source_count"] = int(existing.get("source_count", 1)) + 1
                existing["confidence"] = _confidence_for_count(existing["source_count"])
                if update.get("example_before") and update.get("example_after"):
                    existing["example_before"] = update["example_before"]
                    existing["example_after"] = update["example_after"]
                actions.append(
                    {
                        "action": "reinforced",
                        "id": existing["id"],
                        "description": existing["description"],
                        "source_count": existing["source_count"],
                        "confidence": existing["confidence"],
                    }
                )
            else:
                new_rule = {
                    "id": self.next_rule_id(),
                    "description": description,
                    "example_before": update.get("example_before", ""),
                    "example_after": update.get("example_after", ""),
                    "category": update.get("category", "tone"),
                    "confidence": "low",
                    "source_count": 1,
                }
                self.data.setdefault("rules", []).append(new_rule)
                actions.append(
                    {
                        "action": "new",
                        "id": new_rule["id"],
                        "description": new_rule["description"],
                        "source_count": 1,
                        "confidence": "low",
                    }
                )

        self.data.setdefault("history", []).append(
            {
                "date": date.today().isoformat(),
                "article_id": article_id,
                "edits_absorbed": len(actions),
            }
        )
        return actions

    def rules_as_json(self) -> str:
        return json.dumps(self.data.get("rules", []), indent=2, ensure_ascii=False)

    def replace_with_clusters(
        self, clusters: list[dict[str, Any]]
    ) -> tuple[int, list[dict[str, Any]]]:
        """Rebuild the rules list from consolidation clusters.

        Returns (new_rule_count, merges) where merges lists only clusters that
        actually combined more than one prior rule:
        {"id": ..., "description": ..., "confidence": ..., "source_count": ...,
         "merged_from_count": <number of prior rules combined>}
        """
        rules_by_id = {r["id"]: r for r in self.data.get("rules", []) if r.get("id")}
        seen_ids: set[str] = set()
        new_rules: list[dict[str, Any]] = []
        merges: list[dict[str, Any]] = []

        for index, cluster in enumerate(clusters, start=1):
            source_ids = [
                rid for rid in cluster.get("source_rule_ids", []) if rid in rules_by_id
            ]
            if not source_ids:
                continue

            merged_count = sum(
                int(rules_by_id[rid].get("source_count", 1)) for rid in source_ids
            )
            description = (cluster.get("description") or "").strip()
            if not description:
                description = rules_by_id[source_ids[0]].get("description", "")

            new_rule = {
                "id": f"rule_{index:03d}",
                "description": description,
                "example_before": cluster.get("example_before")
                or rules_by_id[source_ids[0]].get("example_before", ""),
                "example_after": cluster.get("example_after")
                or rules_by_id[source_ids[0]].get("example_after", ""),
                "category": cluster.get("category")
                or rules_by_id[source_ids[0]].get("category", "tone"),
                "confidence": _confidence_for_count(merged_count),
                "source_count": merged_count,
            }
            new_rules.append(new_rule)
            seen_ids.update(source_ids)

            if len(source_ids) > 1:
                merges.append(
                    {
                        "id": new_rule["id"],
                        "description": new_rule["description"],
                        "confidence": new_rule["confidence"],
                        "source_count": new_rule["source_count"],
                        "merged_from_count": len(source_ids),
                    }
                )

        # Any rule the model failed to place in a cluster is kept, renumbered to
        # continue after the consolidated ones, so consolidation never drops data
        # or collides with a freshly assigned cluster id.
        next_index = len(new_rules) + 1
        for rule_id, rule in rules_by_id.items():
            if rule_id not in seen_ids:
                rule = dict(rule)
                rule["id"] = f"rule_{next_index:03d}"
                new_rules.append(rule)
                next_index += 1

        self.data["rules"] = new_rules
        return len(new_rules), merges

    def add_lexical_avoid(self, phrases: list[str]) -> None:
        avoid = self.data.setdefault("lexical_preferences", {"avoid": [], "prefer": []}).setdefault(
            "avoid", []
        )
        for phrase in phrases:
            phrase = phrase.strip().lower()
            if phrase and phrase not in avoid:
                avoid.append(phrase)

    def as_prompt_context(self) -> str:
        """Render the profile as a compact text block for prompt injection."""
        if self.is_empty():
            return "(No voice profile yet — no learned rules to apply.)"

        lines: list[str] = []
        rules = sorted(
            self.data.get("rules", []),
            key=lambda r: int(r.get("source_count", 0)),
            reverse=True,
        )
        mandatory = [r for r in rules if r.get("confidence") == "high"]
        situational = [r for r in rules if r.get("confidence") != "high"]

        def _format(rule, with_confidence: bool) -> str:
            prefix = f"[{rule.get('confidence', 'low')}] " if with_confidence else ""
            example = (
                f" (e.g. \"{rule['example_before']}\" -> \"{rule['example_after']}\")"
                if rule.get("example_before") and rule.get("example_after")
                else ""
            )
            return f"- {prefix}{rule.get('description', '')}{example}"

        if mandatory:
            lines.append(
                "Apply these rules to EVERY matching instance in the draft, not "
                "just the first one or two — scan the whole text, including "
                "closing lines and list items:"
            )
            for rule in mandatory:
                lines.append(_format(rule, with_confidence=False))

        if situational:
            lines.append("\nApply these where they fit naturally (lower confidence — use judgment):")
            for rule in situational:
                lines.append(_format(rule, with_confidence=True))

        avoid = self.data.get("lexical_preferences", {}).get("avoid", [])
        if avoid:
            lines.append("\nAvoid these words/phrases: " + ", ".join(avoid))
        prefer = self.data.get("lexical_preferences", {}).get("prefer", [])
        if prefer:
            lines.append("Prefer these words/phrases: " + ", ".join(prefer))

        notes = self.data.get("structural_notes", [])
        if notes:
            lines.append("\nStructural tendencies:")
            for note in notes:
                lines.append(f"- {note}")

        return "\n".join(lines)


def _confidence_for_count(count: int) -> str:
    if count >= 4:
        return "high"
    if count >= 2:
        return "medium"
    return "low"
