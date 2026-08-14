import logging
from pathlib import Path

import anyio
import firebase_admin
import httpx
from firebase_admin import auth, credentials

from backend.core.config import settings

log = logging.getLogger(__name__)
_firebase_admin_ready = False


def _init_firebase_admin() -> None:
    global _firebase_admin_ready

    try:
        firebase_admin.get_app()
        _firebase_admin_ready = True
        return
    except ValueError:
        pass

    credential_path = settings.firebase_service_account_path
    if not credential_path or not Path(credential_path).is_file():
        log.info(
            "Firebase service account is not configured in this runtime; "
            "using Firebase API key token verification"
        )
        return

    try:
        try:
            credential = credentials.Certificate(credential_path)
        except ValueError:
            credential = credentials.RefreshToken(credential_path)
        options = (
            {"projectId": settings.firebase_project_id}
            if settings.firebase_project_id
            else None
        )
        firebase_admin.initialize_app(credential, options)
        _firebase_admin_ready = True
    except Exception:
        log.warning(
            "Firebase Admin could not initialize; using remote token verification",
            exc_info=True,
        )


_init_firebase_admin()


async def _verify_supabase_token(token: str) -> dict | None:
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
            "firebase": {
                "sign_in_provider": (
                    "google.com" if provider == "google" else "password"
                )
            },
            "auth_system": "supabase",
        }
    except Exception:
        log.exception("Supabase token verification failed")
        return None


async def _verify_firebase_token(token: str) -> dict | None:
    if _firebase_admin_ready:
        try:
            return await anyio.to_thread.run_sync(auth.verify_id_token, token)
        except (auth.InvalidIdTokenError, auth.ExpiredIdTokenError):
            return None
        except Exception:
            log.exception("Local Firebase token verification failed")
            return None

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://identitytoolkit.googleapis.com/v1/accounts:lookup",
                params={"key": settings.FIREBASE_API_KEY},
                json={"idToken": token},
            )
        data = response.json()
        users = data.get("users", [])
        if "error" in data or not users:
            return None
        user = users[0]
        return {
            "uid": user["localId"],
            "email": user.get("email"),
            "name": user.get("displayName", ""),
            "picture": user.get("photoUrl"),
            "firebase": {"sign_in_provider": "password"},
        }
    except Exception:
        log.exception("Remote Firebase token verification failed")
        return None


async def verify_firebase_token(token: str) -> dict | None:
    """Accept Supabase sessions first, with Firebase retained for rollback."""
    supabase_user = await _verify_supabase_token(token)
    if supabase_user:
        return supabase_user
    return await _verify_firebase_token(token)


async def delete_firebase_user(firebase_uid: str) -> bool:
    """Delete an auth identity from Supabase, falling back to Firebase."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/admin/users/{firebase_uid}",
                headers={
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                },
            )
        if response.status_code in {200, 204}:
            return True
    except Exception:
        log.exception("Supabase user deletion failed for %s", firebase_uid)

    if not _firebase_admin_ready:
        return False
    try:
        await anyio.to_thread.run_sync(auth.delete_user, firebase_uid)
        return True
    except auth.UserNotFoundError:
        return True
    except Exception:
        log.exception("Firebase user deletion failed for %s", firebase_uid)
        return False


async def create_firebase_user_rest(email: str, password: str, display_name: str | None = None) -> str:
    """Create a legacy Firebase identity for installed pre-migration apps."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signUp",
            params={"key": settings.FIREBASE_API_KEY},
            json={"email": email, "password": password, "returnSecureToken": True},
        )
    data = response.json()
    if "error" in data:
        raise Exception(data["error"]["message"])
    firebase_uid = data["localId"]
    if display_name:
        async with httpx.AsyncClient() as client:
            await client.post(
                "https://identitytoolkit.googleapis.com/v1/accounts:update",
                params={"key": settings.FIREBASE_API_KEY},
                json={"idToken": data["idToken"], "displayName": display_name},
            )
    return firebase_uid


async def create_supabase_user_rest(
    email: str,
    password: str,
    display_name: str | None = None,
) -> str:
    """Create a Supabase Auth identity for a provider team account."""
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
            raise Exception("EMAIL_EXISTS")
        raise Exception(message)
    return data["id"]


async def verify_firebase_password(email: str, password: str) -> str:
    """Verify a password with Supabase, retaining Firebase as rollback."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/token",
            params={"grant_type": "password"},
            headers={"apikey": settings.SUPABASE_SERVICE_ROLE_KEY},
            json={
                "email": email.strip().lower(),
                "password": password,
            },
        )
    data = response.json()
    if response.status_code == 200 and data.get("user", {}).get("id"):
        return data["user"]["id"]

    async with httpx.AsyncClient() as client:
        firebase_response = await client.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": settings.FIREBASE_API_KEY},
            json={
                "email": email.strip().lower(),
                "password": password,
                "returnSecureToken": True,
            },
        )
    firebase_data = firebase_response.json()
    if "error" in firebase_data:
        raise ValueError("The provider owner password is incorrect.")
    return firebase_data["localId"]
