from __future__ import annotations

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import chat, music, root
from app.db import init_db


def _resolve_allowed_origins() -> list[str]:
    raw = os.getenv("CORS_ALLOW_ORIGINS")
    if raw:
        return [origin.strip() for origin in raw.split(",") if origin.strip()]
    return [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]


def create_app() -> FastAPI:
    app = FastAPI(
        title="Music Library Backend",
        description="Implements music library and chat proxy services.",
        version="0.1.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=_resolve_allowed_origins(),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(root.router)
    app.include_router(music.router)
    app.include_router(chat.router)

    @app.on_event("startup")
    def on_startup() -> None:
        init_db()

    return app


__all__ = ["create_app"]
