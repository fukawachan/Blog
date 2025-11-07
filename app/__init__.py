from __future__ import annotations

from fastapi import FastAPI

from app.api.routes import chat, music, root
from app.db import init_db


def create_app() -> FastAPI:
    app = FastAPI(
        title="Music Library Backend",
        description="Implements music library and chat proxy services.",
        version="0.1.0",
    )

    app.include_router(root.router)
    app.include_router(music.router)
    app.include_router(chat.router)

    @app.on_event("startup")
    def on_startup() -> None:
        init_db()

    return app


__all__ = ["create_app"]
