from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any

import resend
from fastapi import APIRouter, Header, HTTPException, Request, status

from backend.core.config import settings
from backend.db.session import get_db_connection


router = APIRouter(prefix="/webhooks", tags=["webhooks"])
log = logging.getLogger(__name__)

_MAX_BODY_CHARS = 250_000


async def ensure_resend_webhook_schema() -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS inbound_support_emails (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                webhook_event_id text NOT NULL UNIQUE,
                resend_email_id text NOT NULL UNIQUE,
                sender text NOT NULL,
                recipients text[] NOT NULL DEFAULT '{}',
                cc text[] NOT NULL DEFAULT '{}',
                subject text NOT NULL DEFAULT '(no subject)',
                body_text text,
                body_html text,
                reply_to text[] NOT NULL DEFAULT '{}',
                attachment_metadata jsonb NOT NULL DEFAULT '[]'::jsonb,
                message_id text,
                status text NOT NULL DEFAULT 'unread',
                received_at timestamptz NOT NULL,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS inbound_support_emails_status_received_idx
                ON inbound_support_emails(status, received_at DESC);
            """
        )


def _trim_body(value: Any) -> str | None:
    if value is None:
        return None
    clean = str(value)
    return clean[:_MAX_BODY_CHARS]


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def _received_at(value: Any) -> datetime:
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def _attachment_metadata(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    result: list[dict[str, Any]] = []
    for attachment in value:
        if not isinstance(attachment, dict):
            continue
        result.append(
            {
                key: attachment.get(key)
                for key in ("id", "filename", "content_type", "content_disposition", "content_id")
                if attachment.get(key) is not None
            }
        )
    return result


@router.post("/resend", status_code=status.HTTP_200_OK)
async def receive_resend_webhook(
    request: Request,
    svix_id: str | None = Header(default=None, alias="svix-id"),
    svix_timestamp: str | None = Header(default=None, alias="svix-timestamp"),
    svix_signature: str | None = Header(default=None, alias="svix-signature"),
) -> dict[str, Any]:
    webhook_secret = (settings.RESEND_WEBHOOK_SECRET or "").strip()
    if not webhook_secret:
        log.error("RESEND_WEBHOOK_SECRET is not configured")
        raise HTTPException(status_code=503, detail="Email receiving is not configured.")

    raw_body = await request.body()
    try:
        event = resend.Webhooks.verify(
            {
                "payload": raw_body.decode("utf-8"),
                "headers": {
                    "id": svix_id or "",
                    "timestamp": svix_timestamp or "",
                    "signature": svix_signature or "",
                },
                "webhook_secret": webhook_secret,
            }
        )
    except (UnicodeDecodeError, ValueError) as exc:
        log.warning("Rejected invalid Resend webhook: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid webhook signature.") from exc

    event_type = str(event.get("type") or "")
    if event_type != "email.received":
        return {"ok": True, "ignored": True, "event_type": event_type}

    event_data = event.get("data")
    if not isinstance(event_data, dict):
        raise HTTPException(status_code=400, detail="Webhook data is missing.")
    email_id = str(event_data.get("email_id") or "").strip()
    if not email_id:
        raise HTTPException(status_code=400, detail="Received email ID is missing.")

    async with get_db_connection() as db:
        already_saved = await db.fetchval(
            "SELECT EXISTS(SELECT 1 FROM inbound_support_emails WHERE webhook_event_id=$1)",
            svix_id,
        )
    if already_saved:
        return {"ok": True, "duplicate": True, "email_id": email_id}

    if not settings.RESEND_API_KEY:
        raise HTTPException(status_code=503, detail="Resend API access is not configured.")
    resend.api_key = settings.RESEND_API_KEY
    try:
        email = await resend.Emails.Receiving.get_async(email_id)
    except Exception as exc:
        log.exception("Could not retrieve received Resend email %s", email_id)
        raise HTTPException(status_code=502, detail="Could not retrieve received email.") from exc

    sender = str(email.get("from") or event_data.get("from") or "Unknown sender").strip()
    subject = str(email.get("subject") or event_data.get("subject") or "(no subject)").strip()
    recipients = _string_list(email.get("to") or event_data.get("to"))
    received_at = _received_at(email.get("created_at") or event_data.get("created_at"))
    attachments = _attachment_metadata(email.get("attachments"))

    async with get_db_connection() as db:
        await db.execute(
            """
            INSERT INTO inbound_support_emails(
                webhook_event_id, resend_email_id, sender, recipients, cc,
                subject, body_text, body_html, reply_to, attachment_metadata,
                message_id, received_at
            ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12)
            ON CONFLICT(webhook_event_id) DO NOTHING
            """,
            svix_id,
            email_id,
            sender,
            recipients,
            _string_list(email.get("cc")),
            subject or "(no subject)",
            _trim_body(email.get("text")),
            _trim_body(email.get("html")),
            _string_list(email.get("reply_to")),
            json.dumps(attachments),
            str(email.get("message_id") or event_data.get("message_id") or "") or None,
            received_at,
        )

    log.info("Stored inbound support email %s from %s", email_id, sender)
    return {"ok": True, "email_id": email_id}
