from __future__ import annotations

import json
import uuid
from typing import Any

from core.config import Config
from core.diffing import is_likely_mismatch, unified_diff
from core.prompts import load_template, render, split_system_user
from core.providers import Provider
from core.providers.base import ProviderError
from core.voice_profile import VoiceProfile


class PipelineError(Exception):
    pass


def humanize(
    provider: Provider,
    config: Config,
    voice_profile: VoiceProfile,
    draft: str,
    platform: str,
) -> dict[str, Any]:
    if not draft.strip():
        raise PipelineError("Draft text is empty.")

    used_voice_profile = not voice_profile.is_empty()
    voice_section = (
        voice_profile.as_prompt_context()
        if used_voice_profile
        else "No voice profile yet — apply only the generic AI-tell stripping above."
    )

    template = load_template("humanize.md")
    system, user_template = split_system_user(template)
    system = render(system, voice_section=voice_section, platform=platform or "Other")
    user = render(user_template, draft=draft)

    try:
        output = provider.complete(system, user, config.max_tokens)
    except ProviderError as exc:
        raise PipelineError(str(exc)) from exc

    if not output.strip():
        raise PipelineError("The provider returned an empty response.")

    output = output.strip()

    first_pass_draft = None
    if used_voice_profile:
        first_pass_draft = output
        second_user = render(user_template, draft=output)
        output = _second_pass(provider, config, system, second_user, fallback=output)

    return {
        "draft": output,
        "used_voice_profile": used_voice_profile,
        "first_pass_draft": first_pass_draft,
    }


def _second_pass(
    provider: Provider, config: Config, system: str, user: str, fallback: str
) -> str:
    """Run the humanize prompt again on its own output, so the model gets a
    second honest attempt at applying voice rules it missed the first time.
    Falls back to the first-pass draft if this call fails."""
    try:
        output = provider.complete(system, user, config.max_tokens)
    except ProviderError:
        return fallback

    output = output.strip()
    return output if output else fallback


def review(
    provider: Provider,
    config: Config,
    voice_profile: VoiceProfile,
    humanized_text: str,
    edited_text: str,
) -> dict[str, Any]:
    humanized_text = humanized_text.strip()
    edited_text = edited_text.strip()

    if not humanized_text or not edited_text:
        raise PipelineError("Both the humanized draft and the edited version are required.")

    if is_likely_mismatch(humanized_text, edited_text, config.mismatch_threshold):
        return {
            "mismatch": True,
            "message": "This looks like a different article, not an edit — check your paste.",
        }

    classification = _classify(provider, config, voice_profile, humanized_text, edited_text)

    style_count = sum(
        1 for c in classification.get("changes", []) if c.get("classification") == "style"
    )
    content_count = sum(
        1 for c in classification.get("changes", []) if c.get("classification") == "content"
    )

    rule_updates = classification.get("rule_updates", [])
    article_id = uuid.uuid4().hex[:8]
    actions = voice_profile.apply_rule_updates(rule_updates, article_id)
    voice_profile.save()

    new_rules = [a for a in actions if a["action"] == "new"]
    reinforced_rules = [a for a in actions if a["action"] == "reinforced"]

    merges: list[dict[str, Any]] = []
    if len(voice_profile.data.get("rules", [])) >= 2:
        try:
            merges = _consolidate(provider, config, voice_profile)
        except PipelineError:
            # Auto-consolidation is a nice-to-have on top of a successful review;
            # if the extra LLM call fails, keep the review result rather than
            # losing the already-saved rule updates.
            pass

    return {
        "mismatch": False,
        "changes": classification.get("changes", []),
        "style_count": style_count,
        "content_count": content_count,
        "edits_absorbed": len(actions),
        "summary": (
            f"{style_count} style edit{'s' if style_count != 1 else ''} "
            f"(added to voice profile), {content_count} content edit"
            f"{'s' if content_count != 1 else ''} (ignored for learning)."
        ),
        "profile_changes": {
            "new_rules": new_rules,
            "reinforced_rules": reinforced_rules,
            "merges": merges,
        },
    }


def consolidate_voice_profile(
    provider: Provider, config: Config, voice_profile: VoiceProfile
) -> dict[str, Any]:
    """Merge near-duplicate rules (same tendency, different wording) via an LLM pass.

    Public entry point for the manual "Consolidate Similar Rules" UI action.
    """
    rules = voice_profile.data.get("rules", [])
    before_count = len(rules)
    merges = _consolidate(provider, config, voice_profile)
    after_count = len(voice_profile.data.get("rules", []))
    return {
        "before_count": before_count,
        "after_count": after_count,
        "changed": after_count != before_count,
        "merges": merges,
    }


def _consolidate(
    provider: Provider, config: Config, voice_profile: VoiceProfile
) -> list[dict[str, Any]]:
    """Run the consolidation LLM pass and save. Returns the list of real merges."""
    rules = voice_profile.data.get("rules", [])
    if len(rules) < 2:
        return []

    template = load_template("consolidate.md")
    system, user_template = split_system_user(template)
    user = render(user_template, rules_json=voice_profile.rules_as_json())

    try:
        raw_output = provider.complete(system, user, config.max_tokens)
    except ProviderError as exc:
        raise PipelineError(str(exc)) from exc

    parsed = _parse_json_response(raw_output, "consolidation")
    clusters = parsed.get("clusters", []) if isinstance(parsed, dict) else []
    _after_count, merges = voice_profile.replace_with_clusters(clusters)
    voice_profile.save()
    return merges


def _classify(
    provider: Provider,
    config: Config,
    voice_profile: VoiceProfile,
    original: str,
    edited: str,
) -> dict[str, Any]:
    diff_text = unified_diff(original, edited)
    template = load_template("classify.md")
    system, user_template = split_system_user(template)
    user = render(
        user_template,
        original=original,
        edited=edited,
        diff=diff_text,
        existing_rules=voice_profile.rules_context_for_matching(),
    )

    try:
        raw_output = provider.complete(system, user, config.max_tokens)
    except ProviderError as exc:
        raise PipelineError(str(exc)) from exc

    parsed = _parse_json_response(raw_output, "classifier")
    parsed.setdefault("changes", [])
    parsed.setdefault("rule_updates", [])
    return parsed


def _parse_json_response(raw_output: str, label: str) -> dict[str, Any]:
    text = raw_output.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise PipelineError(
            f"The {label} response could not be parsed as JSON. Try again."
        ) from exc

    if not isinstance(parsed, dict):
        raise PipelineError(f"The {label} response was not a JSON object.")

    return parsed
