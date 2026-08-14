import logging

import httpx

from backend.core.config import settings

log = logging.getLogger(__name__)


async def verify_supabase_token(token: str) -> dict | None:
    """Validate a Supabase access token and normalize its identity claims."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/user",
                headers={
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {token}",
                },
            )
        if response.status_code != 200:
            return None

        user = response.json()
        metadata = user.get("user_metadata") or {}
        app_metadata = user.get("app_metadata") or {}
        provider = app_metadata.get("provider") or "email"
        return {
            "uid": user["id"],
            "email": user.get("email"),
            "email_verified": bool(user.get("email_confirmed_at")),
            "name": metadata.get("full_name") or metadata.get("name") or "",
            "picture": metadata.get("avatar_url") or metadata.get("picture"),
            "provider": provider,
            "auth_system": "supabase",
        }
    except Exception:
        log.exception("Supabase token verification failed")
        return None


async def delete_supabase_user(user_id: str) -> bool:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/admin/users/{user_id}",
                headers={
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                },
            )
        return response.status_code in {200, 204, 404}
    except Exception:
        log.exception("Supabase user deletion failed for %s", user_id)
        return False


async def create_supabase_user(
    email: str,
    password: str,
    display_name: str | None = None,
) -> str:
    """Create a confirmed Supabase identity for a provider team account."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/admin/users",
            headers={
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            },
            json={
                "email": email.strip().lower(),
                "password": password,
                "email_confirm": True,
                "user_metadata": {"full_name": display_name or ""},
            },
        )
    data = response.json()
    if response.status_code not in {200, 201}:
        message = data.get("msg") or data.get("message") or "Could not create account"
        if "already" in message.lower() or "exist" in message.lower():
            raise ValueError("EMAIL_EXISTS")
        raise ValueError(message)
    return data["id"]


async def verify_supabase_password(email: str, password: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/token",
            params={"grant_type": "password"},
            headers={"apikey": settings.SUPABASE_SERVICE_ROLE_KEY},
            json={"email": email.strip().lower(), "password": password},
        )
    data = response.json()
    if response.status_code != 200 or not data.get("user", {}).get("id"):
        raise ValueError("The provider owner password is incorrect.")
    return data["user"]["id"]
