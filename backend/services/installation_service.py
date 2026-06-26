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
    """The firebase uid didn't resolve go to a row in 'users'."""

class PhoneNotVerified(InstallationRequestError):
    """User hasn't complete OTP verification yet"""

class ProviderOrPackageMissing(InstallationRequestError):
    """provider_id or package_id did not resove, or they dont belong together."""

class IncompleteAddress(InstallationRequestError):
    """User gave no complete address"""

@dataclass(slots = True)
class InstallationRequestResult:
    id: UUID
    user_id: UUID
    provider_id: UUID
    package_id: UUID
    phone_e164: str
    gps_location: str | None
    estate_or_building: str
    house_or_apartment: str | None
    landmark: str | None

    preferred_date: str
    status: str
    created_at: str
    updated_at: str


def _row_to_result(row: dict[str, Any]) -> InstallationRequestResult:
    return InstallationRequestResult(
        id = row["id"],
        user_id = row["user_id"],
        package_id= row["package_id"],
        provider_id=row["provider_id"],
        gps_location=row["gps_location"],
        estate_or_building=row["estate_or+building"],
        phone_e164=row["phone_e164"],
        preferred_date=row["preferred_date"]
    )
