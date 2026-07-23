from __future__ import annotations

from datetime import datetime, timezone

from enum import Enum

from typing import Any
from uuid import UUID

from backend.db.session import get_db_connection


class Tier(str, Enum):
    FREE = "free"
    GROWTH = "growth"
    PRO = "pro"


TIER_LIMITS: dict[str, dict[str, Any]] = {
    Tier.FREE.value: {
        "max_packages": 10,
        "max_coverage_areas": 3,
        "max_photos": 0,
        "featured_in_search": False,
        "demand_intelligence_enabled": False,
        "in_app_alerts": True,
        "external_alerts": False,
        "priority_inbox": False,
        "custom_cover": False,
        "own_stats": True,
        "max_staff_accounts": 1,
    },
    Tier.GROWTH.value: {
        "max_packages": 10,
        "max_coverage_areas": 5,
        "max_photos": 3,
        "featured_in_search": "mid",
        "demand_intelligence_enabled": False,
        "in_app_alerts": True,
        "own_stats": True,
        "external_alerts": True,
        "priority_inbox": False,
        "custom_cover": False,
        "max_staff_accounts": 3,
    },

    Tier.PRO.value: {
        "max_packages": 999,
        "max_coverage_areas": None,
        "featured_in_search": "pinned",
        "max_photos": 6,
        "max_staff_accounts": 999,
        "external_alerts": True,
        "demand_intelligence_enabled": True,
        "own_stats": True,
        "priority_inbox": True,
        "custom_cover": True,
    }
}


def get_tier_limits(tier: str) -> dict[str, Any]:
    return TIER_LIMITS.get(tier, TIER_LIMITS[Tier.FREE.value])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_expired(expires_at: datetime | None, tier: str) -> bool:
    if expires_at is None or tier == Tier.FREE.value:
        return False

    now = _utcnow()
    if expires_at.tzinfo is None:
        now = now.replace(tzinfo=None)

    return expires_at < now


async def get_provider_tier(provider_id: UUID) -> tuple[str, dict[str, Any]]:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            """
            SELECT subscription_tier, subscription_expires_at
            FROM providers
            WHERE id = $1
            """,
            provider_id,
        )
    if row is None:
        return Tier.FREE.value, get_tier_limits(Tier.FREE.value)

    tier = row["subscription_tier"] or Tier.FREE.value

    expires_at = row["subscription_expires_at"]

    if _is_expired(expires_at, tier):
        tier = Tier.FREE.value
    
    return tier, get_tier_limits(tier)


async def get_provider_subscription_status(provider_id: UUID) -> dict[str, Any]:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            """
            SELECT subscription_tier, subscription_expires_at
            FROM providers
            WHERE id = $1
            """,
            provider_id,
        )

    tier = Tier.FREE.value
    expires_at = None

    if row is not None:
        tier = row["subscription_tier"] or Tier.FREE.value
        expires_at = row["subscription_expires_at"]

    is_expired = _is_expired(expires_at, tier)
    if is_expired:
        tier = Tier.FREE.value

    return {
        "tier": tier,
        "limits": get_tier_limits(tier),
        "expires_at": expires_at.isoformat() if expires_at is not None else None,
        "is_active": not is_expired,
    }


async def get_provider_tier_for_user(user_id: UUID) -> tuple[str, dict[str, Any]]:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM providers WHERE user_id = $1",
            user_id,
        )
    
    if row is None:
        return Tier.FREE.value, get_tier_limits(Tier.FREE.value)

    return await get_provider_tier(row["id"])


def has_feature(limits: dict[str, Any], feature: str) -> bool:
    return bool(limits.get(feature, False))


def within_count_limits(
    limits: dict[str, Any],
    feature: str,
    current_count: int,
) -> bool:
    cap = limits.get(feature, 0)

    if cap is None:
        return True

    return current_count < cap


async def set_provider_tier(
    provider_id: UUID,
    tier: str,
    duration_days: int | None = None,
) -> None:
    if tier not in TIER_LIMITS:
        raise ValueError(f"Unknown tier: {tier!r}")
    
    if tier == Tier.FREE.value or duration_days is None:
        async with get_db_connection() as conn:
            await conn.execute(
                """
                UPDATE providers
                SET subscription_tier = $1,
                    subscription_expires_at = NULL
                WHERE id = $2
                """,
                tier,
                provider_id,
            )
    else:
        async with get_db_connection() as conn:
            await conn.execute(
                """
                UPDATE providers
                SET subscription_tier = $1,
                    subscription_expires_at = now() + ($3::int * interval '1 day')
                WHERE id = $2
                """,
                tier,
                provider_id,
                duration_days,
            )


async def upgrade_to_growth(provider_id: UUID, duration_days: int = 30) -> None:
    await set_provider_tier(provider_id, Tier.GROWTH.value, duration_days)


async def upgrade_to_pro(provider_id: UUID, duration_days: int = 30) -> None:
    await set_provider_tier(provider_id, Tier.PRO.value, duration_days)


async def downgrade_to_free(provider_id: UUID) -> None:
    await set_provider_tier(provider_id, Tier.FREE.value, None)
