from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, time
from typing import Any
from uuid import UUID

from backend.db.session import get_db_connection

logger = logging.getLogger(__name__)

class InstallationRequestError(Exception):
    """Base - caller maps to 400."""


class UserNotFound(InstallationRequestError):
    """The firebase_uid didn't resolve to a row in users"""


class PhoneNotVerified(InstallationRequestError):
    """User hasn't completed OTP verification yet - this is the spam gate."""


class ProviderOrPackageMissing(InstallationRequestError):
    """provider_id or package_id didn't resolve, or they don't belong together."""


class IncompleteAddress(InstallationRequestError):
    """User gave us an estate but no unit identifier."""


class WrongProvider(InstallationRequestError):
    """The request exists but doesn't belong to this provider."""


class InvalidStatusTransition(InstallationRequestError):
    """The request isn't in a state that allows this transition."""


@dataclass(slots=True)
class InstallationRequestResult:
    id: UUID
    user_id: UUID
    provider_id: UUID
    package_id: UUID
    package_name: str | None

    phone_e164: str
    gps_location: str | None
    estate_or_building: str
    house_or_apartment: str | None
    landmark: str | None

    preferred_date: date
    preferred_time: time

    status: str
    decline_reason: str | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


REQUEST_COLUMNS = """
    id, user_id, provider_id, package_id,
    phone_e164, gps_location,
    estate_or_building, house_or_apartment, landmark,
    preferred_date, preferred_time,
    status, decline_reason, completed_at, created_at, updated_at
"""


