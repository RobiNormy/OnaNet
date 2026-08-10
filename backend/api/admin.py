from __future__ import annotations

import logging
from typing import Any, Literal
from urllib.parse import unquote, urlparse
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, status
import anyio
from pydantic import BaseModel, Field
from supabase import create_client

from backend.api.auth import _get_current_firebase_user
from backend.core.config import settings
from backend.core.firebase import delete_firebase_user
from backend.db.session import get_db_connection
from backend.services.email_notifications import send_provider_status_email


router = APIRouter(prefix="/admin", tags=["admin"])
log = logging.getLogger(__name__)
DOCUMENT_BUCKET = "provider-documents"
DOCUMENT_URL_MARKER = f"/storage/v1/object/public/{DOCUMENT_BUCKET}/"
supabase = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_ROLE_KEY,
)


class DocumentDecision(BaseModel):
    status: Literal["approved", "rejected"]


class ProviderModeration(BaseModel):
    status: Literal["approved", "suspended", "banned"]
    reason: str | None = Field(default=None, max_length=1000)


class AdminAction(BaseModel):
    action: str = Field(min_length=2, max_length=40)
    reason: str | None = Field(default=None, max_length=1000)
    value: str | None = Field(default=None, max_length=100)


async def ensure_admin_schema() -> None:
    """Small additive schema used by the control panel.

    Keeping moderation state separate avoids changing the public account model
    and gives us a useful audit trail.
    """
    async with get_db_connection() as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_user_moderation (
                user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                status text NOT NULL DEFAULT 'active',
                reason text,
                updated_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE TABLE IF NOT EXISTS admin_reports (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                report_type text NOT NULL,
                reporter_name text NOT NULL,
                reported_provider_id uuid REFERENCES providers(id) ON DELETE SET NULL,
                reported_name text NOT NULL,
                details text,
                status text NOT NULL DEFAULT 'open',
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE TABLE IF NOT EXISTS admin_invoices (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                invoice_number text UNIQUE NOT NULL,
                provider_id uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
                plan text NOT NULL,
                amount numeric(12,2) NOT NULL DEFAULT 0,
                period text,
                due_date date,
                status text NOT NULL DEFAULT 'pending',
                created_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE TABLE IF NOT EXISTS admin_notifications (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                provider_id uuid REFERENCES providers(id) ON DELETE CASCADE,
                user_id uuid REFERENCES users(id) ON DELETE CASCADE,
                title text NOT NULL,
                message text NOT NULL,
                created_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE TABLE IF NOT EXISTS admin_deleted_users (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                deleted_user_id uuid NOT NULL,
                firebase_uid text NOT NULL UNIQUE,
                email text NOT NULL,
                reason text NOT NULL,
                deleted_by_id uuid NOT NULL,
                deleted_by_email text NOT NULL,
                deleted_at timestamptz NOT NULL DEFAULT now()
            );
            ALTER TABLE provider_packages
                ADD COLUMN IF NOT EXISTS is_available boolean NOT NULL DEFAULT true;
            """
        )


def _iso(value: Any) -> str | None:
    return value.isoformat() if value is not None else None


def _signed_document_url(file_url: str) -> str:
    """Turn a legacy public-style URL into a short-lived private document URL."""
    parsed = urlparse(file_url)
    marker_index = parsed.path.find(DOCUMENT_URL_MARKER)
    if marker_index < 0:
        return file_url

    storage_path = unquote(
        parsed.path[marker_index + len(DOCUMENT_URL_MARKER) :]
    )
    result = supabase.storage.from_(DOCUMENT_BUCKET).create_signed_url(
        storage_path,
        15 * 60,
    )
    signed_url = result.get("signedURL") or result.get("signedUrl")
    if not signed_url:
        raise RuntimeError("Supabase did not return a signed document URL.")
    if signed_url.startswith("http"):
        return signed_url
    return f"{settings.SUPABASE_URL.rstrip('/')}{signed_url}"


def _safe_signed_document_url(file_url: str) -> str:
    try:
        return _signed_document_url(file_url)
    except Exception:
        log.warning(
            "Could not create a signed provider-document URL",
            exc_info=True,
        )
        return file_url


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
                p.subscription_tier, p.is_verified,
                coalesce(m.status, 'active') AS status,
                (SELECT count(*)::int FROM installation_requests ir
                 WHERE ir.user_id = u.id) AS ticket_count
            FROM users u
            LEFT JOIN providers p ON p.user_id = u.id
            LEFT JOIN admin_user_moderation m ON m.user_id = u.id
            ORDER BY u.created_at DESC
            """
        )
        providers = await db.fetch(
            """
            SELECT
                p.id, p.provider_name, p.business_name, p.provider_type,
                p.primary_city, p.logo_url, p.status, p.is_verified,
                p.subscription_tier, p.subscription_expires_at,
                p.created_at, u.email,
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
        packages = await db.fetch(
            """
            SELECT pp.*, p.provider_name, p.provider_type
            FROM provider_packages pp JOIN providers p ON p.id=pp.provider_id
            ORDER BY pp.created_at DESC
            """
        )
        coverage = await db.fetch(
            """
            SELECT ca.*, p.provider_name, p.provider_type
            FROM provider_coverage_areas ca JOIN providers p ON p.id=ca.provider_id
            ORDER BY p.provider_name, ca.area_name
            """
        )
        reports = await db.fetch(
            """
            SELECT r.*, p.provider_name
            FROM admin_reports r LEFT JOIN providers p ON p.id=r.reported_provider_id
            ORDER BY r.created_at DESC
            """
        )
        invoices = await db.fetch(
            """
            SELECT i.*, p.provider_name
            FROM admin_invoices i JOIN providers p ON p.id=i.provider_id
            ORDER BY i.created_at DESC
            """
        )

    # The Supabase sync storage client owns one HTTP connection pool and must
    # not be used concurrently across several worker threads. Generate URLs
    # sequentially inside one worker so snapshot requests remain reliable.
    signed_document_urls = await anyio.to_thread.run_sync(
        lambda: [_safe_signed_document_url(row["file_url"]) for row in documents]
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
                "file_url": signed_url,
            }
            for row, signed_url in zip(
                documents,
                signed_document_urls,
                strict=True,
            )
        ],
        "packages": [_json_row(row) for row in packages],
        "coverage_zones": [_json_row(row) for row in coverage],
        "reports": [_json_row(row) for row in reports],
        "invoices": [_json_row(row) for row in invoices],
    }


def _json_row(row: Any) -> dict[str, Any]:
    result = dict(row)
    for key, value in list(result.items()):
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        elif key == "id" or key.endswith("_id"):
            result[key] = str(value) if value is not None else None
        elif value.__class__.__name__ == "Decimal":
            result[key] = float(value)
    return result


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
    background_tasks: BackgroundTasks,
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
    background_tasks.add_task(
        send_provider_status_email,
        provider_id,
        str(row["status"]),
        body.reason,
    )
    return {
        "id": str(row["id"]),
        "status": row["status"],
        "reason": body.reason,
    }


@router.post("/providers/{provider_id}/verification")
async def verify_provider(
    provider_id: UUID,
    body: AdminAction,
    background_tasks: BackgroundTasks,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    approved = body.action == "approve"
    async with get_db_connection() as db:
        async with db.transaction():
            exists = await db.fetchval("SELECT EXISTS(SELECT 1 FROM providers WHERE id=$1)", provider_id)
            if not exists:
                raise HTTPException(status_code=404, detail="Provider not found.")
            await db.execute(
                "UPDATE provider_documents SET status=$2 WHERE provider_id=$1",
                provider_id, "approved" if approved else "rejected",
            )
            await db.execute(
                "UPDATE providers SET is_verified=$2, updated_at=now() WHERE id=$1",
                provider_id, approved,
            )
            await db.execute(
                """INSERT INTO admin_notifications(provider_id,title,message)
                   VALUES($1,$2,$3)""",
                provider_id,
                "Verification approved" if approved else "Verification needs attention",
                "Your provider account is now verified." if approved
                else (
                    "We could not approve your verification yet. "
                    f"Reason: {body.reason or 'The submitted details or documents did not meet our requirements.'} "
                    "Correct the affected details or documents, then submit your provider profile for verification again."
                ),
            )
    background_tasks.add_task(
        send_provider_status_email,
        provider_id,
        "verified" if approved else "verification rejected",
        body.reason,
    )
    return {"ok": True}


@router.patch("/packages/{package_id}")
async def update_package(
    package_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    if body.action != "availability" or body.value not in {"true", "false"}:
        raise HTTPException(status_code=400, detail="Invalid package action.")
    async with get_db_connection() as db:
        row = await db.fetchrow(
            "UPDATE provider_packages SET is_available=$2 WHERE id=$1 RETURNING id,is_available",
            package_id, body.value == "true",
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Package not found.")
    return _json_row(row)


@router.post("/users/{user_id}/moderation")
async def moderate_user(
    user_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    if body.action not in {"ban", "unban"}:
        raise HTTPException(status_code=400, detail="Invalid user action.")
    state = "banned" if body.action == "ban" else "active"
    async with get_db_connection() as db:
        exists = await db.fetchval("SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)", user_id)
        if not exists:
            raise HTTPException(status_code=404, detail="User not found.")
        await db.execute(
            """INSERT INTO admin_user_moderation(user_id,status,reason)
               VALUES($1,$2,$3) ON CONFLICT(user_id) DO UPDATE
               SET status=excluded.status,reason=excluded.reason,updated_at=now()""",
            user_id, state, body.reason,
        )
    return {"id": str(user_id), "status": state}


@router.post("/users/{user_id}/role")
async def promote_user_to_admin(
    user_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    acting_admin = await _require_admin(authorization)
    if body.action != "promote_admin":
        raise HTTPException(status_code=400, detail="Invalid role action.")
    async with get_db_connection() as db:
        target = await db.fetchrow(
            "SELECT id, email, role FROM users WHERE id=$1",
            user_id,
        )
        if target is None:
            raise HTTPException(status_code=404, detail="User not found.")
        if target["role"] == "admin":
            return {"id": str(user_id), "role": "admin"}
        row = await db.fetchrow(
            """
            UPDATE users
               SET role='admin', updated_at=now()
             WHERE id=$1
             RETURNING id, email, role
            """,
            user_id,
        )
    log.info(
        "Admin %s promoted %s (%s) to admin",
        acting_admin["email"],
        row["email"],
        row["id"],
    )
    return {"id": str(row["id"]), "email": row["email"], "role": row["role"]}


@router.post("/users/{user_id}/delete")
async def delete_user_account(
    user_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    acting_admin = await _require_admin(authorization)
    reason = (body.reason or "").strip()
    if body.action != "delete" or len(reason) < 5:
        raise HTTPException(
            status_code=400,
            detail="A deletion reason of at least 5 characters is required.",
        )
    if user_id == acting_admin["id"]:
        raise HTTPException(status_code=400, detail="You cannot delete your own account.")

    async with get_db_connection() as db:
        async with db.transaction():
            target = await db.fetchrow(
                "SELECT id, firebase_uid, email, role FROM users WHERE id=$1 FOR UPDATE",
                user_id,
            )
            if target is None:
                raise HTTPException(status_code=404, detail="User not found.")
            if target["role"] == "admin":
                raise HTTPException(
                    status_code=400,
                    detail="Administrator accounts cannot be deleted here.",
                )
            await db.execute(
                """
                INSERT INTO admin_deleted_users (
                    deleted_user_id, firebase_uid, email, reason,
                    deleted_by_id, deleted_by_email
                ) VALUES ($1,$2,$3,$4,$5,$6)
                ON CONFLICT (firebase_uid) DO UPDATE
                   SET reason=excluded.reason,
                       deleted_by_id=excluded.deleted_by_id,
                       deleted_by_email=excluded.deleted_by_email,
                       deleted_at=now()
                """,
                target["id"],
                target["firebase_uid"],
                target["email"],
                reason,
                acting_admin["id"],
                acting_admin["email"],
            )
            # Preserve staff accounts created by this user by transferring the
            # immutable creator reference to the acting administrator.
            await db.execute(
                "UPDATE provider_staff_accounts SET created_by=$1 WHERE created_by=$2",
                acting_admin["id"],
                target["id"],
            )
            await db.execute("DELETE FROM users WHERE id=$1", target["id"])

    firebase_deleted = await delete_firebase_user(str(target["firebase_uid"]))
    log.warning(
        "Admin %s deleted user %s (%s); Firebase deleted=%s; reason=%s",
        acting_admin["email"],
        target["email"],
        target["id"],
        firebase_deleted,
        reason,
    )
    return {"id": str(user_id), "deleted": True, "firebase_deleted": firebase_deleted}


@router.post("/reports/{report_id}/action")
async def act_on_report(
    report_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    allowed = {"warn", "suspend", "ban", "dismiss", "investigate"}
    if body.action not in allowed:
        raise HTTPException(status_code=400, detail="Invalid report action.")
    async with get_db_connection() as db:
        async with db.transaction():
            report = await db.fetchrow(
                "SELECT reported_provider_id FROM admin_reports WHERE id=$1", report_id
            )
            if report is None:
                raise HTTPException(status_code=404, detail="Report not found.")
            final_status = "resolved" if body.action in {"dismiss", "ban"} else "investigating"
            await db.execute(
                "UPDATE admin_reports SET status=$2,updated_at=now() WHERE id=$1",
                report_id, final_status,
            )
            provider_id = report["reported_provider_id"]
            if provider_id and body.action in {"suspend", "ban"}:
                await db.execute(
                    "UPDATE providers SET status=$2,updated_at=now() WHERE id=$1",
                    provider_id, "suspended" if body.action == "suspend" else "banned",
                )
            if provider_id and body.action == "warn":
                await db.execute(
                    """INSERT INTO admin_notifications(provider_id,title,message)
                       VALUES($1,'Account warning',$2)""",
                    provider_id, body.reason or "A report about your account requires attention.",
                )
    return {"id": str(report_id), "status": final_status}


@router.post("/subscriptions/{provider_id}/action")
async def change_subscription(
    provider_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    tier = body.value if body.action in {"upgrade", "downgrade"} else "free"
    if tier not in {"free", "growth", "pro"}:
        raise HTTPException(status_code=400, detail="Invalid plan.")
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """UPDATE providers SET subscription_tier=$2,
               subscription_expires_at=CASE WHEN $2='free' THEN NULL
               ELSE now()+interval '30 days' END,updated_at=now()
               WHERE id=$1 RETURNING id,subscription_tier""",
            provider_id, tier,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Provider not found.")
    return _json_row(row)


@router.post("/invoices/{invoice_id}/action")
async def act_on_invoice(
    invoice_id: UUID,
    body: AdminAction,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    await _require_admin(authorization)
    if body.action not in {"paid", "remind"}:
        raise HTTPException(status_code=400, detail="Invalid invoice action.")
    async with get_db_connection() as db:
        invoice = await db.fetchrow(
            "SELECT provider_id,invoice_number FROM admin_invoices WHERE id=$1", invoice_id
        )
        if invoice is None:
            raise HTTPException(status_code=404, detail="Invoice not found.")
        if body.action == "paid":
            await db.execute("UPDATE admin_invoices SET status='paid' WHERE id=$1", invoice_id)
        else:
            await db.execute(
                """INSERT INTO admin_notifications(provider_id,title,message)
                   VALUES($1,'Invoice reminder',$2)""",
                invoice["provider_id"], f"Invoice {invoice['invoice_number']} is awaiting payment.",
            )
    return {"ok": True}
