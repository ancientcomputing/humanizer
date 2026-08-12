from __future__ import annotations

import json
import urllib.error
import urllib.request

from core.config import Config
from core.providers.base import Provider, ProviderError

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"


class OpenAIProvider(Provider):
    def __init__(self, config: Config) -> None:
        self.config = config

    def complete(self, system: str, user: str, max_tokens: int) -> str:
        if not self.config.openai_api_key:
            raise ProviderError(
                "No OpenAI API key set. Add one in the Settings tab, then try again."
            )

        payload = {
            "model": self.config.openai_model,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        }
        request = urllib.request.Request(
            OPENAI_CHAT_URL,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "content-type": "application/json",
                "authorization": f"Bearer {self.config.openai_api_key}",
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
                "Could not reach the OpenAI API. Check your internet connection."
            ) from exc

        choices = body.get("choices", [])
        if not choices:
            return ""
        return (choices[0].get("message", {}).get("content") or "").strip()


def _format_http_error(status_code: int, detail: str) -> str:
    try:
        parsed = json.loads(detail)
        message = parsed.get("error", {}).get("message") or parsed.get("message")
    except json.JSONDecodeError:
        message = detail.strip()

    if status_code == 401:
        return "OpenAI rejected the API key. Check it in the Settings tab."
    if status_code == 404:
        return "OpenAI could not find the configured model. Check it in the Settings tab."
    if status_code == 429:
        return "OpenAI rate-limited this request. Try again in a moment."

    return f"OpenAI API error {status_code}: {message or 'No details provided.'}"
