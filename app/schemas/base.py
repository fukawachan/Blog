from __future__ import annotations

from pydantic import BaseModel

try:
    from pydantic import ConfigDict
except ImportError:  # pragma: no cover
    ConfigDict = None


class ORMModel(BaseModel):
    if ConfigDict is not None:  # Pydantic v2+
        model_config = ConfigDict(from_attributes=True)
    else:  # Pydantic v1 fallback

        class Config:
            orm_mode = True
