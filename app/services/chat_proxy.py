from __future__ import annotations

import json
from typing import Dict

import httpx
from fastapi import HTTPException, status
from fastapi.responses import StreamingResponse

from app.config import GLM_API_KEY, GLM_API_URL, HTTP_TIMEOUT
from app.utils.http import proxy_config


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


async def forward_chat_request(payload: Dict, stream: bool):
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
        "proxies": proxy_config(),
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
