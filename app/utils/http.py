from __future__ import annotations

from typing import Dict, Optional


def proxy_config() -> Optional[Dict[str, str]]:
    import os

    http_proxy = os.getenv("HTTP_PROXY") or os.getenv("http_proxy")
    https_proxy = os.getenv("HTTPS_PROXY") or os.getenv("https_proxy")

    proxies = {}
    if http_proxy:
        proxies["http://"] = http_proxy
    if https_proxy or http_proxy:
        proxies["https://"] = https_proxy or http_proxy

    return proxies or None
