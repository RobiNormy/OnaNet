from typing import Any

from fastapi import APIRouter, Header, HTTPException, status
from firebase_admin import auth as firebase_auth
from pydantic import BaseModel, field_validator

from backend.core.firebase import verify_firebase_token
from backend.db.session import get_db_connection

router = APIRouter(prefix="/auth", tags=["auth"])


class UserSyncRequest(BaseModel):
    firebase_uid: str
    email: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    profile_image_url: str | None = None
    auth_provider: str | None = None
    role: str = "user"
    is_phone_verified: bool = False
    is_profile_complete: bool = False

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str | None) -> str | None:
        if value is None:
            return None

        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Invalid email address")

        return email


class UserResponse(BaseModel):
    firebase_uid: str
    email: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    profile_image_url: str | None = None
    auth_provider: str | None = None
    role: str = "user"
    is_phone_verified: bool = False
    is_profile_complete: bool = False
    created_at: str | None = None
    updated_at: str | None = None


@router.get("/ping")
async def auth_ping() -> dict[str, str]:
    return {"status": "auth router working"}


@router.post("/sync", response_model=UserResponse)
async def sync_user(
    user_in: UserSyncRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    token_uid = firebase_user["uid"]
    if user_in.firebase_uid != token_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase UID does not match authenticated user",
        )

    email = user_in.email or firebase_user.get("email")
    profile_image_url = user_in.profile_image_url or firebase_user.get("picture")
    is_phone_verified = bool(user_in.is_phone_verified or user_in.phone_number)

    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            INSERT INTO users (
                firebase_uid,
                email,
                first_name,
                last_name,
                phone_number,
                profile_image_url,
                auth_provider,
                role,
                is_phone_verified,
                is_profile_complete
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (firebase_uid)
            DO UPDATE SET
                email = EXCLUDED.email,
                first_name = COALESCE(EXCLUDED.first_name, users.first_name),
                last_name = COALESCE(EXCLUDED.last_name, users.last_name),
                phone_number = COALESCE(EXCLUDED.phone_number, users.phone_number),
                profile_image_url = COALESCE(EXCLUDED.profile_image_url, users.profile_image_url),
                auth_provider = COALESCE(EXCLUDED.auth_provider, users.auth_provider),
                role = COALESCE(EXCLUDED.role, users.role),
                is_phone_verified = EXCLUDED.is_phone_verified,
                is_profile_complete = EXCLUDED.is_profile_complete,
                updated_at = NOW()
            RETURNING
                firebase_uid,
                email,
                first_name,
                last_name,
                phone_number,
                profile_image_url,
                auth_provider,
                role,
                is_phone_verified,
                is_profile_complete,
                created_at,
                updated_at;
            """,
            token_uid,
            email.lower() if email else None,
            _clean(user_in.first_name),
            _clean(user_in.last_name),
            _clean(user_in.phone_number),
            _clean(profile_image_url),
            _clean(user_in.auth_provider),
            _clean(user_in.role) or "user",
            is_phone_verified,
            user_in.is_profile_complete,
        )

    return _serialize_user(row)


@router.get("/me", response_model=UserResponse)
async def get_me(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT
                firebase_uid,
                email,
                first_name,
                last_name,
                phone_number,
                profile_image_url,
                auth_provider,
                role,
                is_phone_verified,
                is_profile_complete,
                created_at,
                updated_at
            FROM users
            WHERE firebase_uid = $1;
            """,
            firebase_user["uid"],
        )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )

    return _serialize_user(row)


async def _get_current_firebase_user(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header must be Bearer token",
        )

    try:
        return verify_firebase_token(token)
    except firebase_auth.InvalidIdTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        ) from exc
    except firebase_auth.ExpiredIdTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Expired Firebase token",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not verify Firebase token",
        ) from exc


def _clean(value: str | None) -> str | None:
    if value is None:
        return None

    cleaned = value.strip()
    return cleaned or None


def _serialize_user(row: Any) -> dict[str, Any]:
    data = dict(row)
    for key in ("created_at", "updated_at"):
        if data.get(key) is not None:
            data[key] = data[key].isoformat()
    return data
