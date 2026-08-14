from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from typing import Any

import resend

from backend.core.config import settings


logger = logging.getLogger(__name__)


class EmailConfigurationError(RuntimeError):
    """Raised when email delivery has not been configured."""


class EmailSendError(RuntimeError):
    """Raised when Resend rejects or fails to deliver an email request."""


@dataclass(frozen=True, slots=True)
class EmailSendResult:
    id: str


def _recipients(value: str | Iterable[str]) -> list[str]:
    values = [value] if isinstance(value, str) else list(value)
    recipients = [address.strip() for address in values if address.strip()]
    if not recipients:
        raise ValueError("At least one email recipient is required.")
    if len(recipients) > 50:
        raise ValueError("Resend accepts at most 50 recipients per email.")
    return recipients


class EmailService:
    """Async application-facing email delivery through Resend."""

    def __init__(
        self,
        *,
        api_key: str | None = None,
        from_email: str | None = None,
        reply_to: str | None = None,
        sender: Callable[..., Any] | None = None,
    ) -> None:
        self._api_key = (api_key or settings.RESEND_API_KEY or "").strip()
        self._from_email = (
            from_email or settings.RESEND_FROM_EMAIL or ""
        ).strip()
        self._reply_to = (reply_to or settings.RESEND_REPLY_TO or "").strip()
        self._sender = sender or resend.Emails.send

    async def send(
        self,
        *,
        to: str | Iterable[str],
        subject: str,
        html: str | None = None,
        text: str | None = None,
        from_email: str | None = None,
        cc: str | Iterable[str] | None = None,
        bcc: str | Iterable[str] | None = None,
        reply_to: str | None = None,
        tags: Mapping[str, str] | None = None,
        idempotency_key: str | None = None,
    ) -> EmailSendResult:
        if not self._api_key:
            raise EmailConfigurationError(
                "Resend is not configured. Add RESEND_API_KEY to the server environment."
            )
        if not self._from_email:
            raise EmailConfigurationError(
                "Resend sender is not configured. Add RESEND_FROM_EMAIL."
            )

        clean_subject = subject.strip()
        if not clean_subject:
            raise ValueError("Email subject is required.")
        if html is None and text is None:
            raise ValueError("Email HTML or text content is required.")

        effective_from = (from_email or self._from_email).strip()
        if not effective_from:
            raise EmailConfigurationError("Email sender is required.")

        payload: resend.Emails.SendParams = {
            "from": effective_from,
            "to": _recipients(to),
            "subject": clean_subject,
        }
        if html is not None:
            payload["html"] = html
        if text is not None:
            payload["text"] = text
        if cc is not None:
            payload["cc"] = _recipients(cc)
        if bcc is not None:
            payload["bcc"] = _recipients(bcc)

        # Only the dedicated support identity should invite replies. General
        # hello/security mail remains transactional even when a global support
        # reply address is configured.
        support_sender = settings.RESEND_SUPPORT_FROM_EMAIL.strip().lower()
        effective_reply_to = (reply_to or "").strip()
        if reply_to is None and effective_from.lower() == support_sender:
            effective_reply_to = self._reply_to
        if effective_reply_to:
            payload["reply_to"] = effective_reply_to
        if tags:
            payload["tags"] = [
                {"name": name, "value": value} for name, value in tags.items()
            ]

        options: resend.Emails.SendOptions | None = None
        if idempotency_key:
            options = {"idempotency_key": idempotency_key.strip()}

        resend.api_key = self._api_key
        try:
            response = await asyncio.to_thread(self._sender, payload, options)
        except Exception as exc:
            logger.exception("Resend email delivery failed")
            raise EmailSendError(f"Resend email delivery failed: {exc}") from exc

        message_id = response.get("id") if isinstance(response, dict) else None
        if not message_id:
            raise EmailSendError("Resend returned no email ID.")

        logger.info("Email accepted by Resend: id=%s", message_id)
        return EmailSendResult(id=str(message_id))


email_service = EmailService()
