from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass
from typing import Any

import httpx

from backend.core.config import settings


log = logging.getLogger(__name__)


class KraPinServiceError(RuntimeError):
    """A safe, user-facing failure from the KRA PIN verification service."""


@dataclass
class _CachedToken:
    value: str
    expires_at: float


_token: _CachedToken | None = None
_token_lock = asyncio.Lock()


def _base_url() -> str:
    environment = settings.GAVACONNECT_ENV.strip().lower()
    if environment == "sandbox":
        return "https://sbx.kra.go.ke"
    if environment == "production":
        return "https://api.kra.go.ke"
    raise KraPinServiceError("GavaConnect environment is not configured correctly.")


def _credentials() -> tuple[str, str]:
    key = settings.GAVACONNECT_CONSUMER_KEY
    secret = settings.GAVACONNECT_CONSUMER_SECRET
    if not key or not secret:
        raise KraPinServiceError("KRA verification is not configured.")
    return key, secret


async def _access_token() -> str:
    global _token
    now = time.monotonic()
    if _token and _token.expires_at > now:
        return _token.value

    async with _token_lock:
        now = time.monotonic()
        if _token and _token.expires_at > now:
            return _token.value

        key, secret = _credentials()
        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                response = await client.get(
                    f"{_base_url()}/v1/token/generate",
                    params={"grant_type": "client_credentials"},
                    auth=httpx.BasicAuth(key, secret),
                )
            payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            log.warning("GavaConnect token request failed: %s", type(exc).__name__)
            raise KraPinServiceError(
                "KRA verification is temporarily unavailable. Try again shortly."
            ) from exc

        access_token = payload.get("access_token")
        if response.status_code != 200 or not access_token:
            log.warning(
                "GavaConnect rejected token request with status %s",
                response.status_code,
            )
            raise KraPinServiceError(
                "KRA verification credentials were rejected. Check the backend configuration."
            )

        try:
            lifetime = max(int(payload.get("expires_in", 3599)), 60)
        except (TypeError, ValueError):
            lifetime = 3599
        _token = _CachedToken(access_token, now + lifetime - 30)
        return access_token


async def check_kra_pin(kra_pin: str) -> dict[str, Any]:
    global _token
    token = await _access_token()
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{_base_url()}/checker/v1/pinbypin",
                headers={"Authorization": f"Bearer {token}"},
                json={"KRAPIN": kra_pin},
            )
        payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        log.warning("KRA PIN check failed: %s", type(exc).__name__)
        raise KraPinServiceError(
            "KRA verification is temporarily unavailable. Try again shortly."
        ) from exc

    if response.status_code in {401, 403}:
        _token = None
        raise KraPinServiceError(
            "KRA rejected the verification session. Try the check again."
        )
    if response.status_code >= 500:
        raise KraPinServiceError(
            "KRA verification is temporarily unavailable. Try again shortly."
        )

    pin_data = payload.get("PINDATA") or {}
    return {
        "valid": payload.get("Status") == "OK"
        and payload.get("ResponseCode") == "23000",
        "response_code": str(payload.get("ResponseCode") or response.status_code),
        "message": str(payload.get("Message") or "KRA returned no message."),
        "taxpayer_name": pin_data.get("Name"),
        "taxpayer_type": pin_data.get("TypeOfTaxpayer"),
        "pin_status": pin_data.get("StatusOfPIN"),
        "environment": settings.GAVACONNECT_ENV.strip().lower(),
    }
