from __future__ import annotations
import logging
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from backend.core.config import settings
from backend.db.session import get_db_connection

logger = logging.getLogger(__name__)

class InstallationRequestError(Exception):
    """Base - caller maps to 400."""

class UserNotFound(InstallationRequestError):
    """The firebase_uid didn't resolve to a row in users"""

class PhoneNotVerified(InstallationRequestError):
    """User hasn't completed OTP verification yet - this is the spam gate."""

class ProviderOrPackageMissing(InstallationRequestError):
    """provideer_id or package_id didnt resolve, or they don't belong together."""

class IncompleteAddress(InstallationRequestError):
    """User gave us an estate but no unit identifier."""


@dataclass(slots=True)

class InstallationRequestResult:
    id:UUID
    user_id:UUID
    provider_id:UUID
    package_id: UUID

    phone_e164: str
    gps_location: str | None
    estate_or_building: str
    house_or_appartment: str | None
    landmark: str | None

    preferred_date: str
    preferred_time: str

    status: str
    created_at: str
    updated_at: str

def _row_to_result(row: dict[str,Any])-> InstallationRequestResult:
    return InstallationRequestResult(
        id = row["id"],
        user_id=row["user_id"],
        package_id=row["package_id"],
        phone_e164=row["phone_e164"],
        gps_location=row["gps_location"],
        estate_or_building=row["estate_or_building"],
        house_or_appartment=row["house_or_appartment"],
        landmark=row["landmark"],
        preferred_date=row["preferred_date"].isoformat(),
        preferred_time=row["preferred_time"].isoformart(),
        status=row["status"],
        created_at=row["created_at"].isoformart(),
        updated_at=row["updated_at"].isoformat(),
    
    )

class InstallationRequestService:
    async def create(
        self,
            *,
        user_id:UUID,
        provider_id: UUID,
        package_id:UUID,
        phone_e164:str,
        gps_location: str | None,
        estate_or_building: str,
        house_or_apartment: str,
        landmark: str | None,
        preferred_date: Any,
        preferred_time: Any,
    ) -> InstallationRequestResult:
        estate = (estate_or_building or "").strip()
        unit = (house_or_apartment or "").strip() or None
        land = (landmark or "").strip() or None

        if not estate:
            raise IncompleteAddress("Estate or building is required.")
        
        if not unit and not land:
            raise IncompleteAddress(
                "Tell us how to find you - house number, plot or a landmark"
            )
        
        async with get_db_connection() as conn:
            user_row = await conn.fetchrow(
                "SELECT id,is_phone_verified FROM users WHERE id = $1",
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
                """
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
                
                RETURNING
                    id, user_id, provider_id, package_id,
                    phone_e164,gps_location,
                    estate_or_building, house_or_apartment, landmark,
                    preferred_date, preferred_time,
                    status, created_at, updated_at

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
            row["id"],user_id,provider_id,package_id,
        )

        return _row_to_result(dict(row))

async def list_for_user(self,*,user_id:UUID)-> list[InstallationRequestResult]:
    async with get_db_connection() as conn:
        rows = await conn.fetch(
            """
            SELECT

                id,user_id,provider_id,package_id,

                phone_e164,gps_location,

                estate_or_building,house_or_apartment,landmark,

                preferre_date,preferred_time,

                status,created_at,updated_at

              FROM installation requests

            WHERE user_id = $1

            ORDER BY created_at DESC

            """,
            user_id,
        )
    return [_row_to_result(dict(r)) for r in rows]


def get_installation_request_service() -> InstallationRequestService:
    return InstallationRequestService()    