from __future__ import annotations

import json
import mimetypes
import os
from pathlib import Path
from typing import Dict, Generator, Literal, Optional

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "music_library.db"
DATABASE_URL = f"sqlite:///{DB_PATH.as_posix()}"
GLM_API_URL = os.getenv(
    "GLM_API_URL", "https://open.bigmodel.cn/api/paas/v4/chat/completions"
)
GLM_API_KEY = os.getenv("GLM_API_KEY")
HTTP_TIMEOUT = float(os.getenv("GLM_TIMEOUT", "30"))

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

mimetypes.add_type("audio/mpeg", ".mp3")
mimetypes.add_type("image/jpeg", ".jpg")
mimetypes.add_type("image/jpeg", ".jpeg")


class Music(Base):
    __tablename__ = "music"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    artist = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    thumbnail_path = Column(String, nullable=False)


def init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _resolve_file_path(raw_path: str) -> Path:
    path = Path(raw_path)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path.resolve(strict=False)


def _guess_mime_type(path: Path, fallback: str) -> str:
    mime_type, _ = mimetypes.guess_type(path.as_posix())
    return mime_type or fallback


def _proxy_config() -> Optional[Dict[str, str]]:
    http_proxy = os.getenv("HTTP_PROXY") or os.getenv("http_proxy")
    https_proxy = os.getenv("HTTPS_PROXY") or os.getenv("https_proxy")

    proxies = {}
    if http_proxy:
        proxies["http://"] = http_proxy
    if https_proxy or http_proxy:
        proxies["https://"] = https_proxy or http_proxy

    return proxies or None


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


class MusicBrief(ORMModel):
    id: int
    title: str
    artist: str


class MusicListResponse(BaseModel):
    musics: list[MusicBrief]


class MusicInfoResponse(MusicBrief):
    music_url: str
    thumbnail_url: str


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
            return self.model_dump(exclude_none=True)
        except AttributeError:  # pragma: no cover
            return self.dict(exclude_none=True)


app = FastAPI(
    title="Personal Site Backend",
    description="Implements music library and chat proxy services.",
    version="0.1.0",
)


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/")
async def root() -> Dict[str, str]:
    return {"message": "Backend is up", "docs": "/docs"}


@app.get("/api/music/list", response_model=MusicListResponse)
def list_musics(db: Session = Depends(get_db)) -> MusicListResponse:
    musics = db.query(Music).order_by(Music.id).all()
    return MusicListResponse(musics=musics)


@app.get("/api/music/info/{music_id}", response_model=MusicInfoResponse)
def get_music_info(
    music_id: int, request: Request, db: Session = Depends(get_db)
) -> MusicInfoResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    return MusicInfoResponse(
        id=music.id,
        title=music.title,
        artist=music.artist,
        music_url=request.url_for("get_music_file", music_id=music.id),
        thumbnail_url=request.url_for("get_music_thumbnail", music_id=music.id),
    )


@app.get("/api/music/file/{music_id}", name="get_music_file")
def get_music_file(music_id: int, db: Session = Depends(get_db)) -> FileResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    file_path = _resolve_file_path(music.file_path)
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Music file is missing"
        )

    media_type = _guess_mime_type(file_path, "audio/mpeg")
    return FileResponse(path=file_path, media_type=media_type, filename=file_path.name)


@app.get("/api/music/thumbnail/{music_id}", name="get_music_thumbnail")
def get_music_thumbnail(music_id: int, db: Session = Depends(get_db)) -> FileResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    thumb_path = _resolve_file_path(music.thumbnail_path)
    if not thumb_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Thumbnail file is missing"
        )

    media_type = _guess_mime_type(thumb_path, "image/jpeg")
    return FileResponse(path=thumb_path, media_type=media_type, filename=thumb_path.name)


def _raise_upstream_error(status_code: int, raw_body: bytes) -> None:
    detail: Dict[str, str | int] | str = "Upstream service error"
    try:
        parsed = json.loads(raw_body.decode("utf-8"))
        detail = parsed.get("error", parsed)
    except Exception:
        try:
            detail = raw_body.decode("utf-8")
        except UnicodeDecodeError:
            pass
    raise HTTPException(status_code=status_code, detail=detail)


async def _forward_chat_request(payload: Dict, stream: bool):
    if not GLM_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GLM_API_KEY is not configured",
        )

    headers = {
        "Authorization": f"Bearer {GLM_API_KEY}",
        "Content-Type": "application/json",
    }

    client_args = {
        "headers": headers,
        "timeout": httpx.Timeout(HTTP_TIMEOUT),
        "proxies": _proxy_config(),
    }

    if stream:
        async def event_stream():
            async with httpx.AsyncClient(**client_args) as client:
                async with client.stream("POST", GLM_API_URL, json=payload) as response:
                    if response.status_code >= 400:
                        body = await response.aread()
                        _raise_upstream_error(response.status_code, body)
                    async for chunk in response.aiter_bytes():
                        if chunk:
                            yield chunk

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    async with httpx.AsyncClient(**client_args) as client:
        response = await client.post(GLM_API_URL, json=payload)

    if response.status_code >= 400:
        _raise_upstream_error(response.status_code, response.content)

    return response.json()


@app.post("/api/chat")
async def chat_endpoint(request_body: ChatRequest):
    payload = request_body.dict_compat()
    result = await _forward_chat_request(payload, stream=request_body.stream)
    return result
