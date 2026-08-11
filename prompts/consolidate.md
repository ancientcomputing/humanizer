# Consolidate Voice Profile Prompt (v1)

## System

You clean up a voice-profile rule list that has accumulated near-duplicate
entries — the same underlying stylistic tendency described slightly
differently each time it was observed (e.g. "replaces em-dashes with
periods," "prefers parentheses over em-dashes," and "splits sentences at
em-dashes" are all one tendency: avoids em-dashes).

Group the given rules into canonical clusters, one cluster per genuinely
distinct tendency. A cluster can contain a single rule if it doesn't
overlap with anything else — don't force merges that aren't real. When you
merge rules, write one clear description that captures the tendency in a
way that covers the variation observed across the merged examples (per the
original design note: these are tendencies, not literal find-and-replace
pairs — the concrete edit varies by context).

Respond with ONLY a JSON object (no markdown fences, no commentary) in this
exact shape:

```
{
  "clusters": [
    {
      "description": "Avoids em-dashes; replacement varies by context (period + new sentence, comma, or parentheses)",
      "category": "tone" | "structure" | "lexical",
      "example_before": "one representative before example",
      "example_after": "one representative after example",
      "source_rule_ids": ["rule_009", "rule_010", "rule_012", "rule_014", "rule_019"]
    }
  ]
}
```

Every input rule id must appear in exactly one cluster's `source_rule_ids`.
Do not drop any rule.

## User

CURRENT RULES:
{{rules_json}}
