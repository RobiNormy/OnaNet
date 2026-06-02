from typing import Any
from uuid import UUID


async def replace_provider_services(
    db: Any,
    provider_id: UUID,
    firebase_uid: str,
    service_types: list[str],
) -> list[dict[str, Any]]:
    await _get_owned_provider(db, provider_id, firebase_uid)

    async with db.transaction():
        await db.execute(
            """
            DELETE FROM provider_services
            WHERE provider_id = $1;
            """,
            provider_id,
        )

        rows = []
        for service_type in service_types:
            row = await db.fetchrow(
                """
                INSERT INTO provider_services (
                    provider_id,
                    service_type
                )
                VALUES ($1, $2)
                RETURNING
                    id,
                    provider_id,
                    service_type;
                """,
                provider_id,
                service_type,
            )
            rows.append(_serialize_provider_service(row))

    return rows


async def get_provider_services(
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
            service_type
        FROM provider_services
        WHERE provider_id = $1
        ORDER BY created_at ASC;
        """,
        provider_id,
    )

    return [_serialize_provider_service(row) for row in rows]


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


def _serialize_provider_service(row: Any) -> dict[str, Any]:
    data = dict(row)
    data["id"] = str(data["id"])
    data["provider_id"] = str(data["provider_id"])
    return data
