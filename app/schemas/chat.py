from __future__ import annotations

from typing import Dict, Literal, Optional

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(..., min_length=1)


class ChatRequest(BaseModel):
    model: str = Field(..., min_length=1)
    messages: list[ChatMessage] = Field(..., min_length=1)
    stream: bool = False
    temperature: Optional[float] = Field(default=None, ge=0.0, le=2.0)
    top_p: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    max_tokens: Optional[int] = Field(default=None, gt=0)

    def dict_compat(self) -> Dict:
        try:
            return self.model_dump(exclude_none=True)  # type: ignore[attr-defined]
        except AttributeError:  # pragma: no cover
            return self.dict(exclude_none=True)
