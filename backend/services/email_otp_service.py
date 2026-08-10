from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID

from backend.core.config import settings
from backend.db.session import get_db_connection
from backend.services.email_notifications import (
    send_email_verification_otp,
    send_welcome_email,
)


class EmailOtpError(Exception):
    pass


class EmailOtpRateLimited(EmailOtpError):
    pass


class EmailOtpInvalid(EmailOtpError):
    pass


class EmailOtpNotFound(EmailOtpError):
    pass


@dataclass(frozen=True, slots=True)
class EmailOtpStartResult:
    email: str
    expires_at: datetime


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _hash_otp(otp: str) -> str:
    return hashlib.sha256(f"{otp}{settings.SECRET_KEY}".encode("utf-8")).hexdigest()


def _generate_otp() -> str:
    length = max(4, min(settings.OTP_LENGTH, 8))
    return "".join(str(secrets.randbelow(10)) for _ in range(length))


async def ensure_email_otp_schema() -> None:
    async with get_db_connection() as connection:
        await connection.execute(
            """
            ALTER TABLE users
              ADD COLUMN IF NOT EXISTS is_email_verified boolean NOT NULL DEFAULT true;

            CREATE TABLE IF NOT EXISTS email_verifications (
              id bigserial PRIMARY KEY,
              user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              email text NOT NULL,
              otp_hash text NOT NULL,
              expires_at timestamptz NOT NULL,
              attempts integer NOT NULL DEFAULT 0,
              verified_at timestamptz,
              invalidated_at timestamptz,
              created_at timestamptz NOT NULL DEFAULT now()
            );

            CREATE INDEX IF NOT EXISTS email_verifications_user_created_idx
              ON email_verifications(user_id, created_at DESC);
            """
        )


class EmailOtpService:
    async def start(self, *, user_id: UUID) -> EmailOtpStartResult:
        if settings.DEV_OTP:
            otp = settings.DEV_OTP
        else:
            otp = _generate_otp()
        expires_at = _utcnow() + timedelta(seconds=settings.OTP_TTL_SECONDS)

        async with get_db_connection() as connection:
            user = await connection.fetchrow(
                "SELECT email FROM users WHERE id = $1",
                user_id,
            )
            if user is None:
                raise EmailOtpNotFound("User profile not found.")
            email = str(user["email"]).strip().lower()

            recent = await connection.fetchval(
                """
                SELECT COUNT(*) FROM email_verifications
                WHERE user_id = $1
                  AND created_at > now() - interval '1 hour'
                """,
                user_id,
            )
            if recent is not None and recent >= settings.OTP_RATE_LIMIT_PER_HOUR:
                raise EmailOtpRateLimited(
                    "Too many verification codes requested. Try again in a few minutes."
                )

            await connection.execute(
                """
                UPDATE email_verifications
                   SET invalidated_at = now()
                 WHERE user_id = $1
                   AND verified_at IS NULL
                   AND invalidated_at IS NULL
                """,
                user_id,
            )
            await connection.execute(
                """
                INSERT INTO email_verifications (user_id, email, otp_hash, expires_at)
                VALUES ($1, $2, $3, $4)
                """,
                user_id,
                email,
                _hash_otp(otp),
                expires_at,
            )

        await send_email_verification_otp(
            email=email,
            otp=otp,
            expires_in_minutes=max(1, settings.OTP_TTL_SECONDS // 60),
        )
        return EmailOtpStartResult(email=email, expires_at=expires_at)

    async def verify(self, *, user_id: UUID, otp: str) -> None:
        submitted = otp.strip()
        if not submitted.isdigit() or not 4 <= len(submitted) <= 8:
            raise EmailOtpInvalid("Enter the verification code from your email.")

        async with get_db_connection() as connection:
            user = await connection.fetchrow(
                "SELECT email, first_name FROM users WHERE id = $1",
                user_id,
            )
            if user is None:
                raise EmailOtpNotFound("User profile not found.")
            async with connection.transaction():
                row = await connection.fetchrow(
                    """
                    SELECT id, otp_hash, expires_at, attempts
                      FROM email_verifications
                     WHERE user_id = $1
                       AND verified_at IS NULL
                       AND invalidated_at IS NULL
                     ORDER BY created_at DESC
                     LIMIT 1
                     FOR UPDATE
                    """,
                    user_id,
                )
                if row is None:
                    raise EmailOtpNotFound(
                        "No active email verification code. Request a new one."
                    )
                if row["attempts"] >= settings.OTP_MAX_ATTEMPTS:
                    raise EmailOtpInvalid("Too many attempts. Request a new code.")
                if row["expires_at"] < _utcnow():
                    raise EmailOtpInvalid("Code expired. Request a new one.")
                if not hmac.compare_digest(_hash_otp(submitted), row["otp_hash"]):
                    await connection.execute(
                        "UPDATE email_verifications SET attempts = attempts + 1 WHERE id = $1",
                        row["id"],
                    )
                    raise EmailOtpInvalid("Incorrect code. Please try again.")

                await connection.execute(
                    """
                    UPDATE email_verifications
                       SET verified_at = now(), attempts = attempts + 1
                     WHERE id = $1
                    """,
                    row["id"],
                )
                await connection.execute(
                    "UPDATE users SET is_email_verified = true, updated_at = now() WHERE id = $1",
                    user_id,
                )
        await send_welcome_email(str(user["email"]), user["first_name"])

    async def is_verified(self, *, user_id: UUID) -> bool:
        async with get_db_connection() as connection:
            value = await connection.fetchval(
                "SELECT is_email_verified FROM users WHERE id = $1",
                user_id,
            )
        if value is None:
            raise EmailOtpNotFound("User profile not found.")
        return bool(value)


def get_email_otp_service() -> EmailOtpService:
    return EmailOtpService()
