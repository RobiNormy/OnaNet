from __future__ import annotations

import asyncio
import json
import logging
from html import escape
from typing import Any
from uuid import UUID

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from backend.core.config import settings
from backend.db.session import get_db_connection
from backend.services.email_service import email_service
from backend.services.subscription_services import get_provider_tier


logger = logging.getLogger(__name__)
MAX_ATTEMPTS = 5
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_fcm_credentials: service_account.Credentials | None = None
_fcm_credentials_lock = asyncio.Lock()


class NotificationChannelNotConfigured(RuntimeError):
    pass


def channels_for_limits(
    limits: dict[str, Any], *, sms_enabled: bool
) -> tuple[str, ...]:
    channels: list[str] = []
    if limits.get("push_request_alerts"):
        channels.append("push")
    if limits.get("external_alerts"):
        channels.append("email")
        if sms_enabled:
            channels.append("sms")
    return tuple(channels)


async def enqueue_installation_request_notifications(request_id: UUID) -> None:
    async with get_db_connection() as db:
        request = await db.fetchrow(
            "SELECT provider_id FROM installation_requests WHERE id=$1",
            request_id,
        )
    if request is None:
        return

    provider_id = request["provider_id"]
    _, limits = await get_provider_tier(provider_id)
    channels = channels_for_limits(
        limits,
        sms_enabled=settings.PRO_SMS_ALERTS_ENABLED,
    )
    if not channels:
        return

    job_ids: list[UUID] = []
    async with get_db_connection() as db:
        for channel in channels:
            job_id = await db.fetchval(
                """
                INSERT INTO notification_jobs(
                    installation_request_id, provider_id, channel, kind
                ) VALUES($1,$2,$3,'new_request')
                ON CONFLICT(installation_request_id, channel, kind)
                DO NOTHING
                RETURNING id
                """,
                request_id,
                provider_id,
                channel,
            )
            if job_id is not None:
                job_ids.append(job_id)

        if limits.get("auto_request_reminders"):
            delay = int(limits.get("request_reminder_delay_minutes") or 120)
            for channel in channels:
                await db.execute(
                    """
                    INSERT INTO notification_jobs(
                        installation_request_id, provider_id, channel, kind,
                        available_at
                    ) VALUES($1,$2,$3,'request_reminder',now()+($4::int*interval '1 minute'))
                    ON CONFLICT(installation_request_id, channel, kind) DO NOTHING
                    """,
                    request_id,
                    provider_id,
                    channel,
                    delay,
                )

    for job_id in job_ids:
        await _process_job(job_id)


