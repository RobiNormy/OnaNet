from __future__ import annotations
import logging
from typing import Any
from fastapi import APIRouter,Depends,Header,HTTPException,status
from uuid import UUID
from pydantic import BaseModel,Field
from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection
from backend.providers.schema.installation_request import (
    InstallationRequestCreate,
    InstallationRequestOut,
)

from backend.services.installation_service import (
    InstallationRequestError,
    InstallationRequestResult,
    InstallationRequestService,
    IncompleteAddress,
    PhoneNotVerified,
    ProviderOrPackageMissing,
    UserNotFound,
    WrongProvider,
    InvalidStatusTransition,
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


def _result_to_response(result: InstallationRequestResult) -> InstallationRequestOut:
    return InstallationRequestOut(
        id = result.id,
        user_id = result.user_id,
        provider_id = result.provider_id,
        package_id = result.package_id,
        package_name = result.package_name,
        phone_e164 = result.phone_e164,

        gps_location = result.gps_location,

        estate_or_building = result.estate_or_building,

        house_or_apartment = result.house_or_apartment,

        landmark = result.landmark,

        preferred_date = result.preferred_date,

        preferred_time = result.preferred_time,

        status = result.status,

        decline_reason = result.decline_reason,

        completed_at = result.completed_at,

        created_at = result.created_at,
    
        updated_at = result.updated_at,
    )

async def _resolve_provider_id(firebase_uid: str)-> str:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            """
            SELECT p.id AS provider_id
                FROM providers p
                JOIN users u ON u.id = p.user_id
            WHERE u.firebase_uid = $1

            """,
            firebase_uid,
        )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No provider profile linked in this account.",

        )
    return str(row["provider_id"])


@router.get("/inbox",response_model=list[InstallationRequestOut])

async def list_provider_inbox(
    status_filter: str | None = None,
    authorization: str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),
) -> list[Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    results = await service.list_for_provider(
        provider_id=UUID(provider_id),
        status_filter=status_filter,
    )

    return [_result_to_response(r) for r in results]

@router.get("/inbox/{request_id}", response_model=InstallationRequestOut)

async def get_provider_inboc_item(
    request_id:UUID,
    authorization: str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),

) -> Any:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    result = await service.get_for_provider(
        request_id =request_id,
        provider_id =UUID(provider_id),
    )

    return _result_to_response(result)

@router.post("/{request_id}/accept", response_model=InstallationRequestOut)
async def accept_request(
    request_id: UUID,
    authorization: str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service)
)-> Any:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    try : 
        result = await service.accept(
            request_id = request_id,
            provider_id = UUID(provider_id),
        )
    
    except WrongProvider as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,detail=str(exc)) from exc
    
    except InvalidStatusTransition as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,detail=str(exc)) from exc
    
    except InstallationRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,detail=str(exc)) from exc
    
    return _result_to_response(result)

class DeclineBody(BaseModel):
    reason: str | None = Field(default=None,max_length = 500)

@router.post("/{request_id}/decline",response_model=InstallationRequestOut)
async def decline_request(
    request_id: UUID,
    body: DeclineBody | None = None,
    authorization: str | None =Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),
) -> Any:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    try :
        result = await service.decline(
            request_id = request_id,
            provider_id = UUID(provider_id),
            reason = body.reason if body else None,
        )

    except WrongProvider as exc:
        raise HTTPException (status_code=status.HTTP_403_FORBIDDEN,detail=str(exc)) from exc
    
    except InvalidStatusTransition as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,detail=str(exc)) from exc
    
    except InstallationRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,detail=str(exc)) from exc

    return _result_to_response(result)

@router.post("/{request_id}/complete", response_model=InstallationRequestOut)

async def complete_request(

    request_id: UUID,
    authorization: str | None = Header(default=None),
    service: InstallationRequestService = Depends(get_installation_request_service),

) -> Any:

    firebase_user = await _get_current_firebase_user(authorization)
    provider_id = await _resolve_provider_id(firebase_user["uid"])

    try:
        result = await service.complete(
            request_id=request_id,
            provider_id=UUID(provider_id),

        )
    except WrongProvider as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc

    except InvalidStatusTransition as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc

    except InstallationRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return _result_to_response(result)
