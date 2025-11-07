from __future__ import annotations

import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "music_library.db"
DATABASE_URL = f"sqlite:///{DB_PATH.as_posix()}"

GLM_API_URL = os.getenv(
    "GLM_API_URL", "https://open.bigmodel.cn/api/paas/v4/chat/completions"
)
GLM_API_KEY = os.getenv("GLM_API_KEY")
HTTP_TIMEOUT = float(os.getenv("GLM_TIMEOUT", "30"))
