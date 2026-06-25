from __future__ import annotations

import hashlib
import hmac
import logging
import secrets

from dataclasses import dataclass

from datetime import datetime,timedelta,timezone
from typing import Any
from uuid import UUID

from backend.core.config import settings

from backend.db.session import get_db_connection 

from backend.services.sms_provider import SmsProvider,get_sms_provider

logger = logging.getLogger(__name__)
_PEPPER = settings.SECRET_KEY.encode("utf-8")

class OtpError(Exception):
    """Base class for OTP errors that should reach the API layer."""

class OtpRateLimited(OtpError):
    """User requested too many OTPs in the rate-limit window."""

class OtpInvalid(OtpError):

    """Submitted OTP doesn't match (or expired / exhausted)."""

class OtpNotFound(OtpError):
    """No active OTP exists for this user/phone combination."""



@dataclass(slots=True)
class OtpStartResult:
    phone_e164: str
    otp: str
    expires_at: datetime

@dataclass(slots=True)
class OtpVerifyResult:
    user_id: UUID
    phone_e164: str


def _hash_otp(otp: str) -> str:
    digest = hashlib.sha256()
    digest.update(otp.encode("utf-8"))
    digest.update(_PEPPER)
    return digest.hexdigest()

def _constant_time_eq(a: str, b: str)-> bool:
    a_bytes = a.encode("utf-8")
    b_bytes = b.encode("utf-8")
    try:
        return hmac.compare_digest(a_bytes, b_bytes)
    except AttributeError:
        if len(a_bytes) != len(b_bytes):
            return False
        result = 0
        for x, y in zip(a_bytes, b_bytes):
            result |= x ^ y
        return result == 0

def _generate_otp() -> str:
    length = max (4, min(settings.OTP_LENGTH, 8))
    return "".join(str(secrets.randbelow(10)) for _ in range(length))

def _normalize_phone(phone:str) -> str:
    return phone.strip()


def _utcnow()-> datetime:
    return datetime.now(timezone.utc)


class OtpService:
    def __init__(self,sms_provider: SmsProvider | None = None)-> None:
        self._sms = sms_provider or get_sms_provider()

    async def start_verification(
            self, *, user_id: UUID, phone_e164: str
    ) -> OtpStartResult:
        phone = _normalize_phone(phone_e164)
        if not phone.startswith("+") or len(phone) < 8:
            raise OtpError("invalid phone number")

        if settings.DEV_OTP:
            otp = settings.DEV_OTP
            logger.warning("DEV_OTP %s", otp)
        else:
            otp = _generate_otp()

        otp_hash = _hash_otp(otp)
        expires_at = _utcnow() + timedelta(seconds=settings.OTP_TTL_SECONDS)

        async with get_db_connection() as conn:
            recent = await conn.fetchval(
                """
                SELECT COUNT(*) FROM phone_verifications
                WHERE phone_e164 = $1
                  AND created_at > now() - interval '1 hour'
                """,
                phone,
            )
            if recent is not None and recent >= settings.OTP_RATE_LIMIT_PER_HOUR:
                raise OtpRateLimited(
                    f"Too many OTP requests for {phone}. Try again in a few minutes"
                )

            await conn.execute(
                """
                UPDATE phone_verifications
                   SET verified_at = COALESCE(verified_at, now() - interval '1 second')
                 WHERE user_id = $1
                   AND verified_at IS NULL
                """,
                user_id,
            )

            await conn.execute(
                """
                INSERT INTO phone_verifications
                    (user_id, phone_e164, otp_hash, expires_at, attempts)
                VALUES ($1, $2, $3, $4, 0)
                """,
                user_id,
                phone,
                otp_hash,
                expires_at,
            )

        try:
            await self._sms.send(
                phone_e164=phone,
                message=(
                    f"Your OnaNet verification code is {otp}. "
                    f"Valid for {settings.OTP_TTL_SECONDS // 60} minutes. "
                    f"Do not share this code."
                ),
            )
        except Exception as exc:
            logger.exception("SMS delivery failed for %s", phone)
            raise OtpError(f"Failed to deliver OTP: {exc}") from exc

        logger.info("OTP issued: user=%s phone=%s provider=%s", user_id, phone, self._sms.name)
        return OtpStartResult(phone_e164=phone, otp=otp, expires_at=expires_at)

    async def verify(
            self, *, user_id: UUID, phone_e164: str, otp: str
    ) -> OtpVerifyResult:
        phone = _normalize_phone(phone_e164)
        submitted = otp.strip()

        async with get_db_connection() as conn:
            row: dict[str, Any] | None = await conn.fetchrow(
                """
                SELECT id, otp_hash, expires_at, attempts
                  FROM phone_verifications
                 WHERE user_id = $1
                   AND phone_e164 = $2
                   AND verified_at IS NULL
                 ORDER BY created_at DESC
                 LIMIT 1
                 FOR UPDATE
                """,
                user_id,
                phone,
            )

            if row is None:
                raise OtpNotFound(
                    "No active verification for this phone. Request a new code."
                )

            if row["attempts"] >= settings.OTP_MAX_ATTEMPTS:
                raise OtpInvalid("Too many attempts. Please request a new code")

            if row["expires_at"] < _utcnow():
                raise OtpInvalid("Code expired. Please request a new one.")

            submitted_hash = _hash_otp(submitted)
            if not _constant_time_eq(submitted_hash, row["otp_hash"]):
                await conn.execute(
                    """
                    UPDATE phone_verifications
                       SET attempts = attempts + 1
                     WHERE id = $1
                    """,
                    row["id"],
                )
                raise OtpInvalid("Incorrect code. Please try again.")

            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE phone_verifications
                       SET verified_at = now(), attempts = attempts + 1
                     WHERE id = $1
                    """,
                    row["id"],
                )
                await conn.execute(
                    """
                    UPDATE users
                       SET phone_number = $1,
                           is_phone_verified = TRUE
                     WHERE id = $2
                    """,
                    phone,
                    user_id,
                )

        logger.info("Phone verified: user=%s phone=%s", user_id, phone)
        return OtpVerifyResult(user_id=user_id, phone_e164=phone)

    async def status(self, *, user_id: UUID) -> dict[str, Any]:
        async with get_db_connection() as conn:
            row = await conn.fetchrow(
                """
                SELECT phone_number, is_phone_verified
                  FROM users
                 WHERE id = $1
                """,
                user_id,
            )

        if row is None:
            raise OtpError(f"user {user_id} not found")

        return {
            "phone_number": row["phone_number"],
            "is_phone_verified": bool(row["is_phone_verified"]),
        }

def get_otp_service()-> OtpService:
    return OtpService()