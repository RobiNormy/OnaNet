from __future__ import annotations

from typing import Any, Literal
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection


router = APIRouter(prefix="/admin", tags=["admin"])


class DocumentDecision(BaseModel):
    status: Literal["approved", "rejected"]


class ProviderModeration(BaseModel):
    status: Literal["approved", "suspended"]
    reason: str | None = Field(default=None, max_length=1000)


def _iso(value: Any) -> str | None:
    return value.isoformat() if value is not None else None


async def _require_admin(authorization: str | None) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    account_uid = firebase_user.get("actor_uid") or firebase_user["uid"]
    async with get_db_connection() as db:
        account = await db.fetchrow(
            """
            SELECT id, email, first_name, last_name, role
            FROM users
            WHERE firebase_uid = $1
            """,
            account_uid,
        )
    if account is None or account["role"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access is required.",
        )
    return dict(account)


@router.get("/snapshot")
async def admin_snapshot(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    admin = await _require_admin(authorization)
    async with get_db_connection() as db:
        users = await db.fetch(
            """
            SELECT
                u.id, u.email, u.first_name, u.last_name, u.phone_number,
                u.profile_image_url, u.auth_provider, u.role,
                u.is_phone_verified, u.is_profile_complete, u.created_at,
                p.id AS provider_id, p.provider_name, p.status AS provider_status,
                p.subscription_tier, p.is_verified
            FROM users u
            LEFT JOIN providers p ON p.user_id = u.id
            ORDER BY u.created_at DESC
            """
        )
        providers = await db.fetch(
            """
            SELECT
                p.id, p.provider_name, p.business_name, p.provider_type,
                p.primary_city, p.logo_url, p.status, p.is_verified,
                p.subscription_tier, p.created_at, u.email,
                concat_ws(
                    ' ',
                    nullif(trim(u.first_name), ''),
                    nullif(trim(u.last_name), '')
                ) AS owner_name,
                count(DISTINCT pp.id)::int AS package_count,
                count(DISTINCT ca.id)::int AS coverage_count,
                count(DISTINCT ir.user_id) FILTER (
                    WHERE ir.status IN ('complete', 'completed')
                )::int AS customer_count
            FROM providers p
            JOIN users u ON u.id = p.user_id
            LEFT JOIN provider_packages pp ON pp.provider_id = p.id
            LEFT JOIN provider_coverage_areas ca ON ca.provider_id = p.id
            LEFT JOIN installation_requests ir ON ir.provider_id = p.id
            GROUP BY p.id, u.id
            ORDER BY p.created_at DESC
            """
        )
        documents = await db.fetch(
            """
            SELECT
                d.id, d.provider_id, d.document_type, d.file_url, d.status,
                d.created_at, p.provider_name, p.logo_url, u.email AS owner_email
            FROM provider_documents d
            JOIN providers p ON p.id = d.provider_id
            JOIN users u ON u.id = p.user_id
            ORDER BY
                CASE d.status WHEN 'pending' THEN 0 ELSE 1 END,
                d.created_at DESC
            """
        )

    return {
        "admin": {
            "id": str(admin["id"]),
            "email": admin["email"],
            "name": " ".join(
                part
                for part in [admin["first_name"], admin["last_name"]]
                if part
            )
            or admin["email"],
        },
        "users": [
            {
                **dict(row),
                "id": str(row["id"]),
                "provider_id": (
                    str(row["provider_id"]) if row["provider_id"] else None
                ),
                "created_at": _iso(row["created_at"]),
            }
            for row in users
        ],
        "providers": [
            {
                **dict(row),
                "id": str(row["id"]),
                "created_at": _iso(row["created_at"]),
            }
            for row in providers
        ],
        "documents": [
            {
                **dict(row),
                "id": str(row["id"]),
                "provider_id": str(row["provider_id"]),
                "created_at": _iso(row["created_at"]),
            }
            for row in documents
        ],
    }


@router.patch("/documents/{document_id}")
async def review_document(
    document_id: UUID,
    body: DocumentDecision,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    async with get_db_connection() as db:
        async with db.transaction():
            row = await db.fetchrow(
                """
                UPDATE provider_documents
                SET status = $2
                WHERE id = $1
                RETURNING id, provider_id, status
                """,
                document_id,
                body.status,
            )
            if row is None:
                raise HTTPException(status_code=404, detail="Document not found.")
            if body.status == "approved":
                pending_or_rejected = await db.fetchval(
                    """
                    SELECT count(*)
                    FROM provider_documents
                    WHERE provider_id = $1 AND status != 'approved'
                    """,
                    row["provider_id"],
                )
                approved_count = await db.fetchval(
                    """
                    SELECT count(*)
                    FROM provider_documents
                    WHERE provider_id = $1 AND status = 'approved'
                    """,
                    row["provider_id"],
                )
                if approved_count and not pending_or_rejected:
                    await db.execute(
                        """
                        UPDATE providers
                        SET is_verified = true, updated_at = now()
                        WHERE id = $1
                        """,
                        row["provider_id"],
                    )
            else:
                await db.execute(
                    """
                    UPDATE providers
                    SET is_verified = false, updated_at = now()
                    WHERE id = $1
                    """,
                    row["provider_id"],
                )
    return {"id": str(row["id"]), "status": row["status"]}


@router.patch("/providers/{provider_id}/moderation")
async def moderate_provider(
    provider_id: UUID,
    body: ProviderModeration,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            UPDATE providers
            SET status = $2, updated_at = now()
            WHERE id = $1
            RETURNING id, status
            """,
            provider_id,
            body.status,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Provider not found.")
    return {
        "id": str(row["id"]),
        "status": row["status"],
        "reason": body.reason,
    }
