from typing import Any
from uuid import UUID

from backend.providers.schema.provider_coverage_schema import (
    ProviderCoverageAreaCreate,
)


class CoverageAreaLimitExceeded(ValueError):
    def __init__(self, tier: str, limit: int) -> None:
        self.tier = tier
        self.limit = limit
        super().__init__(
            f"Your {tier.capitalize()} plan allows up to {limit} coverage areas."
        )


async def replace_provider_coverage_areas(
    db: Any,
    provider_id: UUID,
    firebase_uid: str,
    coverage_areas: list[ProviderCoverageAreaCreate],
    *,
    tier: str,
    max_coverage_areas: int | None,
) -> list[dict[str, Any]]:
    await _get_owned_provider(db, provider_id, firebase_uid)

    if max_coverage_areas is not None and len(coverage_areas) > max_coverage_areas:
        raise CoverageAreaLimitExceeded(tier, max_coverage_areas)

    async with db.transaction():
        await db.execute(
            """
            DELETE FROM provider_coverage_areas
            WHERE provider_id = $1;
            """,
            provider_id,
        )

        rows = []
        for area in coverage_areas:
            row = await db.fetchrow(
                """
                INSERT INTO provider_coverage_areas (
                    provider_id,
                    area_name,
                    latitude,
                    longitude,
                    radius_km
                )
                VALUES ($1, $2, $3, $4, $5)
                RETURNING
                    id,
                    provider_id,
                    area_name,
                    latitude,
                    longitude,
                    radius_km;
                """,
                provider_id,
                area.area_name,
                area.latitude,
                area.longitude,
                area.radius_km,
            )
            rows.append(_serialize_coverage_area(row))

    return rows


async def get_provider_coverage_areas(
    db: Any,
    provider_id: UUID,
    firebase_uid: str,
) -> list[dict[str, Any]]:
    await _get_owned_provider(db, provider_id, firebase_uid)

    rows = await db.fetch(
        """
        SELECT
            id,
            provider_id,
            area_name,
            latitude,
            longitude,
            radius_km
        FROM provider_coverage_areas
        WHERE provider_id = $1
        ORDER BY created_at ASC;
        """,
        provider_id,
    )

    return [_serialize_coverage_area(row) for row in rows]


async def _get_owned_provider(
    db: Any,
    provider_id: UUID,
    firebase_uid: str,
) -> Any:
    provider = await db.fetchrow(
        """
        SELECT providers.id
        FROM providers
        JOIN users ON users.id = providers.user_id
        WHERE providers.id = $1
          AND users.firebase_uid = $2;
        """,
        provider_id,
        firebase_uid,
    )
    if provider is None:
        raise ValueError("Provider profile not found for this user")

    return provider


def _serialize_coverage_area(row: Any) -> dict[str, Any]:
    data = dict(row)
    data["id"] = str(data["id"])
    data["provider_id"] = str(data["provider_id"])
    data["latitude"] = float(data["latitude"])
    data["longitude"] = float(data["longitude"])
    data["radius_km"] = float(data["radius_km"])
    return data
