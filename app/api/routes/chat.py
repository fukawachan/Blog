from __future__ import annotations

from fastapi import APIRouter

from app.schemas import ChatRequest
from app.services.chat_proxy import forward_chat_request

router = APIRouter(prefix="/api", tags=["chat"])


@router.post("/chat")
async def chat_endpoint(request_body: ChatRequest):
    payload = request_body.dict_compat()
    result = await forward_chat_request(payload, stream=request_body.stream)
    return result
