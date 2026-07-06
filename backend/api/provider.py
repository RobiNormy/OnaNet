from typing import Any
from uuid import UUID
import uuid
from pathlib import Path

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile, status
from supabase import create_client

from backend.api.auth import _get_current_firebase_user
from backend.core.config import settings
from backend.db.session import get_db_connection
from backend.providers.repos.provider_contact import (
    get_provider_contacts,
    replace_provider_contacts,
)
from backend.providers.repos.provider_coverage_repo import (
    get_provider_coverage_areas,
    replace_provider_coverage_areas,
)
from backend.providers.repos.provider_repo import (
    create_provider_registration,
    get_provider_by_firebase_uid,
)
from backend.providers.repos.provider_service_repo import (
    get_provider_services,
    replace_provider_services,
)
from backend.providers.schema.provider_service_schema import (
    ProviderServiceOut,
    ProviderServicesCreate,
)
from backend.providers.schema.provider_coverage_schema import (
    ProviderCoverageAreaOut,
    ProviderCoverageAreasCreate,
)
from backend.providers.schema.provider_contact import (
    ProviderContactOut,
    ProviderContactsCreate,
)
from backend.providers.schema.provider_package import (
    ProviderPackageCreate,
    ProviderPackageOut,
)
from backend.providers.schema.schema import (
    ProviderRegistrationRequest,
    ProviderRegistrationResponse,
)

router = APIRouter(prefix="/providers", tags=["providers"])

SUPABASE_BUCKET = "provider-documents"
ASSET_BUCKET = "provider-assets"
ALLOWED_LOGO_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp"
}
MAX_FILE_SIZE = 5 * 1024 * 1024
ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "application/pdf",
}
ALLOWED_DOCUMENT_TYPES = {
    "national_id",
    "national_id_front",
    "national_id_back",
    "selfie",
    "kra_pin",
    "business_registration",
    "cak_license",
    "business_permit",
    "premises_photo",
}

supabase = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_ROLE_KEY,
)


@router.get("/ping")
async def providers_ping() -> dict[str, str]:
    return {"status": "providers router working"}


@router.get("")
async def list_public_providers() -> list[dict[str, Any]]:
    async with get_db_connection() as db:
        providers = await db.fetch(
            """
            SELECT
                id,
                provider_name,
                provider_type,
                primary_city,
                upstream_provider,
                is_verified,
                logo_url,
                logo_display_size,
                logo_offset_x,
                logo_offset_y
            FROM providers
            WHERE status != 'suspended'
            ORDER BY created_at DESC;
            """
        )
        provider_ids = [row["id"] for row in providers]

        packages_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }
        coverage_by_provider: dict[UUID, list[str]] = {
            provider_id: [] for provider_id in provider_ids
        }

        if provider_ids:
            package_rows = await db.fetch(
                """
                SELECT
                    id,
                    provider_id,
                    package_name,
                    speed_mbps,
                    monthly_price,
                    installation_fee,
                    fair_usage_policy,
                    contract_type,
                    installation_period,
                    router_included
                FROM provider_packages
                WHERE provider_id = ANY($1::uuid[])
                ORDER BY monthly_price ASC;
                """,
                provider_ids,
            )
            for row in package_rows:
                packages_by_provider[row["provider_id"]].append(
                    {
                        "id": str(row["id"]),
                        "package_id": str(row["id"]),
                        "name": row["package_name"],
                        "speed": f"{row['speed_mbps']}Mbps",
                        "contract": _format_contract_type(row["contract_type"]),
                        "price": _format_money(row["monthly_price"]),
                        "installationFee": _format_money(row["installation_fee"]),
                        "fairUsage": row["fair_usage_policy"] or "Not specified",
                        "routerIncluded": row["router_included"],
                        "installationTime": row["installation_period"]
                        or "Not specified",
                        "coverageAreas": [],
                        "trustLabel": "Provider package",
                        "subscriberCount": "No review data yet",
                        "popular": False,
                    }
                )

            coverage_rows = await db.fetch(
                """
                SELECT provider_id, area_name
                FROM provider_coverage_areas
                WHERE provider_id = ANY($1::uuid[])
                ORDER BY created_at ASC;
                """,
                provider_ids,
            )
            for row in coverage_rows:
                coverage_by_provider[row["provider_id"]].append(row["area_name"])

    public_providers = []
    for provider in providers:
        provider_id = provider["id"]
        packages = packages_by_provider[provider_id]
        coverage_areas = coverage_by_provider[provider_id]
        for package in packages:
            package["coverageAreas"] = coverage_areas

        starting_price = min(
            (_money_to_float(package["price"]) for package in packages),
            default=0,
        )
        max_speed = max(
            (_speed_to_mbps(package["speed"]) for package in packages),
            default=0,
        )

        public_providers.append(
            {
                "id": str(provider_id),
                "name": provider["provider_name"],
                "initials": _provider_initials(provider["provider_name"]),
                "color": _provider_color(str(provider_id)),
                "rating": 0.0,
                "reviews": "0",
                "price": _format_money(starting_price),
                "speed": max_speed,
                "distance": 0.0,
                "verified": provider["is_verified"],
                "providerType": provider["provider_type"],
                "primaryCity": provider["primary_city"],
                "mainIspProvider": provider["upstream_provider"],
                "logoUrl": provider["logo_url"],
                "logoScale": float(provider["logo_display_size"] or 1),
                "logoOffsetX": float(provider["logo_offset_x"] or 0),
                "logoOffsetY": float(provider["logo_offset_y"] or 0),
                "coverageAreas": coverage_areas,
                "packages": packages,
            }
        )

    return public_providers


