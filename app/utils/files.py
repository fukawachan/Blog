from __future__ import annotations

import mimetypes
from pathlib import Path

from app.config import BASE_DIR


def resolve_file_path(raw_path: str) -> Path:
    path = Path(raw_path)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path.resolve(strict=False)


def guess_mime_type(path: Path, fallback: str) -> str:
    mime_type, _ = mimetypes.guess_type(path.as_posix())
    return mime_type or fallback
