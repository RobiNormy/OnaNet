from __future__ import annotations

import hmac
from typing import Literal

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_user
from backend.db.session import get_db_connection
from backend.core.config import settings
from backend.services.notification_dispatcher import process_due_notification_jobs


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

            CREATE TABLE IF NOT EXISTS notification_jobs (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                installation_request_id uuid NOT NULL
                    REFERENCES installation_requests(id) ON DELETE CASCADE,
                provider_id uuid NOT NULL
                    REFERENCES providers(id) ON DELETE CASCADE,
                channel text NOT NULL CHECK (channel IN ('push', 'email', 'sms')),
                kind text NOT NULL CHECK (kind IN ('new_request', 'request_reminder')),
                status text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
                attempts integer NOT NULL DEFAULT 0,
                available_at timestamptz NOT NULL DEFAULT now(),
                last_error text,
                sent_at timestamptz,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT notification_jobs_delivery_unique
                    UNIQUE(installation_request_id, channel, kind)
            );
            CREATE INDEX IF NOT EXISTS notification_jobs_due_idx
                ON notification_jobs(status, available_at);
            """
        )


@router.post("/internal/process")
async def process_notification_queue(
    x_notification_worker_secret: str | None = Header(default=None),
) -> dict[str, int]:
    configured = (settings.NOTIFICATION_WORKER_SECRET or "").strip()
    supplied = (x_notification_worker_secret or "").strip()
    if not configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Notification worker is not configured.",
        )
    if not supplied or not hmac.compare_digest(supplied, configured):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid notification worker secret.",
        )
    return await process_due_notification_jobs()


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