async def recover_stale_notification_jobs() -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE notification_jobs
            SET status='pending', updated_at=now(),
                last_error=coalesce(last_error, 'Recovered after worker restart')
            WHERE status='processing' AND updated_at < now()-interval '10 minutes'
            """
        )


async def run_notification_worker(poll_seconds: int = 60) -> None:
    while True:
        try:
            await process_due_notification_jobs()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Notification worker cycle failed")
        await asyncio.sleep(max(poll_seconds, 10))


async def process_due_notification_jobs(limit: int = 50) -> dict[str, int]:
    async with get_db_connection() as db:
        rows = await db.fetch(
            """
            SELECT id
            FROM notification_jobs
            WHERE status='pending' AND available_at <= now()
            ORDER BY available_at
            LIMIT $1
            """,
            max(1, min(limit, 100)),
        )
    sent = failed = 0
    for row in rows:
        if await _process_job(row["id"]):
            sent += 1
        else:
            failed += 1
    return {"processed": len(rows), "sent": sent, "failed": failed}


async def _claim_job(job_id: UUID) -> Any | None:
    async with get_db_connection() as db:
        return await db.fetchrow(
            """
            UPDATE notification_jobs
            SET status='processing', attempts=attempts+1, updated_at=now()
            WHERE id=$1 AND status='pending' AND available_at <= now()
            RETURNING *
            """,
            job_id,
        )


async def _process_job(job_id: UUID) -> bool:
    job = await _claim_job(job_id)
    if job is None:
        return False
    try:
        context = await _request_context(job["installation_request_id"])
        if context is None or (
            job["kind"] == "request_reminder"
            and context["status"] not in {"pending", "new"}
        ):
            await _finish(job_id, "cancelled")
            return True
        if job["channel"] == "email":
            await _send_email(job, context)
        elif job["channel"] == "push":
            await _send_push(job, context)
        elif job["channel"] == "sms":
            raise RuntimeError("Africa's Talking SMS alerts are not enabled yet")
        await _finish(job_id, "sent")
        return True
    except NotificationChannelNotConfigured as exc:
        logger.info("Notification job %s deferred: %s", job_id, exc)
        await _defer_unconfigured(job, str(exc))
        return False
    except Exception as exc:
        logger.exception("Notification job %s failed", job_id)
        await _retry_or_fail(job, str(exc))
        return False


async def _request_context(request_id: UUID) -> Any | None:
    async with get_db_connection() as db:
        return await db.fetchrow(
            """
            SELECT ir.id, ir.provider_id, ir.status, ir.preferred_date,
                   p.provider_name, p.user_id AS owner_id,
                   owner.email AS owner_email, pkg.package_name
            FROM installation_requests ir
            JOIN providers p ON p.id=ir.provider_id
            JOIN users owner ON owner.id=p.user_id
            JOIN provider_packages pkg ON pkg.id=ir.package_id
            WHERE ir.id=$1
            """,
            request_id,
        )


def _copy(kind: str, package_name: str) -> tuple[str, str]:
    if kind == "request_reminder":
        return (
            "Installation request still waiting",
            f"A customer is still waiting for your response about {package_name}.",
        )
    return (
        "New installation request",
        f"A customer requested {package_name}. Open OnaNet to respond.",
    )


async def _send_email(job: Any, context: Any) -> None:
    subject, body = _copy(job["kind"], str(context["package_name"]))
    await email_service.send(
        to=str(context["owner_email"]),
        subject=subject,
        html=f"<h1>{escape(subject)}</h1><p>{escape(body)}</p>",
        text=body,
        tags={"category": job["kind"]},
        idempotency_key=f"notification-{job['id']}",
    )


async def _send_push(job: Any, context: Any) -> None:
    target_project = (settings.FCM_TARGET_PROJECT_ID or "").strip()
    if not target_project or not (settings.FCM_SERVICE_ACCOUNT_JSON or "").strip():
        raise NotificationChannelNotConfigured("Direct FCM is not configured")

    async with get_db_connection() as db:
        rows = await db.fetch(
            """
            SELECT DISTINCT device.token
            FROM push_notification_devices device
            WHERE device.enabled=true AND device.user_id IN (
                SELECT $1::uuid
                UNION
                SELECT staff.user_id
                FROM provider_staff_accounts staff
                WHERE staff.provider_id=$2 AND staff.is_active=true
                  AND coalesce((staff.permissions->'installation_requests'->>'view')::boolean,false)
            )
            """,
            context["owner_id"],
            context["provider_id"],
        )
    tokens = [str(row["token"]) for row in rows]
    if not tokens:
        return
    title, body = _copy(job["kind"], str(context["package_name"]))
    access_token = await _fcm_access_token()
    endpoint = (
        f"https://fcm.googleapis.com/v1/projects/{target_project}/messages:send"
    )
    invalid_tokens: list[str] = []
    async with httpx.AsyncClient(timeout=15.0) as client:
        for token in tokens:
            response = await client.post(
                endpoint,
                headers={"Authorization": f"Bearer {access_token}"},
                json={
                    "message": {
                        "token": token,
                        "notification": {"title": title, "body": body},
                        "data": {
                            "route": "/provider/installation-requests",
                            "request_id": str(context["id"]),
                        },
                        "android": {
                            "priority": "high",
                            "notification": {"channel_id": "onanet_updates"},
                        },
                    }
                },
            )
            if response.status_code < 400:
                continue
            error_body = response.text
            if response.status_code in {400, 404} and any(
                marker in error_body
                for marker in ("UNREGISTERED", "INVALID_ARGUMENT")
            ):
                invalid_tokens.append(token)
                continue
            response.raise_for_status()

    if invalid_tokens:
        async with get_db_connection() as db:
            await db.execute(
                """
                UPDATE push_notification_devices
                SET enabled=false, updated_at=now()
                WHERE token=ANY($1::text[])
                """,
                invalid_tokens,
            )


async def _fcm_access_token() -> str:
    global _fcm_credentials
    async with _fcm_credentials_lock:
        if _fcm_credentials is None:
            raw_credentials = (settings.FCM_SERVICE_ACCOUNT_JSON or "").strip()
            try:
                credentials_info = json.loads(raw_credentials)
            except (TypeError, json.JSONDecodeError) as exc:
                raise NotificationChannelNotConfigured(
                    "FCM service-account JSON is invalid"
                ) from exc
            _fcm_credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=[FCM_SCOPE],
            )

        if not _fcm_credentials.valid:
            await asyncio.to_thread(
                _fcm_credentials.refresh,
                GoogleAuthRequest(),
            )
        if not _fcm_credentials.token:
            raise RuntimeError("Google did not return an FCM access token")
        return _fcm_credentials.token


async def _finish(job_id: UUID, status: str) -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE notification_jobs
            SET status=$2, sent_at=CASE WHEN $2='sent' THEN now() ELSE sent_at END,
                last_error=NULL, updated_at=now()
            WHERE id=$1
            """,
            job_id,
            status,
        )


async def _retry_or_fail(job: Any, error: str) -> None:
    attempts = int(job["attempts"])
    terminal = attempts >= MAX_ATTEMPTS
    delay_minutes = min(2 ** max(attempts - 1, 0), 30)
    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE notification_jobs
            SET status=$2,
                available_at=CASE WHEN $2='pending'
                    THEN now()+($3::int*interval '1 minute') ELSE available_at END,
                last_error=$4, updated_at=now()
            WHERE id=$1
            """,
            job["id"],
            "failed" if terminal else "pending",
            delay_minutes,
            error[:1000],
        )


async def _defer_unconfigured(job: Any, error: str) -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE notification_jobs
            SET status='pending', attempts=greatest(attempts-1, 0),
                available_at=now()+interval '6 hours',
                last_error=$2, updated_at=now()
            WHERE id=$1
            """,
            job["id"],
            error[:1000],
        )
