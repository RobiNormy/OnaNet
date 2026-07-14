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

from backend.services.subscription_services import(
    get_provider_tier,
    within_count_limits,
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
                p.id,
                p.provider_name,
                p.provider_type,
                p.primary_city,
                p.is_verified,
                p.logo_url,
                p.logo_display_size,
                p.logo_offset_x,
                p.logo_offset_y,
                coalesce(round(avg(pr.rating)::numeric, 1), 0)::float
                    AS weighted_rating,
                count(pr.id)::int AS review_count
            FROM providers p
            LEFT JOIN provider_reviews pr ON pr.provider_id = p.id
            WHERE p.status != 'suspended'
            GROUP BY
                p.id,
                p.provider_name,
                p.provider_type,
                p.primary_city,
                p.is_verified,
                p.logo_url,
                p.logo_display_size,
                p.logo_offset_x,
                p.logo_offset_y,
                p.created_at
            ORDER BY p.created_at DESC;
            """
        )
        provider_ids = [row["id"] for row in providers]

        packages_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }
        coverage_by_provider: dict[UUID, list[str]] = {
            provider_id: [] for provider_id in provider_ids
        }
        coverage_details_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }
        reviews_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }

        if provider_ids:
            package_rows = await db.fetch(
                """
                SELECT
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
                SELECT provider_id, area_name, latitude, longitude, radius_km
                FROM provider_coverage_areas
                WHERE provider_id = ANY($1::uuid[])
                ORDER BY created_at ASC;
                """,
                provider_ids,
            )
            for row in coverage_rows:
                coverage_by_provider[row["provider_id"]].append(row["area_name"])
                coverage_details_by_provider[row["provider_id"]].append(
                    {
                        "name": row["area_name"],
                        "area_name": row["area_name"],
                        "latitude": float(row["latitude"]),
                        "longitude": float(row["longitude"]),
                        "radius_km": float(row["radius_km"]),
                    }
                )

            review_rows = await db.fetch(
                """
                SELECT *
                FROM (
                    SELECT
                        pr.id,
                        pr.provider_id,
                        pr.package_id,
                        pr.rating,
                        pr.comment,
                        pr.updated_at,
                        pp.package_name,
                        customer.first_name,
                        customer.last_name,
                        row_number() OVER (
                            PARTITION BY pr.provider_id
                            ORDER BY pr.updated_at DESC
                        ) AS review_rank
                    FROM provider_reviews pr
                    JOIN users customer ON customer.id = pr.user_id
                    LEFT JOIN provider_packages pp ON pp.id = pr.package_id
                    WHERE pr.provider_id = ANY($1::uuid[])
                ) ranked
                WHERE review_rank <= 20
                ORDER BY provider_id, updated_at DESC
                """,
                provider_ids,
            )
            for row in review_rows:
                first_name = str(row["first_name"] or "").strip()
                last_name = str(row["last_name"] or "").strip()
                display_name = first_name
                if last_name:
                    display_name = f"{display_name} {last_name[0]}.".strip()
                reviews_by_provider[row["provider_id"]].append(
                    {
                        "id": str(row["id"]),
                        "package_id": str(row["package_id"]),
                        "customer_name": display_name or "OnaNet customer",
                        "package_name": row["package_name"] or "Package",
                        "rating": int(row["rating"]),
                        "comment": row["comment"] or "",
                        "updated_at": row["updated_at"].isoformat(),
                    }
                )

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
                "rating": float(provider["weighted_rating"] or 0),
                "reviews": str(provider["review_count"] or 0),
                "price": _format_money(starting_price),
                "speed": max_speed,
                "distance": 0.0,
                "verified": provider["is_verified"],
                "providerType": provider["provider_type"],
                "primaryCity": provider["primary_city"],
                "logoUrl": provider["logo_url"],
                "logoScale": float(provider["logo_display_size"] or 1),
                "logoOffsetX": float(provider["logo_offset_x"] or 0),
                "logoOffsetY": float(provider["logo_offset_y"] or 0),
                "coverageAreas": coverage_areas,
                "coverageAreaDetails": coverage_details_by_provider[provider_id],
                "customerReviews": reviews_by_provider[provider_id],
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
            tier, limits = await get_provider_tier(provider_id)
            existing_count = await db.fetchwal(
                "SELECT COUNT(*) FROM provider_packages WHERE provider_id = $1",
                provider_id,
            )

            if not within_count_limits(limits,"max_packages",existing_count):
                tier_label = tier.capitalize()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=(
                        f"Your {tier_label} plan allows up to "
                        f"{limits['max_packages']} packages. "
                        f"Upgradr to Growth for 10 or Pro for unlimited"
                    ),
                )

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


@router.get("/me/customers")
async def get_my_provider_customers(
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    """Customers are users with at least one completed installation."""
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as db:
        rows = await db.fetch(
            """
            SELECT
                customer.id,
                customer.first_name,
                customer.last_name,
                customer.email,
                coalesce(
                    customer.phone_number,
                    (array_agg(ir.phone_e164 ORDER BY ir.completed_at DESC))[1]
                ) AS phone_number,
                customer.is_phone_verified,
                count(ir.id)::int AS request_count,
                array_agg(DISTINCT pp.package_name)
                    FILTER (WHERE pp.package_name IS NOT NULL) AS packages,
                min(ir.completed_at) AS customer_since,
                max(ir.completed_at) AS last_installation_at,
                (array_agg(
                    ir.estate_or_building ORDER BY ir.completed_at DESC
                ))[1] AS latest_estate_or_building,
                (array_agg(
                    ir.house_or_apartment ORDER BY ir.completed_at DESC
                ))[1] AS latest_house_or_apartment,
                (array_agg(
                    ir.landmark ORDER BY ir.completed_at DESC
                ))[1] AS latest_landmark,
                (array_agg(
                    ir.gps_location ORDER BY ir.completed_at DESC
                ))[1] AS latest_gps_location
            FROM providers provider
            JOIN users owner ON owner.id = provider.user_id
            JOIN installation_requests ir ON ir.provider_id = provider.id
            JOIN users customer ON customer.id = ir.user_id
            LEFT JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE owner.firebase_uid = $1
              AND ir.status IN ('complete', 'completed')
            GROUP BY
                customer.id,
                customer.first_name,
                customer.last_name,
                customer.email,
                customer.phone_number,
                customer.is_phone_verified
            ORDER BY max(ir.completed_at) DESC
            """,
            firebase_user["uid"],
        )
    return [dict(row) for row in rows]


@router.get("/me/reviews")
async def get_my_provider_reviews(
    authorization: str | None = Header(default=None),
) -> list[dict[str, Any]]:
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as db:
        rows = await db.fetch(
            """
            SELECT
                pr.id,
                pr.installation_request_id,
                pr.rating,
                pr.comment,
                pr.created_at,
                pr.updated_at,
                customer.first_name,
                customer.last_name,
                pp.package_name
            FROM provider_reviews pr
            JOIN providers provider ON provider.id = pr.provider_id
            JOIN users owner ON owner.id = provider.user_id
            JOIN users customer ON customer.id = pr.user_id
            LEFT JOIN provider_packages pp ON pp.id = pr.package_id
            WHERE owner.firebase_uid = $1
            ORDER BY pr.updated_at DESC
            """,
            firebase_user["uid"],
        )
    return [dict(row) for row in rows]


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
async def get_dashboard(provider_id: UUID):
    async with get_db_connection() as db:
        provider = await db.fetchrow(
            """
            SELECT provider_name,status,is_verified,created_at
            FROM providers
            WHERE id = $1
            """,
            provider_id,
        )
        packages_count = await db.fetchval(
            """
            SELECT count(*)
            FROM provider_packages
            WHERE provider_id = $1

            """,
            provider_id,
        )

        live_stats = await db.fetchrow(
            """
            SELECT
              count(DISTINCT user_id) FILTER (
                WHERE status IN ('complete', 'completed')
              )::int AS active_customers,
              count(*) FILTER (
                WHERE status IN ('pending', 'accepted', 'scheduled', 'installed')
              )::int AS pending_installations,
              coalesce(sum(pp.monthly_price) FILTER (
                WHERE ir.status IN ('complete', 'completed')
                  AND ir.completed_at >= date_trunc('month', now())
              ), 0)::float AS monthly_revenue,
              coalesce(sum(ir.commission_amount) FILTER (
                WHERE ir.status IN ('complete', 'completed')
                  AND ir.completed_at >= date_trunc('month', now())
              ), 0)::float AS commission_due
            FROM installation_requests ir
            LEFT JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE ir.provider_id = $1
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
            SELECT p.id, p.package_name, p.speed_mbps, p.monthly_price,
              count(DISTINCT ir.user_id) FILTER (
                WHERE ir.status IN ('complete', 'completed')
              )::int AS customer_count,
              coalesce(sum(p.monthly_price) FILTER (
                WHERE ir.status IN ('complete', 'completed')
              ), 0)::float AS revenue,
              count(ir.id) FILTER (
                WHERE ir.status IN ('complete', 'completed')
                  AND ir.completed_at >= date_trunc('month', now())
              )::int AS current_installs,
              count(ir.id) FILTER (
                WHERE ir.status IN ('complete', 'completed')
                  AND ir.completed_at >= date_trunc('month', now()) - interval '1 month'
                  AND ir.completed_at < date_trunc('month', now())
              )::int AS previous_installs
            FROM provider_packages p
            LEFT JOIN installation_requests ir ON ir.package_id = p.id
            WHERE p.provider_id = $1
            GROUP BY p.id, p.package_name, p.speed_mbps, p.monthly_price
            ORDER BY p.monthly_price ASC

            """,
            provider_id,
        )
        coverage_areas = await db.fetch(
            """
            SELECT c.area_name, c.latitude, c.longitude, c.radius_km,
              count(DISTINCT ir.user_id) FILTER (
                WHERE ir.status IN ('complete', 'completed')
              )::int AS customer_count,
              coalesce(sum(pp.monthly_price) FILTER (
                WHERE ir.status IN ('complete', 'completed')
              ), 0)::float AS revenue
            FROM provider_coverage_areas c
            LEFT JOIN installation_requests ir
              ON ir.provider_id = c.provider_id
              AND lower(coalesce(ir.installation_area, ir.estate_or_building)) =
                  lower(c.area_name)
            LEFT JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE c.provider_id = $1
            GROUP BY c.id, c.area_name, c.latitude, c.longitude, c.radius_km
            ORDER BY customer_count DESC, c.area_name
            """,
            provider_id,
        )
        revenue_history = await db.fetch(
            """
            WITH months AS (
              SELECT generate_series(
                date_trunc('month', now()) - interval '5 months',
                date_trunc('month', now()),
                interval '1 month'
              ) AS month_start
            ), totals AS (
              SELECT date_trunc('month', ir.completed_at) AS month_start,
                sum(pp.monthly_price)::float AS amount
              FROM installation_requests ir
              JOIN provider_packages pp ON pp.id = ir.package_id
              WHERE ir.provider_id = $1
                AND ir.status IN ('complete', 'completed')
                AND ir.completed_at >= date_trunc('month', now()) - interval '5 months'
              GROUP BY date_trunc('month', ir.completed_at)
            )
            SELECT to_char(m.month_start, 'Mon') AS month,
              coalesce(t.amount, 0)::float AS amount
            FROM months m
            LEFT JOIN totals t ON t.month_start = m.month_start
            ORDER BY m.month_start
            """,
            provider_id,
        )
        recent_reviews = await db.fetch(
            """
            SELECT
              concat_ws(
                ' ',
                nullif(trim(customer.first_name), ''),
                nullif(trim(customer.last_name), '')
              ) AS customer_name,
              pp.package_name,
              pr.rating,
              pr.rating AS stars,
              pr.comment,
              pr.updated_at
            FROM provider_reviews pr
            JOIN users customer ON customer.id = pr.user_id
            LEFT JOIN provider_packages pp ON pp.id = pr.package_id
            WHERE pr.provider_id = $1
            ORDER BY pr.updated_at DESC
            LIMIT 5
            """,
            provider_id,
        )

        package_rows = []
        for row in packages:
            item = dict(row)
            current = item.pop("current_installs", 0) or 0
            previous = item.pop("previous_installs", 0) or 0
            item["growth_percent"] = (
                ((current - previous) / previous) * 100
                if previous
                else 100 if current else 0
            )
            package_rows.append(item)

        stats = dict(live_stats or {})
        return {
            "provider_name": provider["provider_name"],
            "status": provider["status"],
            "is_verified": provider["is_verified"],
            "joined_at": provider["created_at"].isoformat(),
            "active_customers": stats.get("active_customers", 0),
            "pending_installations": stats.get("pending_installations", 0),
            "monthly_revenue": stats.get("monthly_revenue", 0),
            "commission_due": stats.get("commission_due", 0),
            "packages_count": packages_count,
            "coverage_count": coverage_count,
            "pending_documents": pending_docs,
            "packages": package_rows,
            "coverage_areas": [dict(row) for row in coverage_areas],
            "revenue_history": [dict(row) for row in revenue_history],
            "recent_reviews": [dict(row) for row in recent_reviews],
        }
