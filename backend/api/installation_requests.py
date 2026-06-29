from __future__ import annotations

import logging
from typing import Any
from fastapi import APIRouter,Depends,Header,HTTPException,status
from uuid import UUID
from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection
from backend.providers.schema.installation_request import (
    InstallationRequestCreate,
    InstallationRequestOut,
)

from backend.services.installation_service import (
    InstallationRequestError,
    InstallationRequestService,
    IncompleteAddress,
    PhoneNotVerified,
    ProviderOrPackageMissing,
    UserNotFound,
    get_installation_request_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/installation-requests",tags=["installation-requests"])


async def _resolve_user_id(firebase_uid: str)-> str:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM users WHERE firebase_uid = $1",
            firebase_uid,
        )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )
    
    return str(row["id"])

@router.post("",response_model=InstallationRequestOut,status_code=status.HTTP_201_CREATED)
async def create_installation_request(
    body: InstallationRequestCreate,
    authorization: str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),
)-> Any:
    
    firebase_user = await _get_current_firebase_user(authorization)
    user_id = await _resolve_user_id(firebase_user["uid"])

    try:
        result = await service.create(
            user_id=UUID(user_id),
            provider_id=body.provider_id,
            package_id=body.package_id,
            phone_e164=body.phone_e164,
            gps_location=body.gps_location,
            estate_or_building=body.estate_or_building,
            house_or_apartment=body.house_or_apartment,
            landmark=body.landmark,
            preferred_date=body.preferred_date,
            preferred_time=body.preferred_time,
        )
    except PhoneNotVerified as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    
    except IncompleteAddress as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    
    except ProviderOrPackageMissing as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    
    except UserNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    
    except InstallationRequestError as exc:
        raise HTTPException(
         status_code=status.HTTP_400_BAD_REQUEST,
         detail=str(exc),

        ) from exc
    
    return _result_to_response(result)

@router.get("/me",response_model=list[InstallationRequestOut])

async def my_requests(
    authorization:str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),
) -> list[Any]:
    
    firebase_user = await _get_current_firebase_user(authorization)

    user_id = await _resolve_user_id(firebase_user["uid"])

    results = await service.list_for_user(user_id=UUID(user_id))

    return [_result_to_response(r) for r in results]


def _result_to_response(result: Any) -> dict[str,Any]:
    return {
        "id":result.id,

        "user_id":result.user_id,

        "provider_id": result.provider_id,

        "package_id": result.package_id,

        "phone_e164": result.phone_e164,

        "gps_location": result.gps_location,

        "estate_or_building": result.estate_or_building,

        "house_or_apartment": result.house_or_apartment,

        "landmark": result.landmark,

        "preferred_date": result.preferred_date,

        "preferred_time": result.preferred_time,

        "status": result.status,

        "decline_reason": None,

        "completed_at": None,

        "created_at": result.created_at,
        
        "updated_at": result.updated_at,
    }