import logging
from fastapi import APIRouter, BackgroundTasks, Header, HTTPException
from pydantic import BaseModel, EmailStr, Field
from backend.db.session import get_db_connection
from backend.core.firebase import (
    create_firebase_user_rest,
    delete_firebase_user,
    verify_firebase_token,
)
from backend.core.security import create_access_token
from backend.schemas.user import AuthResponse
from backend.services.provider_access import current_staff_actor
from backend.services.email_notifications import send_welcome_email

router = APIRouter(prefix="/auth", tags=["auth"])
log = logging.getLogger(__name__)


async def ensure_auth_schema() -> None:
    async with get_db_connection() as connection:
        await connection.execute(
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS supabase_uid text"
        )
        await connection.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS users_supabase_uid_unique_idx
            ON users(supabase_uid)
            WHERE supabase_uid IS NOT NULL
            """
        )


@router.get('/public-config')
async def public_auth_config() -> dict[str, str]:
    """Return browser-safe Supabase configuration for OnaNet's auth pages."""
    from backend.core.config import settings

    if not settings.SUPABASE_PUBLISHABLE_KEY:
        raise HTTPException(
            status_code=503,
            detail="Password reset is temporarily unavailable.",
        )
    return {
        "supabase_url": settings.SUPABASE_URL,
        "supabase_publishable_key": settings.SUPABASE_PUBLISHABLE_KEY,
    }

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


class AccountDeletionRequest(BaseModel):
    confirmation: str = Field(min_length=6, max_length=20)


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
        "is_email_verified": row["is_email_verified"],
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

    if decoded.get("auth_system") == "supabase":
        async with get_db_connection() as connection:
            legacy_uid = await connection.fetchval(
                "SELECT firebase_uid FROM users WHERE supabase_uid = $1",
                decoded["uid"],
            )
        if legacy_uid:
            decoded = {
                **decoded,
                "supabase_uid": decoded["uid"],
                "uid": legacy_uid,
            }

    staff_actor = current_staff_actor()
    actor_auth_ids = {decoded.get("uid"), decoded.get("supabase_uid")}
    if staff_actor and staff_actor["staff_auth_uid"] in actor_auth_ids:
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


