from __future__ import annotations

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection

router = APIRouter(prefix="/reviews", tags=["reviews"])


async def ensure_reviews_schema() -> None:
    async with get_db_connection() as conn:
        await conn.execute(
            """
            CREATE EXTENSION IF NOT EXISTS pgcrypto;

            CREATE TABLE IF NOT EXISTS provider_reviews (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                installation_request_id uuid NOT NULL
                    REFERENCES installation_requests(id) ON DELETE CASCADE,
                user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                provider_id uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
                package_id uuid NOT NULL
                    REFERENCES provider_packages(id) ON DELETE CASCADE,
                rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment text,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT provider_reviews_one_per_request
                    UNIQUE (installation_request_id)
            );

            CREATE INDEX IF NOT EXISTS provider_reviews_provider_id_idx
                ON provider_reviews(provider_id);

            CREATE INDEX IF NOT EXISTS provider_reviews_user_id_idx
                ON provider_reviews(user_id);
            """
        )


class ReviewCreate(BaseModel):
    installation_request_id: UUID
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=1000)


class ReviewOut(BaseModel):
    id: UUID
    installation_request_id: UUID
    provider_id: UUID
    package_id: UUID
    rating: int
    comment: str | None
    customer_name: str | None
    package_name: str | None
    created_at: Any
    updated_at: Any


@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def submit_review(
    body: ReviewCreate,
    authorization: str | None = Header(default=None),
) -> Any:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as conn:
        async with conn.transaction():
            request = await conn.fetchrow(
                """
                SELECT
                    ir.id,
                    ir.user_id,
                    ir.provider_id,
                    ir.package_id,
                    ir.status,
                    pp.package_name
                FROM installation_requests ir
                LEFT JOIN provider_packages pp ON pp.id = ir.package_id
                JOIN users u ON u.id = ir.user_id
                WHERE ir.id = $1
                  AND u.firebase_uid = $2
                FOR UPDATE
                """,
                body.installation_request_id,
                firebase_user["uid"],
            )
            if request is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Completed installation request not found.",
                )
            if request["status"] not in {"complete", "completed"}:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="You can review only after the provider marks the installation complete.",
                )

            review = await conn.fetchrow(
                """
                INSERT INTO provider_reviews(
                    installation_request_id,
                    user_id,
                    provider_id,
                    package_id,
                    rating,
                    comment
                )
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (installation_request_id)
                DO UPDATE SET
                    rating = EXCLUDED.rating,
                    comment = EXCLUDED.comment,
                    updated_at = now()
                RETURNING
                    id,
                    installation_request_id,
                    provider_id,
                    package_id,
                    rating,
                    comment,
                    created_at,
                    updated_at
                """,
                request["id"],
                request["user_id"],
                request["provider_id"],
                request["package_id"],
                body.rating,
                (body.comment or "").strip() or None,
            )

            user = await conn.fetchrow(
                """
                SELECT first_name, last_name
                FROM users
                WHERE id = $1
                """,
                request["user_id"],
            )

    return _review_response(
        dict(review),
        customer_name=_customer_name(dict(user) if user else {}),
        package_name=request["package_name"],
    )


@router.get("/me", response_model=list[ReviewOut])
async def my_reviews(authorization: str | None = Header(default=None)) -> list[Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as conn:
        rows = await conn.fetch(
            """
            SELECT
                pr.id,
                pr.installation_request_id,
                pr.provider_id,
                pr.package_id,
                pr.rating,
                pr.comment,
                pr.created_at,
                pr.updated_at,
                pp.package_name,
                u.first_name,
                u.last_name
            FROM provider_reviews pr
            JOIN users u ON u.id = pr.user_id
            LEFT JOIN provider_packages pp ON pp.id = pr.package_id
            WHERE u.firebase_uid = $1
            ORDER BY pr.updated_at DESC
            """,
            firebase_user["uid"],
        )

    return [
        _review_response(
            dict(row),
            customer_name=_customer_name(dict(row)),
            package_name=row["package_name"],
        )
        for row in rows
    ]


def _customer_name(row: dict[str, Any]) -> str | None:
    parts = [
        str(row.get("first_name") or "").strip(),
        str(row.get("last_name") or "").strip(),
    ]
    name = " ".join(part for part in parts if part)
    return name or None


def _review_response(
    row: dict[str, Any],
    *,
    customer_name: str | None,
    package_name: str | None,
) -> dict[str, Any]:
    return {
        "id": row["id"],
        "installation_request_id": row["installation_request_id"],
        "provider_id": row["provider_id"],
        "package_id": row["package_id"],
        "rating": row["rating"],
        "comment": row["comment"],
        "customer_name": customer_name,
        "package_name": package_name,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }
