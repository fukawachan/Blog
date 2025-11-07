from __future__ import annotations

from typing import Dict, Literal

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(..., min_length=1)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(..., min_length=1)

    def dict_compat(self) -> Dict:
        try:
            return self.model_dump(exclude_none=True)  # type: ignore[attr-defined]
        except AttributeError:  # pragma: no cover
            return self.dict(exclude_none=True)
