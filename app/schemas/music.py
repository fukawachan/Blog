from __future__ import annotations

from pydantic import BaseModel

from .base import ORMModel


class MusicBrief(ORMModel):
    id: int
    title: str
    artist: str


class MusicListResponse(BaseModel):
    musics: list[MusicBrief]


class MusicInfoResponse(MusicBrief):
    music_url: str
    thumbnail_url: str
