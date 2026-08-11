from __future__ import annotations

import json
import urllib.error
import urllib.request

from core.config import Config
from core.providers.base import Provider, ProviderError

ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"


class AnthropicProvider(Provider):
    def __init__(self, config: Config) -> None:
        self.config = config

    def complete(self, system: str, user: str, max_tokens: int) -> str:
        if not self.config.anthropic_api_key:
            raise ProviderError(
                "Missing ANTHROPIC_API_KEY. Add it to .env, then restart Humanizer."
            )

        payload = {
            "model": self.config.anthropic_model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": [{"role": "user", "content": user}],
        }
        request = urllib.request.Request(
            ANTHROPIC_MESSAGES_URL,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "content-type": "application/json",
                "x-api-key": self.config.anthropic_api_key,
                "anthropic-version": ANTHROPIC_VERSION,
            },
        )

        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise ProviderError(_format_http_error(exc.code, detail)) from exc
        except urllib.error.URLError as exc:
            raise ProviderError(
                "Could not reach the Claude API. Check your internet connection."
            ) from exc

        text_parts = [
            block.get("text", "")
            for block in body.get("content", [])
            if block.get("type") == "text"
        ]
        return "".join(text_parts).strip()


def _format_http_error(status_code: int, detail: str) -> str:
    try:
        parsed = json.loads(detail)
        message = parsed.get("error", {}).get("message") or parsed.get("message")
    except json.JSONDecodeError:
        message = detail.strip()

    if status_code == 401:
        return "Claude rejected the API key. Check ANTHROPIC_API_KEY in .env."
    if status_code == 404:
        return "Claude could not find the configured model. Check ANTHROPIC_MODEL in .env."
    if status_code == 429:
        return "Claude rate-limited this request. Try again in a moment."

    return f"Claude API error {status_code}: {message or 'No details provided.'}"
