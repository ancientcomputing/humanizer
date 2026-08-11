from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

APP_NAME = "Humanizer"
PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_PATH = PROJECT_ROOT / ".env"
DATA_DIR = PROJECT_ROOT / "data"
PROMPTS_DIR = PROJECT_ROOT / "prompts"

DEFAULT_PROVIDER = "anthropic"
DEFAULT_ANTHROPIC_MODEL = "claude-sonnet-4-5"
DEFAULT_OPENAI_MODEL = "gpt-4o"
DEFAULT_MAX_TOKENS = 4000
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8420
DEFAULT_OPEN_BROWSER = True
DEFAULT_MISMATCH_THRESHOLD = 0.35


def load_dotenv(path: Path = DEFAULT_ENV_PATH, override: bool = False) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]

        if key and (override or key not in os.environ):
            os.environ[key] = value


def env_bool(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return int(raw.strip())
    except ValueError:
        return default


def update_dotenv(updates: dict[str, str], path: Path = DEFAULT_ENV_PATH) -> None:
    """Merge key=value updates into the .env file, preserving existing lines/comments."""
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    remaining = dict(updates)
    new_lines: list[str] = []

    for raw_line in lines:
        stripped = raw_line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            key = stripped.split("=", 1)[0].strip()
            if key in remaining:
                new_lines.append(f"{key}={remaining.pop(key)}")
                continue
        new_lines.append(raw_line)

    if remaining:
        if new_lines and new_lines[-1].strip():
            new_lines.append("")
        for key, value in remaining.items():
            new_lines.append(f"{key}={value}")

    path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")


def env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return float(raw.strip())
    except ValueError:
        return default


@dataclass(frozen=True)
class Config:
    provider: str
    anthropic_api_key: str
    anthropic_model: str
    openai_api_key: str
    openai_model: str
    max_tokens: int
    host: str
    port: int
    open_browser: bool
    mismatch_threshold: float

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            provider=os.environ.get("HUMANIZER_PROVIDER", DEFAULT_PROVIDER).strip().lower()
            or DEFAULT_PROVIDER,
            anthropic_api_key=os.environ.get("ANTHROPIC_API_KEY", "").strip(),
            anthropic_model=os.environ.get("ANTHROPIC_MODEL", DEFAULT_ANTHROPIC_MODEL).strip()
            or DEFAULT_ANTHROPIC_MODEL,
            openai_api_key=os.environ.get("OPENAI_API_KEY", "").strip(),
            openai_model=os.environ.get("OPENAI_MODEL", DEFAULT_OPENAI_MODEL).strip()
            or DEFAULT_OPENAI_MODEL,
            max_tokens=env_int("HUMANIZER_MAX_TOKENS", DEFAULT_MAX_TOKENS),
            host=os.environ.get("HUMANIZER_HOST", DEFAULT_HOST).strip() or DEFAULT_HOST,
            port=env_int("HUMANIZER_PORT", DEFAULT_PORT),
            open_browser=env_bool("HUMANIZER_OPEN_BROWSER", DEFAULT_OPEN_BROWSER),
            mismatch_threshold=env_float(
                "HUMANIZER_MISMATCH_THRESHOLD", DEFAULT_MISMATCH_THRESHOLD
            ),
        )