@router.post("/me/delete")
async def delete_my_account(
    body: AccountDeletionRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, bool]:
    if body.confirmation.strip().upper() != "DELETE":
        raise HTTPException(status_code=400, detail="Type DELETE to confirm account deletion.")

    firebase_user = await _get_current_firebase_user(authorization)
    if firebase_user.get("provider_staff"):
        account_uid = firebase_user.get("actor_uid")
    else:
        account_uid = firebase_user["uid"]

    async with get_db_connection() as connection:
        async with connection.transaction():
            user = await connection.fetchrow(
                """
                SELECT id, firebase_uid, supabase_uid, email, role
                FROM users
                WHERE firebase_uid=$1
                FOR UPDATE
                """,
                account_uid,
            )
            if user is None:
                raise HTTPException(status_code=404, detail="User profile not found.")
            if user["role"] == "admin":
                raise HTTPException(
                    status_code=400,
                    detail="Administrator accounts must be transferred or removed by another administrator.",
                )

            await connection.execute(
                """
                INSERT INTO admin_deleted_users (
                    deleted_user_id, firebase_uid, email, reason,
                    deleted_by_id, deleted_by_email
                ) VALUES ($1,$2,$3,'Self-service account deletion',$1,$3)
                ON CONFLICT (firebase_uid) DO UPDATE
                   SET reason='Self-service account deletion',
                       deleted_by_id=excluded.deleted_by_id,
                       deleted_by_email=excluded.deleted_by_email,
                       deleted_at=now()
                """,
                user["id"],
                user["firebase_uid"],
                user["email"],
            )
            await connection.execute(
                "DELETE FROM provider_staff_accounts WHERE created_by=$1",
                user["id"],
            )
            await connection.execute("DELETE FROM users WHERE id=$1", user["id"])

    supabase_deleted = True
    if user["supabase_uid"]:
        supabase_deleted = await delete_firebase_user(str(user["supabase_uid"]))
    firebase_deleted = await delete_firebase_user(str(user["firebase_uid"]))
    log.warning(
        "User %s (%s) deleted their OnaNet account; Firebase deleted=%s",
        user["email"],
        user["id"],
        firebase_deleted,
    )
    return {
        "deleted": True,
        "firebase_deleted": firebase_deleted,
        "supabase_deleted": supabase_deleted,
    }


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
        deleted = await connection.fetchval(
            """
            SELECT EXISTS(
                SELECT 1 FROM admin_deleted_users
                WHERE firebase_uid=$1 OR lower(email)=lower($2)
            )
            """,
            firebase_uid,
            email,
        )
        if deleted:
            raise HTTPException(
                status_code=403,
                detail="This OnaNet account has been deleted.",
            )
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
                        auth_provider, role, is_profile_complete, is_phone_verified,
                        is_email_verified
                    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                    RETURNING *
                    """,
                    firebase_uid, email, body.first_name, body.last_name,
                    'email', 'user', False, False, False,
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
            'is_email_verified': user_row['is_email_verified'],
            'is_phone_verified': user_row['is_phone_verified'],
            'is_profile_complete': user_row['is_profile_complete'],
        },
    )


@router.post('/session', response_model=AuthResponse)
@router.post('/firebase', response_model=AuthResponse, deprecated=True)
async def firebase_auth(body: FirebaseTokenRequest, background_tasks: BackgroundTasks):
    firebase_data = await verify_firebase_token(body.token)

    if not firebase_data:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired authentication token",
        )

    firebase_uid = firebase_data['uid']
    email = firebase_data.get('email')
    name = firebase_data.get('name', '')
    photo = firebase_data.get('picture')

    if not email:
        raise HTTPException(
            status_code=400,
            detail="Authenticated account has no email",
        )

    firebase_info = firebase_data.get('firebase', {})
    provider = firebase_info.get('sign_in_provider', 'email')
    email_is_verified = bool(firebase_data.get('email_verified')) or provider == 'google.com'

    name_parts = name.strip().split(' ', 1)
    first_name = name_parts[0] if name_parts else None
    last_name = name_parts[1] if len(name_parts) > 1 else None

    should_send_welcome = False
    async with get_db_connection() as connection:
        deleted = await connection.fetchval(
            """
            SELECT EXISTS(
                SELECT 1 FROM admin_deleted_users
                WHERE firebase_uid=$1 OR lower(email)=lower($2)
            )
            """,
            firebase_uid,
            email,
        )
        if deleted:
            raise HTTPException(
                status_code=403,
                detail="This OnaNet account has been deleted.",
            )
        user_row = await connection.fetchrow(
            "SELECT * FROM users WHERE firebase_uid = $1 OR supabase_uid = $1",
            firebase_uid,
        )
        if user_row:
            should_send_welcome = email_is_verified and not bool(
                user_row['is_email_verified']
            )
            user_row = await connection.fetchrow(
                """
                UPDATE users
                SET email = $2,
                    first_name = coalesce($3, first_name),
                    last_name = coalesce($4, last_name),
                    profile_image_url = coalesce($5, profile_image_url),
                    is_email_verified = is_email_verified OR $6,
                    updated_at = now()
                WHERE id = $1
                RETURNING *
                """,
                user_row["id"],
                email.strip().lower(),
                first_name,
                last_name,
                photo,
                email_is_verified,
            )
        else:
            existing_email_user = await connection.fetchrow(
                "SELECT * FROM users WHERE lower(email) = lower($1)",
                email,
            )
            if existing_email_user:
                should_send_welcome = email_is_verified and not bool(
                    existing_email_user["is_email_verified"]
                )
                user_row = await connection.fetchrow(
                    """
                    UPDATE users
                    SET supabase_uid = $1,
                        auth_provider = $2,
                        profile_image_url = coalesce($3, profile_image_url),
                        is_email_verified = is_email_verified OR $4,
                        updated_at = now()
                    WHERE id = $5
                    RETURNING *
                    """,
                    firebase_uid,
                    provider,
                    photo,
                    email_is_verified,
                    existing_email_user["id"],
                )
            else:
                should_send_welcome = email_is_verified
                user_row = await connection.fetchrow(
                    """
                    INSERT INTO users (
                        firebase_uid,
                        supabase_uid,
                        email,
                        first_name,
                        last_name,
                        profile_image_url,
                        auth_provider,
                        role,
                        is_profile_complete,
                        is_phone_verified,
                        is_email_verified
                    ) VALUES ($1,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
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
                    email_is_verified,
                )

    if should_send_welcome:
        background_tasks.add_task(
            send_welcome_email,
            str(user_row['email']),
            user_row['first_name'],
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
            'is_email_verified': user_row['is_email_verified'],
            'is_phone_verified': user_row['is_phone_verified'],
            'is_profile_complete': user_row['is_profile_complete'],
        },
    )
