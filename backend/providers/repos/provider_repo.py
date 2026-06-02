from typing import Any

from backend.providers.schema.schema import ProviderRegistrationRequest


async def upsert_provider_registration(
    db: Any,
    firebase_uid: str,
    provider_in: ProviderRegistrationRequest,
) -> dict[str, Any]:
    user_row = await db.fetchrow(
        """
        SELECT id
        FROM users
        WHERE firebase_uid = $1;
        """,
        firebase_uid,
    )
    if user_row is None:
        raise ValueError("User profile must be synced before provider registration")

    user_id = user_row["id"]
    existing_provider = await db.fetchrow(
        """
        SELECT id
        FROM providers
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1;
        """,
        user_id,
    )

    if existing_provider is not None:
        row = await db.fetchrow(
            """
            UPDATE providers
            SET
                provider_type = $2,
                provider_name = $3,
                business_name = $4,
                logo_url = $5,
                year_started = $6,
                primary_city = $7,
                description = $8,
                updated_at = NOW()
            WHERE id = $1
            RETURNING
                id,
                user_id,
                provider_type,
                provider_name,
                business_name,
                logo_url,
                year_started,
                primary_city,
                description,
                status,
                is_verified,
                created_at,
                updated_at;
            """,
            existing_provider["id"],
            provider_in.provider_type,
            provider_in.provider_name,
            provider_in.business_name,
            provider_in.logo_url,
            provider_in.year_started,
            provider_in.primary_city,
            provider_in.description,
        )
        return _serialize_provider(row)

    row = await db.fetchrow(
        """
        INSERT INTO providers (
            user_id,
            provider_type,
            provider_name,
            business_name,
            logo_url,
            year_started,
            primary_city,
            description,
            status
        )
        VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, 'draft'
        )
        RETURNING
            id,
            user_id,
            provider_type,
            provider_name,
            business_name,
            logo_url,
            year_started,
            primary_city,
            description,
            status,
            is_verified,
            created_at,
            updated_at;
        """,
        user_id,
        provider_in.provider_type,
        provider_in.provider_name,
        provider_in.business_name,
        provider_in.logo_url,
        provider_in.year_started,
        provider_in.primary_city,
        provider_in.description,
    )

    return _serialize_provider(row)


async def get_provider_by_firebase_uid(
    db: Any,
    firebase_uid: str,
) -> dict[str, Any]:
    row = await db.fetchrow(
        """
        SELECT
            providers.id,
            providers.user_id,
            providers.provider_type,
            providers.provider_name,
            providers.business_name,
            providers.logo_url,
            providers.year_started,
            providers.primary_city,
            providers.description,
            providers.status,
            providers.is_verified,
            providers.created_at,
            providers.updated_at
        FROM providers
        JOIN users ON users.id = providers.user_id
        WHERE users.firebase_uid = $1
        ORDER BY providers.created_at DESC
        LIMIT 1;
        """,
        firebase_uid,
    )
    if row is None:
        raise ValueError("Provider profile not found for this user")

    return _serialize_provider(row)


def _serialize_provider(row: Any) -> dict[str, Any]:
    data = dict(row)
    for key in ("id", "user_id"):
        data[key] = str(data[key])
    for key in ("created_at", "updated_at"):
        if data.get(key) is not None:
            data[key] = data[key].isoformat()
    return data