def _row_to_result(row: dict[str, Any]) -> InstallationRequestResult:
    return InstallationRequestResult(
        id=row["id"],
        user_id=row["user_id"],
        provider_id=row["provider_id"],
        package_id=row["package_id"],
        package_name=row.get("package_name"),
        phone_e164=row["phone_e164"],
        gps_location=row["gps_location"],
        estate_or_building=row["estate_or_building"],
        house_or_apartment=row["house_or_apartment"],
        landmark=row["landmark"],
        preferred_date=row["preferred_date"],
        preferred_time=row["preferred_time"],
        status=row["status"],
        decline_reason=row["decline_reason"],
        completed_at=row["completed_at"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


class InstallationRequestService:
    async def create(
        self,
        *,
        user_id: UUID,
        provider_id: UUID,
        package_id: UUID,
        phone_e164: str,
        gps_location: str | None,
        estate_or_building: str,
        house_or_apartment: str | None,
        landmark: str | None,
        preferred_date: date,
        preferred_time: time,
    ) -> InstallationRequestResult:
        estate = (estate_or_building or "").strip()
        unit = (house_or_apartment or "").strip() or None
        land = (landmark or "").strip() or None

        if not estate:
            raise IncompleteAddress("Estate or building is required.")

        if not unit and not land:
            raise IncompleteAddress(
                "Tell us how to find you - house number, plot, or a landmark."
            )

        async with get_db_connection() as conn:
            user_row = await conn.fetchrow(
                "SELECT id, is_phone_verified FROM users WHERE id = $1",
                user_id,
            )

            if user_row is None:
                raise UserNotFound(f"User {user_id} not found.")

            if not user_row["is_phone_verified"]:
                raise PhoneNotVerified(
                    "Phone number must be verified before submitting an installation request."
                )

            pkg = await conn.fetchrow(
                """
                SELECT p.provider_id, p.id AS package_id
                  FROM provider_packages p
                 WHERE p.id = $1
                   AND p.provider_id = $2
                """,
                package_id,
                provider_id,
            )

            if pkg is None:
                raise ProviderOrPackageMissing(
                    "Selected package does not belong to the chosen provider or one of them no longer exists."
                )

            row = await conn.fetchrow(
                f"""
                INSERT INTO installation_requests(
                    user_id,
                    provider_id,
                    package_id,
                    phone_e164,
                    gps_location,
                    estate_or_building,
                    house_or_apartment,
                    landmark,
                    preferred_date,
                    preferred_time
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                RETURNING {REQUEST_COLUMNS}
                """,
                user_id,
                provider_id,
                package_id,
                phone_e164.strip(),
                gps_location,
                estate,
                unit,
                land,
                preferred_date,
                preferred_time,
            )

        logger.info(
            "Installation request created: id=%s user=%s provider=%s package=%s",
            row["id"],
            user_id,
            provider_id,
            package_id,
        )

        return _row_to_result(dict(row))

    async def list_for_user(
        self, *, user_id: UUID
    ) -> list[InstallationRequestResult]:
        async with get_db_connection() as conn:
            rows = await conn.fetch(
                f"""
                SELECT {REQUEST_COLUMNS}
                FROM installation_requests
                WHERE user_id = $1
                ORDER BY created_at DESC
                """,
                user_id,
            )
        return [_row_to_result(dict(r)) for r in rows]

    async def list_for_provider(
        self,
        *,
        provider_id: UUID,
        status_filter: str | None = None,
    ) -> list[InstallationRequestResult]:
        valid_statuses = {"pending", "accepted", "declined", "complete", "cancelled"}
        if status_filter is not None and status_filter not in valid_statuses:
            raise InstallationRequestError(
                f"Invalid status filter {status_filter!r}. Must be one of: "
                f"{', '.join(sorted(valid_statuses))}."
            )

        async with get_db_connection() as conn:
            if status_filter:
                rows = await conn.fetch(
                    f"""
                    SELECT
                        ir.id, ir.user_id, ir.provider_id, ir.package_id,
                        pp.package_name,
                        ir.phone_e164, ir.gps_location,
                        ir.estate_or_building, ir.house_or_apartment, ir.landmark,
                        ir.preferred_date, ir.preferred_time,
                        ir.status, ir.decline_reason, ir.completed_at,
                        ir.created_at, ir.updated_at
                    FROM installation_requests ir
                    LEFT JOIN provider_packages pp ON pp.id = ir.package_id
                    WHERE ir.provider_id = $1
                      AND ir.status = $2
                    ORDER BY ir.created_at DESC
                    """,
                    provider_id,
                    status_filter,
                )
            else:
                rows = await conn.fetch(
                    f"""
                    SELECT
                        ir.id, ir.user_id, ir.provider_id, ir.package_id,
                        pp.package_name,
                        ir.phone_e164, ir.gps_location,
                        ir.estate_or_building, ir.house_or_apartment, ir.landmark,
                        ir.preferred_date, ir.preferred_time,
                        ir.status, ir.decline_reason, ir.completed_at,
                        ir.created_at, ir.updated_at
                    FROM installation_requests ir
                    LEFT JOIN provider_packages pp ON pp.id = ir.package_id
                    WHERE ir.provider_id = $1
                    ORDER BY ir.created_at DESC
                    """,
                    provider_id,
                )
        return [_row_to_result(dict(r)) for r in rows]

    async def get_for_provider(
        self, *, request_id: UUID, provider_id: UUID
    ) -> InstallationRequestResult:
        async with get_db_connection() as conn:
            row = await conn.fetchrow(
                f"""
                SELECT {REQUEST_COLUMNS}
                FROM installation_requests
                WHERE id = $1
                """,
                request_id,
            )
        if row is None:
            raise InstallationRequestError(f"Installation request {request_id} not found.")
        if row["provider_id"] != provider_id:
            raise WrongProvider("This request does not belong to your provider account.")
        return _row_to_result(dict(row))

    async def accept(
        self, *, request_id: UUID, provider_id: UUID
    ) -> InstallationRequestResult:
        async with get_db_connection() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    SELECT provider_id, status
                    FROM installation_requests
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    request_id,
                )
                if row is None:
                    raise InstallationRequestError(
                        f"Installation request {request_id} not found."
                    )
                if row["provider_id"] != provider_id:
                    raise WrongProvider(
                        "This request does not belong to your provider account."
                    )
                if row["status"] != "pending":
                    raise InvalidStatusTransition(
                        f"Cannot accept a request with status {row['status']!r}."
                    )
                updated = await conn.fetchrow(
                    f"""
                    UPDATE installation_requests
                    SET status = 'accepted',
                        decline_reason = NULL,
                        updated_at = now()
                    WHERE id = $1
                    RETURNING {REQUEST_COLUMNS}
                    """,
                    request_id,
                )
        return _row_to_result(dict(updated))

    async def decline(
        self,
        *,
        request_id: UUID,
        provider_id: UUID,
        reason: str | None = None,
    ) -> InstallationRequestResult:
        async with get_db_connection() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    SELECT provider_id, status
                    FROM installation_requests
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    request_id,
                )
                if row is None:
                    raise InstallationRequestError(
                        f"Installation request {request_id} not found."
                    )
                if row["provider_id"] != provider_id:
                    raise WrongProvider(
                        "This request does not belong to your provider account."
                    )
                if row["status"] != "pending":
                    raise InvalidStatusTransition(
                        f"Cannot decline a request with status {row['status']!r}."
                    )
                updated = await conn.fetchrow(
                    f"""
                    UPDATE installation_requests
                    SET status = 'declined',
                        decline_reason = $2,
                        updated_at = now()
                    WHERE id = $1
                    RETURNING {REQUEST_COLUMNS}
                    """,
                    request_id,
                    reason,
                )
        return _row_to_result(dict(updated))

    async def complete(
        self, *, request_id: UUID, provider_id: UUID
    ) -> InstallationRequestResult:
        async with get_db_connection() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    SELECT provider_id, status
                    FROM installation_requests
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    request_id,
                )
                if row is None:
                    raise InstallationRequestError(
                        f"Installation request {request_id} not found."
                    )
                if row["provider_id"] != provider_id:
                    raise WrongProvider(
                        "This request does not belong to your provider account."
                    )
                if row["status"] != "accepted":
                    raise InvalidStatusTransition(
                        f"Cannot complete a request with status {row['status']!r}."
                    )
                updated = await conn.fetchrow(
                    f"""
                    UPDATE installation_requests
                    SET status = 'complete',
                        completed_at = now(),
                        updated_at = now()
                    WHERE id = $1
                    RETURNING {REQUEST_COLUMNS}
                    """,
                    request_id,
                )
        return _row_to_result(dict(updated))


def get_installation_request_service() -> InstallationRequestService:
    return InstallationRequestService()
