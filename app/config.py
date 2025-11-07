from __future__ import annotations

import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = BASE_DIR / ".env"


def _load_env_file() -> None:
    """
    Load simple KEY=VALUE pairs from the project-level .env file without
    overriding already exported environment variables.
    """
    if not ENV_PATH.exists():
        return

    try:
        with ENV_PATH.open("r", encoding="utf-8") as env_file:
            for raw_line in env_file:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                if not key or key in os.environ:
                    continue
                os.environ[key] = value.strip().strip('"').strip("'")
    except OSError:
        # Best effort load; silently continue if the file cannot be read.
        pass


_load_env_file()

DB_PATH = BASE_DIR / "music_library.db"
DATABASE_URL = f"sqlite:///{DB_PATH.as_posix()}"

GLM_API_URL = os.getenv(
    "GLM_API_URL", "https://open.bigmodel.cn/api/paas/v4/chat/completions"
)
GLM_API_KEY = os.getenv("GLM_API_KEY")
HTTP_TIMEOUT = float(os.getenv("GLM_TIMEOUT", "30"))