@router.post("/register", response_model=ProviderRegistrationResponse)
async def register_provider(
    provider_in: ProviderRegistrationRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await create_provider_registration(
                db,
                firebase_user["uid"],
                provider_in,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(exc),
            ) from exc

@router.post("/{provider_id}/logo")
async def upload_provider_logo(
    provider_id: UUID,
    file: UploadFile = File(...),
    logo_display_size: float = Form(default=1.0),
    logo_offset_x: float = Form(default=0.0),
    logo_offset_y: float = Form(default=0.0),
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    if file.content_type not in ALLOWED_LOGO_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid logo file type",
        )

    contents = await file.read()

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Logo exceeds 5MB limit",
        )

    file_ext = Path(file.filename or "").suffix.lower()

    if file_ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid logo file extension",
        )

    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT providers.id
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE providers.id = $1
              AND users.firebase_uid = $2;
            """,
            provider_id,
            firebase_user["uid"],
        )

        if provider is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider profile not found for this user",
            )

        storage_path = f"providers/{provider_id}/logo{file_ext}"

        try:
            supabase.storage.from_(ASSET_BUCKET).upload(
                storage_path,
                contents,
                {
                    "content-type": file.content_type,
                    "upsert": "true",
                },
            )

            public_url = supabase.storage.from_(ASSET_BUCKET).get_public_url(
                storage_path
            )

        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Could not upload logo to storage: {str(exc)}",
            ) from exc

        row = await db.fetchrow(
            """
            UPDATE providers
            SET logo_url = $1,
                logo_storage_path = $2,
                logo_display_size = $3,
                logo_offset_x = $4,
                logo_offset_y = $5,
                updated_at = now()
            WHERE id = $6
            RETURNING
                id,
                provider_name,
                logo_url,
                logo_storage_path,
                logo_display_size,
                logo_offset_x,
                logo_offset_y;
            """,
            public_url,
            storage_path,
            logo_display_size,
            logo_offset_x,
            logo_offset_y,
            provider_id,
        )

    return {
        "message": "Logo uploaded successfully",
        "provider_id": str(row["id"]),
        "provider_name": row["provider_name"],
        "logo_url": row["logo_url"],
        "logoUrl": row["logo_url"],
        "logo_storage_path": row["logo_storage_path"],
        "logoScale": float(row["logo_display_size"] or 1),
        "logoOffsetX": float(row["logo_offset_x"] or 0),
        "logoOffsetY": float(row["logo_offset_y"] or 0),
    }


@router.delete("/{provider_id}/logo")
async def delete_provider_logo(
    provider_id: UUID,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT providers.id, providers.logo_storage_path
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE providers.id = $1
              AND users.firebase_uid = $2;
            """,
            provider_id,
            firebase_user["uid"],
        )

        if provider is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider profile not found for this user",
            )

        storage_path = provider["logo_storage_path"]
        if storage_path:
            try:
                supabase.storage.from_(ASSET_BUCKET).remove([storage_path])
            except Exception as exc:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Could not delete logo from storage: {str(exc)}",
                ) from exc

        row = await db.fetchrow(
            """
            UPDATE providers
            SET logo_url = NULL,
                logo_storage_path = NULL,
                logo_display_size = 1,
                logo_offset_x = 0,
                logo_offset_y = 0,
                updated_at = now()
            WHERE id = $1
            RETURNING id, provider_name;
            """,
            provider_id,
        )

    return {
        "message": "Logo deleted successfully",
        "provider_id": str(row["id"]),
        "provider_name": row["provider_name"],
        "logo_url": None,
        "logoUrl": None,
        "logoScale": 1.0,
        "logoOffsetX": 0.0,
        "logoOffsetY": 0.0,
    }


