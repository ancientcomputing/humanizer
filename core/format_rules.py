from __future__ import annotations

import re

PLATFORMS = ("Reddit", "LinkedIn", "Other")


def apply_format_rules(text: str, platform: str) -> str:
    """Mechanical, platform-specific formatting only — never touches voice."""
    text = text.strip()

    if platform == "Reddit":
        return _format_reddit(text)
    if platform == "LinkedIn":
        return _format_linkedin(text)
    return text


def _format_reddit(text: str) -> str:
    # Strip any hashtags — not a Reddit convention.
    text = re.sub(r"(?<!\S)#\w+", "", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _format_linkedin(text: str) -> str:
    # LinkedIn favors short paragraphs with a blank line between them.
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    return "\n\n".join(paragraphs)
