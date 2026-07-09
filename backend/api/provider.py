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
        coverage_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }
        ratings_by_provider: dict[UUID, dict[str, Any]] = {
            provider_id: {"rating": 0.0, "reviews": 0} for provider_id in provider_ids
        }
        recent_reviews_by_provider: dict[UUID, list[dict[str, Any]]] = {
            provider_id: [] for provider_id in provider_ids
        }
        popularity_by_package = {}

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
                SELECT
                    provider_id,
                    area_name,
                    latitude,
                    longitude,
                    radius_km
                FROM provider_coverage_areas
                WHERE provider_id = ANY($1::uuid[])
                ORDER BY created_at ASC;
                """,
                provider_ids,
            )
            for row in coverage_rows:
                coverage_by_provider[row["provider_id"]].append(
                    {
                        "name": row["area_name"],
                        "area_name": row["area_name"],
                        "latitude": float(row["latitude"]),
                        "longitude": float(row["longitude"]),
                        "radius_km": float(row["radius_km"]),
                    }
                )

            rating_rows = await db.fetch(
                """
                SELECT
                    provider_id,
                    round(avg(rating)::numeric, 1) AS rating,
                    count(*) AS reviews
                FROM provider_reviews
                WHERE provider_id = ANY($1::uuid[])
                GROUP BY provider_id
                """,
                provider_ids,
            )
            for row in rating_rows:
                ratings_by_provider[row["provider_id"]] = {
                    "rating": float(row["rating"] or 0),
                    "reviews": int(row["reviews"] or 0),
                }

            review_rows = await db.fetch(
                """
                SELECT *
                FROM (
                    SELECT
                        pr.provider_id,
                        pr.rating,
                        pr.comment,
                        pr.updated_at,
                        pp.package_name,
                        u.first_name,
                        u.last_name,
                        row_number() OVER (
                            PARTITION BY pr.provider_id
                            ORDER BY pr.updated_at DESC
                        ) AS row_number
                    FROM provider_reviews pr
                    LEFT JOIN provider_packages pp ON pp.id = pr.package_id
                    LEFT JOIN users u ON u.id = pr.user_id
                    WHERE pr.provider_id = ANY($1::uuid[])
                ) ranked_reviews
                WHERE row_number <= 5
                ORDER BY provider_id, updated_at DESC
                """,
                provider_ids,
            )
            for row in review_rows:
                first_name = (row["first_name"] or "").strip()
                last_name = (row["last_name"] or "").strip()
                customer_name = " ".join(
                    part for part in [first_name, last_name] if part
                )
                recent_reviews_by_provider[row["provider_id"]].append(
                    {
                        "customer_name": customer_name or "Customer",
                        "package_name": row["package_name"] or "Package",
                        "rating": int(row["rating"] or 0),
                        "stars": int(row["rating"] or 0),
                        "comment": row["comment"] or "",
                        "updated_at": row["updated_at"].isoformat(),
                    }
                )

            popularity_by_package = await _load_package_popularity(
                db,
                provider_ids=provider_ids,
            )

    public_providers = []
    for provider in providers:
        provider_id = provider["id"]
        packages = packages_by_provider[provider_id]
        coverage_areas = coverage_by_provider[provider_id]
        coverage_names = [area["name"] for area in coverage_areas]
        rating_summary = ratings_by_provider[provider_id]
        for package in packages:
            package["coverageAreas"] = coverage_names
            package.update(
                _public_package_popularity(
                    popularity_by_package.get(UUID(package["id"]), []),
                )
            )

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
                "rating": rating_summary["rating"],
                "reviews": str(rating_summary["reviews"]),
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
                "coverageAreas": coverage_names,
                "coverageAreaDetails": coverage_areas,
                "packages": packages,
                "recent_reviews": recent_reviews_by_provider[provider_id],
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

        popularity_by_package = await _load_package_popularity(
            db,
            provider_ids=[provider_id],
        )

        packages = []
        for row in rows:
            package = dict(row)
            package.update(
                _api_package_popularity(
                    popularity_by_package.get(package["id"], []),
                )
            )
            packages.append(package)

        return packages


async def _load_package_popularity(
    db: Any,
    *,
    provider_ids: list[UUID],
) -> dict[UUID, list[dict[str, Any]]]:
    rows = await db.fetch(
        """
        SELECT
            package_id,
            estate_or_building,
            count(*) AS installs
        FROM installation_requests
        WHERE provider_id = ANY($1::uuid[])
          AND status IN ('complete', 'completed')
        GROUP BY package_id, estate_or_building
        ORDER BY package_id, installs DESC, estate_or_building ASC
        """,
        provider_ids,
    )
    popularity: dict[UUID, list[dict[str, Any]]] = {}
    for row in rows:
        area = (row["estate_or_building"] or "").strip() or "Unknown area"
        popularity.setdefault(row["package_id"], []).append(
            {
                "area": area,
                "installs": int(row["installs"] or 0),
            }
        )
    return popularity


def _popularity_level(installs: int, top_installs: int) -> str:
    if installs <= 0:
        return "low"
    if top_installs <= 1:
        return "popular"
    ratio = installs / top_installs
    if installs >= 3 or ratio >= 0.66:
        return "popular"
    if installs >= 1 or ratio >= 0.33:
        return "mid"
    return "low"


def _api_package_popularity(areas: list[dict[str, Any]]) -> dict[str, Any]:
    top = areas[0] if areas else None
    top_installs = int(top["installs"]) if top else 0
    level = _popularity_level(top_installs, top_installs)
    return {
        "top_area": top["area"] if top else None,
        "popularity_level": level,
        "popularity_by_area": [
            {
                "area": area["area"],
                "installs": area["installs"],
                "level": _popularity_level(int(area["installs"]), top_installs),
            }
            for area in areas[:8]
        ],
        "trust_label": "Popular in your area" if level == "popular" else "Live installs",
        "subscriber_count": f"{top_installs} completed installs"
        if top_installs
        else "No installs yet",
        "popular": level == "popular",
    }


def _public_package_popularity(areas: list[dict[str, Any]]) -> dict[str, Any]:
    api_payload = _api_package_popularity(areas)
    return {
        "topArea": api_payload["top_area"],
        "top_area": api_payload["top_area"],
        "popularityLevel": api_payload["popularity_level"],
        "popularity_level": api_payload["popularity_level"],
        "popularityByArea": api_payload["popularity_by_area"],
        "popularity_by_area": api_payload["popularity_by_area"],
        "trustLabel": api_payload["trust_label"],
        "subscriberCount": api_payload["subscriber_count"],
        "popular": api_payload["popular"],
    }


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

        pending_installations = await db.fetchval(
            """
            SELECT count(*)
            FROM installation_requests
            WHERE provider_id = $1
              AND status = 'pending'
            """,
            provider_id,
        )

        active_customers = await db.fetchval(
            """
            SELECT count(DISTINCT user_id)
            FROM installation_requests
            WHERE provider_id = $1
              AND status IN ('complete', 'completed')
            """,
            provider_id,
        )

        monthly_revenue = await db.fetchval(
            """
            SELECT COALESCE(sum(pp.monthly_price), 0)
            FROM installation_requests ir
            JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE ir.provider_id = $1
              AND ir.status IN ('complete', 'completed')
            """,
            provider_id,
        )

        packages = await db.fetch(
            """
            SELECT
                pp.package_name,
                pp.speed_mbps,
                pp.monthly_price,
                count(ir.id) FILTER (
                    WHERE ir.status IN ('complete', 'completed')
                ) AS users,
                COALESCE(sum(pp.monthly_price) FILTER (
                    WHERE ir.status IN ('complete', 'completed')
                ), 0) AS revenue
            FROM provider_packages pp
            LEFT JOIN installation_requests ir ON ir.package_id = pp.id
            WHERE pp.provider_id = $1
            GROUP BY pp.id
            ORDER BY revenue DESC, pp.monthly_price ASC
            """,
            provider_id,
        )

        top_locations = await db.fetch(
            """
            SELECT
                COALESCE(NULLIF(trim(ir.estate_or_building), ''), 'Unknown area')
                    AS area,
                count(DISTINCT ir.user_id) AS users,
                COALESCE(sum(pp.monthly_price), 0) AS revenue
            FROM installation_requests ir
            JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE ir.provider_id = $1
              AND ir.status IN ('complete', 'completed')
            GROUP BY area
            ORDER BY users DESC, revenue DESC, area ASC
            LIMIT 8
            """,
            provider_id,
        )

        top_location_users = max(
            (int(row["users"] or 0) for row in top_locations),
            default=0,
        )

        recent_requests = await db.fetch(
            """
            SELECT
                ir.id,
                ir.status,
                ir.estate_or_building,
                ir.created_at,
                ir.completed_at,
                pp.package_name,
                pp.monthly_price
            FROM installation_requests ir
            LEFT JOIN provider_packages pp ON pp.id = ir.package_id
            WHERE ir.provider_id = $1
            ORDER BY ir.updated_at DESC
            LIMIT 6
            """,
            provider_id,
        )
        rating_summary = await db.fetchrow(
            """
            SELECT
                round(avg(rating)::numeric, 1) AS rating,
                count(*) AS reviews
            FROM provider_reviews
            WHERE provider_id = $1
            """,
            provider_id,
        )
        recent_reviews = await db.fetch(
            """
            SELECT
                pr.rating,
                pr.comment,
                pr.updated_at,
                pp.package_name,
                u.first_name,
                u.last_name
            FROM provider_reviews pr
            LEFT JOIN provider_packages pp ON pp.id = pr.package_id
            LEFT JOIN users u ON u.id = pr.user_id
            WHERE pr.provider_id = $1
            ORDER BY pr.updated_at DESC
            LIMIT 5
            """,
            provider_id,
        )
        return {
            "provider_name": provider["provider_name"],
            "status": provider["status"],
            "is_verified": provider["is_verified"],
            "joined_at": provider["created_at"].isoformat(),
            "active_customers": int(active_customers or 0),
            "pending_installations": int(pending_installations or 0),
            "monthly_revenue": float(monthly_revenue or 0),
            "commission_due": 0,
            "packages_count": packages_count,
            "coverage_count": coverage_count,
            "coverage_areas": [
                {
                    "name": row["area"],
                    "area": row["area"],
                    "users": int(row["users"] or 0),
                    "customer_count": int(row["users"] or 0),
                    "revenue": float(row["revenue"] or 0),
                    "monthly_revenue": float(row["revenue"] or 0),
                    "progress": (
                        (int(row["users"] or 0) / top_location_users) * 100
                        if top_location_users
                        else 0
                    ),
                }
                for row in top_locations
            ]
            or [row["area_name"] for row in coverage_areas],
            "pending_documents": pending_docs,
            "packages": [
                {
                    "package_name": row["package_name"],
                    "speed_mbps": row["speed_mbps"],
                    "monthly_price": float(row["monthly_price"] or 0),
                    "users": int(row["users"] or 0),
                    "active_users": int(row["users"] or 0),
                    "customer_count": int(row["users"] or 0),
                    "revenue": float(row["revenue"] or 0),
                    "monthly_revenue": float(row["revenue"] or 0),
                    "growth": 0,
                }
                for row in packages
            ],
            "top_packages": [
                {
                    "package_name": row["package_name"],
                    "users": int(row["users"] or 0),
                    "revenue": float(row["revenue"] or 0),
                }
                for row in packages[:5]
            ],
            "top_locations": [
                {
                    "area": row["area"],
                    "users": int(row["users"] or 0),
                    "revenue": float(row["revenue"] or 0),
                }
                for row in top_locations
            ],
            "rating": float(rating_summary["rating"] or 0)
            if rating_summary
            else 0.0,
            "reviews_count": int(rating_summary["reviews"] or 0)
            if rating_summary
            else 0,
            "recent_reviews": [
                {
                    "customer_name": _review_customer_name(row),
                    "package_name": row["package_name"] or "Package",
                    "rating": int(row["rating"] or 0),
                    "stars": int(row["rating"] or 0),
                    "comment": row["comment"] or "",
                    "updated_at": row["updated_at"].isoformat(),
                }
                for row in recent_reviews
            ],
            "recent_requests": [
                {
                    "id": str(row["id"]),
                    "status": row["status"],
                    "area": row["estate_or_building"],
                    "package_name": row["package_name"],
                    "monthly_price": float(row["monthly_price"] or 0),
                    "created_at": row["created_at"].isoformat(),
                    "completed_at": row["completed_at"].isoformat()
                    if row["completed_at"]
                    else None,
                }
                for row in recent_requests
            ],
        }


def _review_customer_name(row: Any) -> str:
    first_name = (row["first_name"] or "").strip()
    last_name = (row["last_name"] or "").strip()
    return " ".join(part for part in [first_name, last_name] if part) or "Customer"
