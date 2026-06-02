from typing import Any
from uuid import UUID

from backend.providers.schema.provider_contact import ProviderContactCreate


async def replace_provider_contacts(
    db: Any,
    provider_id: UUID,
    firebase_uid: str,
    contacts: list[ProviderContactCreate],
) -> list[dict[str, Any]]:
    await _get_owned_provider(db, provider_id, firebase_uid)

    async with db.transaction():
        await db.execute(
            """
            DELETE FROM provider_contacts
            WHERE provider_id = $1;
            """,
            provider_id,
        )

        rows = []
        for contact in contacts:
            row = await db.fetchrow(
                """
                INSERT INTO provider_contacts (
                    provider_id,
                    contact_type,
                    contact_value,
                    social_platform
                )
                VALUES ($1, $2, $3, $4)
                RETURNING
                    id,
                    provider_id,
                    contact_type,
                    contact_value,
                    social_platform;
                """,
                provider_id,
                contact.contact_type,
                contact.contact_value,
                contact.social_platform,
            )
            rows.append(_serialize_contact(row))

    return rows


async def get_provider_contacts(
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
            contact_type,
            contact_value,
            social_platform
        FROM provider_contacts
        WHERE provider_id = $1
        ORDER BY created_at ASC;
        """,
        provider_id,
    )

    return [_serialize_contact(row) for row in rows]


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


def _serialize_contact(row: Any) -> dict[str, Any]:
    data = dict(row)
    data["id"] = str(data["id"])
    data["provider_id"] = str(data["provider_id"])
    return data
