from __future__ import annotations

from abc import ABC, abstractmethod


class ProviderError(Exception):
    """Raised when a provider call fails in a way the user should see."""


class Provider(ABC):
    """Minimal abstraction over an LLM provider used for humanize/classify calls."""

    @abstractmethod
    def complete(self, system: str, user: str, max_tokens: int) -> str:
        """Send a single-turn request and return the model's text response."""
        raise NotImplementedError
