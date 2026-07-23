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


async def verify_firebase_token(token: str) -> dict | None:
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


async def create_firebase_user_rest(email: str, password: str, display_name: str | None = None) -> str:
    async with httpx.AsyncClient() as client:
        res = await client.post(
            f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={settings.FIREBASE_API_KEY}",
            json={"email": email, "password": password, "returnSecureToken": True}
        )
        data = res.json()
        if "error" in data:
            raise Exception(data["error"]["message"])
        firebase_uid = data["localId"]
        id_token = data["idToken"]

    if display_name:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"https://identitytoolkit.googleapis.com/v1/accounts:update?key={settings.FIREBASE_API_KEY}",
                json={"idToken": id_token, "displayName": display_name}
            )

    return firebase_uid


async def verify_firebase_password(email: str, password: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": settings.FIREBASE_API_KEY},
            json={
                "email": email.strip().lower(),
                "password": password,
                "returnSecureToken": True,
            },
        )
    data = response.json()
    if "error" in data:
        raise ValueError("The provider owner password is incorrect.")
    return data["localId"]
