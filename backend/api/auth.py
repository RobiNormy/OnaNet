import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from supabase import create_client
from backend.core.config import settings
from backend.db.session import get_db_connection
from backend.core.firebase import create_firebase_user_rest, verify_firebase_token
from backend.core.security import create_access_token
from backend.schemas.user import AuthResponse

router = APIRouter(prefix="/auth", tags=["auth"])
log = logging.getLogger(__name__)
supabase_client = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_ROLE_KEY,
)


class FirebaseTokenRequest(BaseModel):
    token: str


class SupabaseTokenRequest(BaseModel):
    token: str


class SignUpRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str | None = None
    last_name: str | None = None


def _extract_supabase_user_identity(payload: object) -> tuple[str | None, str | None, str | None]:
    if hasattr(payload, "model_dump"):
        payload = payload.model_dump()

    if hasattr(payload, "user"):
        payload = payload.user

    if not isinstance(payload, dict):
        return None, None, None

    user_id = payload.get("id") or payload.get("sub")
    email = payload.get("email")
    metadata = payload.get("user_metadata") or {}
    full_name = metadata.get("full_name") or metadata.get("name") or payload.get("name")
    return user_id, email, full_name


async def _resolve_user_identity_columns(connection) -> tuple[bool, bool]:
    rows = await connection.fetch(
        """
        SELECT column_name
          FROM information_schema.columns
         WHERE table_name = 'users'
        """
    )
    columns = {row["column_name"] for row in rows}
    has_auth_user_id = "auth_user_id" in columns
    has_auth_provider = "auth_provider" in columns
    return has_auth_user_id, has_auth_provider


async def _get_or_create_user_row(connection, *, auth_user_id: str, email: str, first_name: str | None, last_name: str | None, photo: str | None, provider: str, role: str = "user"):
    has_auth_user_id, _ = await _resolve_user_identity_columns(connection)

    if has_auth_user_id:
        user_row = await connection.fetchrow(
            "SELECT * FROM users WHERE auth_user_id = $1 OR email = $2",
            auth_user_id,
            email,
        )
        if not user_row:
            user_row = await connection.fetchrow(
                """
                INSERT INTO users (
                    auth_user_id,
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
                auth_user_id,
                email,
                first_name,
                last_name,
                photo,
                provider,
                role,
                False,
                False,
            )
        else:
            await connection.execute(
                """
                UPDATE users
                   SET auth_user_id = $1,
                       email = $2,
                       first_name = COALESCE($3, first_name),
                       last_name = COALESCE($4, last_name),
                       profile_image_url = COALESCE($5, profile_image_url),
                       auth_provider = $6
                 WHERE id = $7
                """,
                auth_user_id,
                email,
                first_name,
                last_name,
                photo,
                provider,
                user_row["id"],
            )
            user_row = await connection.fetchrow(
                "SELECT * FROM users WHERE id = $1",
                user_row["id"],
            )
    else:
        user_row = await connection.fetchrow(
            "SELECT * FROM users WHERE firebase_uid = $1 OR email = $2",
            auth_user_id,
            email,
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
                auth_user_id,
                email,
                first_name,
                last_name,
                photo,
                provider,
                role,
                False,
                False,
            )
        else:
            await connection.execute(
                """
                UPDATE users
                   SET firebase_uid = $1,
                       email = $2,
                       first_name = COALESCE($3, first_name),
                       last_name = COALESCE($4, last_name),
                       profile_image_url = COALESCE($5, profile_image_url),
                       auth_provider = $6
                 WHERE id = $7
                """,
                auth_user_id,
                email,
                first_name,
                last_name,
                photo,
                provider,
                user_row["id"],
            )
            user_row = await connection.fetchrow(
                "SELECT * FROM users WHERE id = $1",
                user_row["id"],
            )

    return user_row


async def verify_supabase_token(token: str) -> dict | None:
    try:
        response = supabase_client.auth.get_user(jwt=token)
    except Exception as exc:  # pragma: no cover - defensive branch
        log.warning("Supabase JWT verification failed: %s", exc)
        return None

    if not response:
        return None

    user_id, email, full_name = _extract_supabase_user_identity(response)
    if not user_id:
        return None

    user = getattr(response, "user", None)
    picture = None
    if isinstance(user, dict):
        picture = user.get("avatar_url")
    else:
        picture = getattr(user, "avatar_url", None)

    return {
        "auth_user_id": str(user_id),
        "uid": str(user_id),
        "email": email,
        "name": full_name or "",
        "picture": picture,
        "provider": "supabase",
        "auth_provider": "supabase",
        "firebase": {"sign_in_provider": "supabase"},
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
    if decoded:
        return decoded

    supabase_user = await verify_supabase_token(token)
    if supabase_user:
        return supabase_user

    raise HTTPException(
        status_code=401,
        detail="Invalid or expired token",
    )


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


@router.post('/supabase', response_model=AuthResponse)
async def supabase_auth(body: SupabaseTokenRequest):
    supabase_data = await verify_supabase_token(body.token)

    if not supabase_data:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Supabase token",
        )

    auth_user_id = supabase_data.get('auth_user_id') or supabase_data.get('uid')
    email = supabase_data.get('email')
    name = supabase_data.get('name', '')
    photo = supabase_data.get('picture')

    if not email:
        raise HTTPException(
            status_code=400,
            detail="Supabase account has no email",
        )

    name_parts = name.strip().split(' ', 1)
    first_name = name_parts[0] if name_parts else None
    last_name = name_parts[1] if len(name_parts) > 1 else None

    async with get_db_connection() as connection:
        user_row = await _get_or_create_user_row(
            connection,
            auth_user_id=auth_user_id,
            email=email.strip().lower(),
            first_name=first_name,
            last_name=last_name,
            photo=photo,
            provider='supabase',
            role='user',
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


@router.post('/firebase', response_model=AuthResponse)
async def firebase_auth(body: FirebaseTokenRequest):
    firebase_data = await verify_firebase_token(body.token)

    if not firebase_data:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Firebase token",
        )

    auth_user_id = firebase_data.get('auth_user_id') or firebase_data.get('uid')
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
        user_row = await _get_or_create_user_row(
            connection,
            auth_user_id=auth_user_id,
            email=email.strip().lower(),
            first_name=first_name,
            last_name=last_name,
            photo=photo,
            provider=provider,
            role='user',
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
