from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Music
from app.schemas import MusicInfoResponse, MusicListResponse
from app.utils.files import guess_mime_type, resolve_file_path

router = APIRouter(prefix="/api/music", tags=["music"])


@router.get("/list", response_model=MusicListResponse)
def list_musics(db: Session = Depends(get_db)) -> MusicListResponse:
    musics = db.query(Music).order_by(Music.id).all()
    return MusicListResponse(musics=musics)


@router.get("/info/{music_id}", response_model=MusicInfoResponse)
def get_music_info(
    music_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> MusicInfoResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    return MusicInfoResponse(
        id=music.id,
        title=music.title,
        artist=music.artist,
        music_url=str(request.url_for("get_music_file", music_id=music.id)),
        thumbnail_url=str(request.url_for("get_music_thumbnail", music_id=music.id)),
    )


@router.get("/file/{music_id}", name="get_music_file")
def get_music_file(music_id: int, db: Session = Depends(get_db)) -> FileResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    file_path = resolve_file_path(music.file_path)
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Music file is missing"
        )

    media_type = guess_mime_type(file_path, "audio/mpeg")
    return FileResponse(path=file_path, media_type=media_type, filename=file_path.name)


@router.get("/thumbnail/{music_id}", name="get_music_thumbnail")
def get_music_thumbnail(music_id: int, db: Session = Depends(get_db)) -> FileResponse:
    music = db.get(Music, music_id)
    if music is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Music not found")

    thumb_path = resolve_file_path(music.thumbnail_path)
    if not thumb_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Thumbnail file is missing"
        )

    media_type = guess_mime_type(thumb_path, "image/jpeg")
    return FileResponse(path=thumb_path, media_type=media_type, filename=thumb_path.name)
