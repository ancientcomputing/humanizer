from __future__ import annotations

import difflib


def similarity_ratio(a: str, b: str) -> float:
    """Rough word-level similarity, 0..1. Cheap heuristic, not exact."""
    a_words = a.split()
    b_words = b.split()
    if not a_words and not b_words:
        return 1.0
    matcher = difflib.SequenceMatcher(a=a_words, b=b_words, autojunk=False)
    return matcher.ratio()


def is_likely_mismatch(a: str, b: str, threshold: float) -> bool:
    return similarity_ratio(a, b) < threshold


def unified_diff(a: str, b: str, from_label: str = "original", to_label: str = "edited") -> str:
    diff_lines = difflib.unified_diff(
        a.splitlines(),
        b.splitlines(),
        fromfile=from_label,
        tofile=to_label,
        lineterm="",
    )
    return "\n".join(diff_lines)
