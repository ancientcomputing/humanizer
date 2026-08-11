from __future__ import annotations

from core.config import Config
from core.providers.base import Provider, ProviderError
from core.providers.anthropic_provider import AnthropicProvider
from core.providers.openai_provider import OpenAIProvider


def get_provider(config: Config) -> Provider:
    if config.provider == "openai":
        return OpenAIProvider(config)
    if config.provider == "anthropic":
        return AnthropicProvider(config)
    raise ProviderError(
        f"Unknown provider '{config.provider}'. Set HUMANIZER_PROVIDER to 'anthropic' or 'openai'."
    )


__all__ = ["Provider", "ProviderError", "get_provider"]