@router.post(
    "/{provider_id}/contacts",
    response_model=list[ProviderContactOut],
)
async def save_provider_contacts(
    provider_id: UUID,
    contacts_in: ProviderContactsCreate,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await replace_provider_contacts(
                db,
                provider_id,
                firebase_user["uid"],
                contacts_in.contacts,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.get(
    "/{provider_id}/contacts",
    response_model=list[ProviderContactOut],
)
async def list_provider_contacts(
    provider_id: UUID,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await get_provider_contacts(
                db,
                provider_id,
                firebase_user["uid"],
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.post(
    "/{provider_id}/coverage-areas",
    response_model=list[ProviderCoverageAreaOut],
)
async def save_provider_coverage_areas(
    provider_id: UUID,
    coverage_in: ProviderCoverageAreasCreate,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await replace_provider_coverage_areas(
                db,
                provider_id,
                firebase_user["uid"],
                coverage_in.coverage_areas,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.get(
    "/{provider_id}/coverage-areas",
    response_model=list[ProviderCoverageAreaOut],
)
async def list_provider_coverage_areas(
    provider_id: UUID,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await get_provider_coverage_areas(
                db,
                provider_id,
                firebase_user["uid"],
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.get("/me", response_model=ProviderRegistrationResponse)
async def get_my_provider(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await get_provider_by_firebase_uid(db, firebase_user["uid"])
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.post(
    "/{provider_id}/services",
    response_model=list[ProviderServiceOut],
)
async def save_provider_services(
    provider_id: UUID,
    services_in: ProviderServicesCreate,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await replace_provider_services(
                db,
                provider_id,
                firebase_user["uid"],
                services_in.service_types,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.get(
    "/{provider_id}/services",
    response_model=list[ProviderServiceOut],
)
async def list_provider_services(
    provider_id: UUID,
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        try:
            return await get_provider_services(
                db,
                provider_id,
                firebase_user["uid"],
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc


@router.post("/{provider_id}/documents")
async def upload_provider_document(
    provider_id: UUID,
    document_type: str = Form(...),
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    firebase_user = await _get_current_firebase_user(authorization)

    if document_type not in ALLOWED_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid document type",
        )

    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file type",
        )

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File exceeds 5MB limit",
        )

    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT providers.id
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE providers.id = $1
              AND users.firebase_uid = $2;
            """,
            provider_id,
            firebase_user["uid"],
        )
        if provider is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider profile not found for this user",
            )

        file_ext = Path(file.filename or "").suffix
        unique_filename = f"{document_type}_{provider_id}_{uuid.uuid4()}{file_ext}"
        storage_path = f"providers/{provider_id}/{unique_filename}"

        try:
            supabase.storage.from_(SUPABASE_BUCKET).upload(
                storage_path,
                contents,
                {"content-type": file.content_type},
            )
            public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(
                storage_path
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not upload document to storage",
            ) from exc

        row = await db.fetchrow(
            """
            INSERT INTO provider_documents (
                provider_id,
                document_type,
                file_url,
                status
            )
            VALUES ($1, $2, $3, 'pending')
            RETURNING id;
            """,
            provider_id,
            document_type,
            public_url,
        )

    return {
        "message": "Document uploaded successfully",
        "document_id": str(row["id"]),
        "file_url": public_url,
    }

@router.post("/{provider_id}/packages", response_model=ProviderPackageOut)
async def create_provider_package(
    provider_id: UUID,
    package_in: ProviderPackageCreate,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT providers.id
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE providers.id = $1
              AND users.firebase_uid = $2;
            """,
            provider_id,
            firebase_user["uid"],
        )
        if provider is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider profile not found for this user",
            )

        row = await db.fetchrow(
            """
            INSERT INTO provider_packages(
                provider_id,
                package_name,
                speed_mbps,
                monthly_price,
                installation_fee,
                fair_usage_policy,
                billing_cycle,
                contract_type,
                installation_period,
                router_included
            )
            VALUES(
                $1,$2,$3,$4,$5,
                $6,$7,$8,$9,$10
            )
            RETURNING *
            """,
            provider_id,
            package_in.package_name,
            package_in.speed_mbps,
            package_in.monthly_price,
            package_in.installation_fee,
            package_in.fair_usage_policy,
            package_in.billing_cycle,
            package_in.contract_type,
            package_in.installation_period,
            package_in.router_included,
        )

        return dict(row)


@router.get("/{provider_id}/packages", response_model=list[ProviderPackageOut])
async def get_provider_packages(
    provider_id: UUID,
) -> list[dict[str, Any]]:
    async with get_db_connection() as db:

        rows = await db.fetch(
            """
            SELECT *
            FROM provider_packages
            WHERE provider_id = $1
            ORDER BY monthly_price ASC
            """,
            provider_id,
        )

        return [dict(row) for row in rows]


def _provider_initials(name: str) -> str:
    words = [word for word in name.strip().split() if word]
    if not words:
        return "ON"
    if len(words) == 1:
        return words[0][:2].upper()
    return "".join(word[0] for word in words[:2]).upper()


def _provider_color(seed: str) -> int:
    colors = [
        0xFF1B4F8A,
        0xFF16A34A,
        0xFF7C3AED,
        0xFFDC2626,
        0xFF0F766E,
        0xFFB45309,
    ]
    return colors[sum(ord(char) for char in seed) % len(colors)]


def _format_money(value: Any) -> str:
    amount = float(value or 0)
    return f"{amount:,.0f}"


def _money_to_float(value: str) -> float:
    return float(value.replace(",", "") or 0)


def _speed_to_mbps(value: str) -> int:
    return int(value.lower().replace("mbps", "").strip() or 0)


def _format_contract_type(value: str | None) -> str:
    if not value:
        return "No contract"
    return value.replace("_", " ").title()


@router.get("/{provider_id}/dashboard")
async def get_dashboard(
    provider_id: UUID,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)

    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT
                providers.provider_name,
                providers.status,
                providers.is_verified,
                providers.created_at
            FROM providers
            JOIN users ON users.id = providers.user_id
            WHERE providers.id = $1
              AND users.firebase_uid = $2
            """,
            provider_id,
            firebase_user["uid"],
        )
        if provider is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider dashboard not found for this user",
            )

        packages_count = await db.fetchval(
            """
            SELECT count(*)
            FROM provider_packages
            WHERE provider_id = $1

            """,
            provider_id,
        )

        coverage_count = await db.fetchval(
            """
            SELECT count(*)
            FROM provider_coverage_areas
            WHERE provider_id = $1
        
            """,
            provider_id,
        )

        coverage_areas = await db.fetch(
            """
            SELECT area_name
            FROM provider_coverage_areas
            WHERE provider_id = $1
            ORDER BY created_at ASC
            """,
            provider_id,
        )

        pending_docs = await db.fetchval(
            """
            SELECT count(*)
            FROM provider_documents
            WHERE provider_id = $1
                AND status = 'pending'
            """,
            provider_id,
        )

        packages = await db.fetch(
            """
            SELECT package_name, speed_mbps, monthly_price
            FROM provider_packages
            WHERE provider_id = $1
            ORDER BY monthly_price ASC

            """,
            provider_id,
        )
        return {
            "provider_name": provider["provider_name"],
            "status": provider["status"],
            "is_verified": provider["is_verified"],
            "joined_at": provider["created_at"].isoformat(),
            "active_customers": 0,
            "pending_installations": 0,
            "monthly_revenue": 0,
            "commission_due": 0,
            "packages_count": packages_count,
            "coverage_count": coverage_count,
            "coverage_areas": [row["area_name"] for row in coverage_areas],
            "pending_documents": pending_docs,
            "packages": [
                {
                    "package_name": row["package_name"],
                    "speed_mbps": row["speed_mbps"],
                    "monthly_price": float(row["monthly_price"] or 0),
                }
                for row in packages
            ],
            "top_packages": [],
            "top_locations": [],
            "recent_requests": [],
        }
