from __future__ import annotations

from typing import Dict

from fastapi import APIRouter

from app.schemas import ChatRequest
from app.services.chat import forward_chat_request

router = APIRouter(prefix="/api", tags=["chat"])

CHAT_COMPLETION_DEFAULTS: Dict[str, object] = {
    "model": "glm-4.6",
    "temperature": 1,
    "top_p": 0.95,
    "max_tokens": 65536,
}


def _build_payload(request_body: ChatRequest, *, stream: bool) -> Dict:
    return {
        **CHAT_COMPLETION_DEFAULTS,
        "stream": stream,
        **request_body.dict_compat(),
    }


@router.post("/chat")
async def chat_endpoint(request_body: ChatRequest):
    payload = _build_payload(request_body, stream=False)
    return await forward_chat_request(payload, stream=False)


@router.post("/chat/stream")
async def chat_stream_endpoint(request_body: ChatRequest):
    payload = _build_payload(request_body, stream=True)
    return await forward_chat_request(payload, stream=True)
