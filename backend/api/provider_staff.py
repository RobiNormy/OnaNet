from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, EmailStr, Field

from backend.api.auth import _get_current_firebase_user
from backend.core.firebase import (
    create_firebase_user_rest,
    verify_firebase_password,
)
from backend.db.session import get_db_connection
from backend.services.provider_access import (
    PROVIDER_SECTIONS,
    default_permissions,
)
from backend.services.subscription_services import get_provider_tier


router = APIRouter(prefix="/provider-staff", tags=["provider-staff"])


async def ensure_provider_staff_schema() -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            CREATE EXTENSION IF NOT EXISTS pgcrypto;

            CREATE TABLE IF NOT EXISTS provider_staff_accounts (
              id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
              provider_id uuid NOT NULL
                REFERENCES providers(id) ON DELETE CASCADE,
              user_id uuid NOT NULL
                REFERENCES users(id) ON DELETE CASCADE,
              role varchar(80) NOT NULL,
              permissions jsonb NOT NULL DEFAULT '{}'::jsonb,
              is_active boolean NOT NULL DEFAULT true,
              created_by uuid NOT NULL
                REFERENCES users(id) ON DELETE RESTRICT,
              created_at timestamptz NOT NULL DEFAULT now(),
              updated_at timestamptz NOT NULL DEFAULT now(),
              CONSTRAINT provider_staff_accounts_user_unique UNIQUE(user_id),
              CONSTRAINT provider_staff_accounts_provider_user_unique
                UNIQUE(provider_id, user_id)
            );

            CREATE INDEX IF NOT EXISTS provider_staff_accounts_provider_idx
              ON provider_staff_accounts(provider_id);
            """
        )


class SectionPermission(BaseModel):
    view: bool = False
    edit: bool = False


class StaffCreate(BaseModel):
    provider_name: str = Field(min_length=2, max_length=160)
    owner_password: str = Field(min_length=6, max_length=200)
    email: EmailStr
    password: str = Field(min_length=6, max_length=200)
    display_name: str = Field(min_length=2, max_length=120)
    role: str = Field(min_length=2, max_length=80)
    permissions: dict[str, SectionPermission]


class StaffUpdate(BaseModel):
    role: str | None = Field(default=None, min_length=2, max_length=80)
    permissions: dict[str, SectionPermission] | None = None
    is_active: bool | None = None


def _normalized_permissions(
    value: dict[str, SectionPermission],
) -> dict[str, dict[str, bool]]:
    permissions = default_permissions()
    for section in PROVIDER_SECTIONS:
        permission = value.get(section)
        if permission is None:
            permissions[section] = {"view": False, "edit": False}
            continue
        can_view = permission.view or permission.edit
        permissions[section] = {
            "view": can_view,
            "edit": permission.edit,
        }
    return permissions


async def _owner_provider(firebase_uid: str) -> Any:
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT
              provider.id,
              provider.provider_name,
              provider.business_name,
              provider.subscription_tier,
              owner.id AS owner_id,
              owner.email AS owner_email,
              owner.firebase_uid AS owner_firebase_uid
            FROM providers provider
            JOIN users owner ON owner.id = provider.user_id
            WHERE owner.firebase_uid = $1
            ORDER BY provider.created_at DESC
            LIMIT 1;
            """,
            firebase_uid,
        )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Provider owner account not found.",
        )
    return row


def _serialize_staff(row: Any) -> dict[str, Any]:
    return {
        "id": str(row["id"]),
        "email": row["email"],
        "display_name": row["display_name"],
        "role": row["role"],
        "permissions": _permissions_object(row["permissions"]),
        "is_active": row["is_active"],
        "created_at": row["created_at"].isoformat(),
    }


