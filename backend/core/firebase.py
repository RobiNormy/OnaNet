import anyio
import httpx
import logging
import firebase_admin
from firebase_admin import auth
from backend.core.config import settings


def _init_firebase_admin() -> None:
    pass


_init_firebase_admin()


async def verify_firebase_token(token: str) -> dict | None:
    try:
        async with httpx.AsyncClient() as client:
            res = await client.post(
                f"https://identitytoolkit.googleapis.com/v1/accounts:lookup?key={settings.FIREBASE_API_KEY}",
                json={"idToken": token}
            )
            data = res.json()
            if "error" in data:
                return None
            users = data.get("users", [])
            if not users:
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
        return None


async def create_firebase_user_rest(email: str, password: str, display_name: str | None = None) -> str:
    api_key = settings.FIREBASE_API_KEY
    print(f"DEBUG API KEY: '{api_key}'")

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