from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_user
from backend.db.session import get_db_connection


router = APIRouter(prefix="/notifications", tags=["notifications"])


class DeviceRegistration(BaseModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android", "ios", "web"]
    app_version: str | None = Field(default=None, max_length=50)


class DeviceRemoval(BaseModel):
    token: str = Field(min_length=20, max_length=4096)


async def ensure_notification_schema() -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS push_notification_devices (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token text NOT NULL UNIQUE,
                platform text NOT NULL,
                app_version text,
                enabled boolean NOT NULL DEFAULT true,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                last_seen_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS push_devices_user_enabled_idx
                ON push_notification_devices(user_id, enabled);
            """
        )


async def _current_account_id(authorization: str | None) -> str:
    actor = await _get_current_user(authorization)
    account_uid = actor.get("actor_uid") or actor["uid"]
    async with get_db_connection() as db:
        user_id = await db.fetchval(
            "SELECT id FROM users WHERE firebase_uid=$1",
            account_uid,
        )
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="OnaNet account not found.",
        )
    return str(user_id)


@router.post("/devices")
async def register_push_device(
    body: DeviceRegistration,
    authorization: str | None = Header(default=None),
) -> dict[str, bool]:
    user_id = await _current_account_id(authorization)
    async with get_db_connection() as db:
        await db.execute(
            """
            INSERT INTO push_notification_devices(
                user_id, token, platform, app_version
            ) VALUES($1,$2,$3,$4)
            ON CONFLICT(token) DO UPDATE SET
                user_id=excluded.user_id,
                platform=excluded.platform,
                app_version=excluded.app_version,
                enabled=true,
                updated_at=now(),
                last_seen_at=now()
            """,
            user_id,
            body.token,
            body.platform,
            body.app_version,
        )
    return {"registered": True}


@router.delete("/devices")
async def remove_push_device(
    body: DeviceRemoval,
    authorization: str | None = Header(default=None),
) -> dict[str, bool]:
    user_id = await _current_account_id(authorization)
    async with get_db_connection() as db:
        await db.execute(
            """
            DELETE FROM push_notification_devices
            WHERE user_id=$1 AND token=$2
            """,
            user_id,
            body.token,
        )
    return {"removed": True}
