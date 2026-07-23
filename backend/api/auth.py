import anyio
import functools
import logging
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, EmailStr, Field
from firebase_admin import auth
from backend.db.session import get_db_connection
from backend.core.firebase import create_firebase_user_rest,verify_firebase_token
from backend.core.security import create_access_token
from backend.schemas.user import AuthResponse
from backend.services.provider_access import current_staff_actor

router = APIRouter(prefix="/auth", tags=["auth"])
log = logging.getLogger(__name__)

class FirebaseTokenRequest(BaseModel):
    token: str

class SignUpRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str | None = None
    last_name: str | None = None


class PersonalInfoUpdate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(default="", max_length=100)


def _user_response(row: dict) -> dict:
    return {
        "id": row["id"],
        "firebase_uid": row["firebase_uid"],
        "email": row["email"],
        "first_name": row["first_name"],
        "last_name": row["last_name"],
        "phone_number": row["phone_number"],
        "profile_image_url": row["profile_image_url"],
        "auth_provider": row["auth_provider"],
        "role": row["role"],
        "is_phone_verified": row["is_phone_verified"],
        "is_profile_complete": row["is_profile_complete"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


async def _get_current_firebase_user(authorization: str | None) -> dict:
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing authorization header",
        )

    try:
        scheme, token = authorization.split(" ", 1)
        if scheme.lower() != "bearer":
            raise ValueError("Invalid authorization scheme")
    except ValueError:
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header format",
        )

    decoded = await verify_firebase_token(token)
    if not decoded:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
        )

    staff_actor = current_staff_actor()
    if staff_actor and staff_actor["staff_firebase_uid"] == decoded.get("uid"):
        return {
            **decoded,
            "actor_uid": decoded["uid"],
            "uid": staff_actor["owner_firebase_uid"],
            "provider_staff": staff_actor,
        }

    return decoded


@router.get("/me")
async def get_my_account(
    authorization: str | None = Header(default=None),
) -> dict:
    firebase_user = await _get_current_firebase_user(authorization)
    account_uid = firebase_user.get("actor_uid") or firebase_user["uid"]
    firebase_email = (firebase_user.get("email") or "").strip().lower() or None
    async with get_db_connection() as connection:
        row = await connection.fetchrow(
            """
            UPDATE users
            SET email = coalesce($2, email),
                updated_at = CASE
                    WHEN $2::text IS NOT NULL AND email IS DISTINCT FROM $2
                    THEN now()
                    ELSE updated_at
                END
            WHERE firebase_uid = $1
            RETURNING *
            """,
            account_uid,
            firebase_email,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="User profile not found.")
    return _user_response(dict(row))


@router.patch("/me")
async def update_my_account(
    body: PersonalInfoUpdate,
    authorization: str | None = Header(default=None),
) -> dict:
    firebase_user = await _get_current_firebase_user(authorization)
    account_uid = firebase_user.get("actor_uid") or firebase_user["uid"]
    async with get_db_connection() as connection:
        row = await connection.fetchrow(
            """
            UPDATE users
            SET first_name = $2,
                last_name = $3,
                is_profile_complete = true,
                updated_at = now()
            WHERE firebase_uid = $1
            RETURNING *
            """,
            account_uid,
            body.first_name.strip(),
            body.last_name.strip() or None,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="User profile not found.")
    return _user_response(dict(row))


