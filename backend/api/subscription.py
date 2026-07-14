from typing import Any
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection
from backend.services.subscription_services import (
    Tier,
    get_provider_subscription_status,
    set_provider_tier,
)

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


class SubscriptionUpgradeRequest(BaseModel):
    tier: Tier
    duration_days: int = Field(default=30, ge=1, le=366)


async def _resolve_provider_id(firebase_uid: str) -> UUID:
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT providers.id
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE users.firebase_uid = $1
            ORDER BY providers.created_at DESC
            LIMIT 1;
            """,
            firebase_uid,
        )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Provider profile not found for this user",
        )

    return row["id"]


@router.get("/status")
async def get_subscription_status(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])
    status_data = await get_provider_subscription_status(provider_id)

    return {
        "provider_id": str(provider_id),
        **status_data,
    }


@router.post("/upgrade")
async def upgrade_subscription(
    body: SubscriptionUpgradeRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    if body.tier == Tier.FREE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use a paid tier when upgrading a subscription",
        )

    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    await set_provider_tier(
        provider_id=provider_id,
        tier=body.tier.value,
        duration_days=body.duration_days,
    )
    status_data = await get_provider_subscription_status(provider_id)

    return {
        "message": "Subscription upgraded successfully",
        "provider_id": str(provider_id),
        **status_data,
    }
