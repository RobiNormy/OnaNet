from fastapi import APIRouter, HTTPException, Query, status

from backend.services.geoapify_service import (
    GeoapifyConfigurationError,
    GeoapifyRequestError,
    geoapify_service,
)

router = APIRouter(prefix="/locations", tags=["locations"])


@router.get("/autocomplete")
async def autocomplete_locations(
    text: str = Query(min_length=3, max_length=120),
    limit: int = Query(default=6, ge=1, le=10),
) -> dict[str, object]:
    try:
        locations = await geoapify_service.autocomplete(text, limit)
    except GeoapifyConfigurationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(error)
        ) from error
    except GeoapifyRequestError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error)
        ) from error
    return {"results": [location.to_dict() for location in locations]}


@router.get("/reverse")
async def reverse_location(
    latitude: float = Query(ge=-90, le=90),
    longitude: float = Query(ge=-180, le=180),
) -> dict[str, object | None]:
    try:
        location = await geoapify_service.reverse(latitude, longitude)
    except GeoapifyConfigurationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(error)
        ) from error
    except GeoapifyRequestError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error)
        ) from error
    return {"result": location.to_dict() if location else None}