def _permissions_object(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {}
    return {}


@router.get("/me")
async def get_provider_account_access(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    staff = firebase_user.get("provider_staff")
    if staff:
        return {
            "is_owner": False,
            "role": staff["role"],
            "provider_id": staff["provider_id"],
            "permissions": staff["permissions"],
        }

    provider = await _owner_provider(firebase_user["uid"])
    return {
        "is_owner": True,
        "role": "Owner",
        "provider_id": str(provider["id"]),
        "permissions": default_permissions(can_edit=True),
    }


@router.get("")
async def list_provider_staff(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider = await _owner_provider(firebase_user["uid"])
    tier, limits = await get_provider_tier(provider["id"])
    async with get_db_connection() as db:
        rows = await db.fetch(
            """
            SELECT
              staff.id,
              member.email,
              trim(concat_ws(' ', member.first_name, member.last_name))
                AS display_name,
              staff.role,
              staff.permissions,
              staff.is_active,
              staff.created_at
            FROM provider_staff_accounts staff
            JOIN users member ON member.id = staff.user_id
            WHERE staff.provider_id = $1
            ORDER BY staff.created_at;
            """,
            provider["id"],
        )
    total_limit = int(limits["max_staff_accounts"])
    return {
        "tier": tier,
        "account_limit": total_limit,
        "accounts_used": len(rows) + 1,
        "staff": [_serialize_staff(row) for row in rows],
    }


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_provider_staff(
    body: StaffCreate,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider = await _owner_provider(firebase_user["uid"])
    expected_names = {
        str(provider["provider_name"] or "").strip().casefold(),
        str(provider["business_name"] or "").strip().casefold(),
    }
    if body.provider_name.strip().casefold() not in expected_names:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provider name does not match this account.",
        )
    try:
        confirmed_uid = await verify_firebase_password(
            provider["owner_email"],
            body.owner_password,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc
    if confirmed_uid != provider["owner_firebase_uid"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Owner confirmation did not match this provider.",
        )

    _, limits = await get_provider_tier(provider["id"])
    async with get_db_connection() as db:
        staff_count = await db.fetchval(
            "SELECT count(*) FROM provider_staff_accounts WHERE provider_id = $1",
            provider["id"],
        )
    if int(staff_count) + 1 >= int(limits["max_staff_accounts"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your current plan has reached its provider account limit.",
        )

    email = body.email.strip().lower()
    names = body.display_name.strip().split(" ", 1)
    try:
        firebase_uid = await create_firebase_user_rest(
            email=email,
            password=body.password,
            display_name=body.display_name.strip(),
        )
    except Exception as exc:
        message = str(exc)
        if "EMAIL_EXISTS" in message:
            message = "That staff email already has an OnaNet account."
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    permissions = _normalized_permissions(body.permissions)
    async with get_db_connection() as db:
        async with db.transaction():
            member = await db.fetchrow(
                """
                INSERT INTO users(
                  firebase_uid, email, first_name, last_name,
                  auth_provider, role, is_profile_complete, is_phone_verified
                )
                VALUES($1,$2,$3,$4,'email','provider_staff',true,false)
                RETURNING id;
                """,
                firebase_uid,
                email,
                names[0],
                names[1] if len(names) > 1 else None,
            )
            row = await db.fetchrow(
                """
                INSERT INTO provider_staff_accounts(
                  provider_id, user_id, role, permissions, created_by
                )
                VALUES($1,$2,$3,$4::jsonb,$5)
                RETURNING id, role, permissions, is_active, created_at;
                """,
                provider["id"],
                member["id"],
                body.role.strip(),
                json.dumps(permissions),
                provider["owner_id"],
            )
    return {
        "id": str(row["id"]),
        "email": email,
        "display_name": body.display_name.strip(),
        "role": row["role"],
        "permissions": _permissions_object(row["permissions"]),
        "is_active": row["is_active"],
        "created_at": row["created_at"].isoformat(),
    }


@router.patch("/{staff_id}")
async def update_provider_staff(
    staff_id: UUID,
    body: StaffUpdate,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider = await _owner_provider(firebase_user["uid"])
    permissions = (
        _normalized_permissions(body.permissions)
        if body.permissions is not None
        else None
    )
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            UPDATE provider_staff_accounts staff
            SET role = coalesce($3, staff.role),
                permissions = coalesce($4::jsonb, staff.permissions),
                is_active = coalesce($5, staff.is_active),
                updated_at = now()
            FROM users member
            WHERE staff.id = $1
              AND staff.provider_id = $2
              AND member.id = staff.user_id
            RETURNING
              staff.id,
              member.email,
              trim(concat_ws(' ', member.first_name, member.last_name))
                AS display_name,
              staff.role,
              staff.permissions,
              staff.is_active,
              staff.created_at;
            """,
            staff_id,
            provider["id"],
            body.role.strip() if body.role else None,
            json.dumps(permissions) if permissions is not None else None,
            body.is_active,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Staff account not found.")
    return _serialize_staff(row)