@router.post('/signup', response_model=AuthResponse)
async def sign_up(body: SignUpRequest):
    email = body.email.strip().lower()
    display_name_parts = [
        part.strip() for part in [body.first_name, body.last_name] if part and part.strip()
    ]
    display_name = " ".join(display_name_parts) or None

    log.info(f"Attempting to create Firebase user for email: {email}")
    try:
        firebase_uid = await create_firebase_user_rest(
            email=email,
            password=body.password,
            display_name=display_name,
        )
        log.info(f"Successfully created Firebase user with UID: {firebase_uid}")
    except Exception as exc:
        error_msg = str(exc)
        log.error(f"Error creating Firebase user: {error_msg}")
        if "EMAIL_EXISTS" in error_msg:
            raise HTTPException(status_code=400, detail="A user with that email already exists.")
        raise HTTPException(status_code=500, detail=error_msg)

    async with get_db_connection() as connection:
        user_row = await connection.fetchrow(
            "SELECT * FROM users WHERE firebase_uid = $1 OR email = $2",
            firebase_uid,
            email,
        )
        if not user_row:
            log.info("Inserting new user into Supabase...")
            try:
                user_row = await connection.fetchrow(
                    """
                    INSERT INTO users (
                        firebase_uid, email, first_name, last_name,
                        auth_provider, role, is_profile_complete, is_phone_verified
                    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
                    RETURNING *
                    """,
                    firebase_uid, email, body.first_name, body.last_name,
                    'email', 'user', False, False,
                )
                log.info(f"User inserted into Supabase with ID: {user_row['id']}")
            except Exception as exc:
                log.error(f"DB insert failed: {exc}", exc_info=True)
                raise HTTPException(status_code=500, detail=f"DB error: {str(exc)}")

    if not user_row:
        raise HTTPException(status_code=500, detail="Failed to create user in database.")

    access_token = create_access_token(
        data={'sub': str(user_row['id']), 'role': user_row['role']}
    )

    return AuthResponse(
        access_token=access_token,
        user={
            'id': user_row['id'],
            'firebase_uid': user_row['firebase_uid'],
            'email': user_row['email'],
            'first_name': user_row['first_name'],
            'last_name': user_row['last_name'],
            'phone_number': user_row['phone_number'],
            'profile_image_url': user_row['profile_image_url'],
            'auth_provider': user_row['auth_provider'],
            'role': user_row['role'],
            'is_phone_verified': user_row['is_phone_verified'],
            'is_profile_complete': user_row['is_profile_complete'],
        },
    )


@router.post('/firebase', response_model=AuthResponse)
async def firebase_auth(body: FirebaseTokenRequest):
    firebase_data = await verify_firebase_token(body.token)

    if not firebase_data:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Firebase token",
        )

    firebase_uid = firebase_data['uid']
    email = firebase_data.get('email')
    name = firebase_data.get('name', '')
    photo = firebase_data.get('picture')

    if not email:
        raise HTTPException(
            status_code=400,
            detail="Firebase account has no email",
        )

    firebase_info = firebase_data.get('firebase', {})
    provider = firebase_info.get('sign_in_provider', 'email')

    name_parts = name.strip().split(' ', 1)
    first_name = name_parts[0] if name_parts else None
    last_name = name_parts[1] if len(name_parts) > 1 else None

    async with get_db_connection() as connection:
        user_row = await connection.fetchrow(
            "SELECT * FROM users WHERE firebase_uid = $1",
            firebase_uid,
        )
        if not user_row:
            user_row = await connection.fetchrow(
                """
                INSERT INTO users (
                    firebase_uid,
                    email,
                    first_name,
                    last_name,
                    profile_image_url,
                    auth_provider,
                    role,
                    is_profile_complete,
                    is_phone_verified
                ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                RETURNING *
                """,
                firebase_uid,
                email.strip().lower(),
                first_name,
                last_name,
                photo,
                provider,
                'user',
                False,
                False,
            )
        else:
            user_row = await connection.fetchrow(
                """
                UPDATE users
                SET email = $2,
                    first_name = coalesce($3, first_name),
                    last_name = coalesce($4, last_name),
                    profile_image_url = coalesce($5, profile_image_url),
                    updated_at = now()
                WHERE firebase_uid = $1
                RETURNING *
                """,
                firebase_uid,
                email.strip().lower(),
                first_name,
                last_name,
                photo,
            )

    access_token = create_access_token(
        data={
            'sub': str(user_row['id']),
            'role': user_row['role'],
        }
    )

    return AuthResponse(
        access_token=access_token,
        user={
            'id': user_row['id'],
            'firebase_uid': user_row['firebase_uid'],
            'email': user_row['email'],
            'first_name': user_row['first_name'],
            'last_name': user_row['last_name'],
            'phone_number': user_row['phone_number'],
            'profile_image_url': user_row['profile_image_url'],
            'auth_provider': user_row['auth_provider'],
            'role': user_row['role'],
            'is_phone_verified': user_row['is_phone_verified'],
            'is_profile_complete': user_row['is_profile_complete'],
        },
    )
