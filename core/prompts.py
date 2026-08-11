from __future__ import annotations

from pathlib import Path

from core.config import PROMPTS_DIR


def load_template(name: str) -> str:
    path = PROMPTS_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"Prompt template not found: {path}")
    return path.read_text(encoding="utf-8")


def split_system_user(template: str) -> tuple[str, str]:
    """Split a template file on '## System' / '## User' headers."""
    system_marker = "## System"
    user_marker = "## User"
    system_start = template.index(system_marker) + len(system_marker)
    user_start = template.index(user_marker)
    system = template[system_start:user_start].strip()
    user = template[user_start + len(user_marker):].strip()
    return system, user


def render(template: str, **values: str) -> str:
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace("{{" + key + "}}", value)
    return rendered
