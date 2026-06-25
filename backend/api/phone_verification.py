from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter,Depends,Header,HTTPException,status

from pydantic import BaseModel,Field

from backend.api.auth import _get_current_firebase_user

from backend.db.session import get_db_connection
from datetime import datetime,timezone

from backend.services.otp_service import(
    OtpError,
    OtpInvalid,
    OtpNotFound,
    OtpRateLimited,
    OtpService,
    get_otp_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/phone",tags=["phone-verification"])


class StartRequest(BaseModel):
    phone: str = Field(...,min_length=8,max_length=20)

class StartResponse(BaseModel):
    sent: bool
    phone: str

    expires_in_seconds: int

class VerifyRequest(BaseModel):
    phone: str = Field(...,min_length=8,max_length=20)

    otp: str = Field(...,min_length=4,max_length=8)

class VerifyResponse(BaseModel):
    verified: bool
    phone: str

class StatusResponse(BaseModel):
    phone_number: str | None = None

    is_phone_verifiedd: bool = False

async def _resolver_user_id(firebase_uid: str) -> str:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM users WHERE firebase_uid = $1",
            firebase_uid,
        )

    if row is None:
        raise HTTPException(
            status_code= status.HTTP_404_NOT_FOUND,
            detail="User Profile not found"

        )
    return str(row["id"])


@router.post("/start",response_model=StartResponse)
async def start_verification(
    body: StartRequest,
    authorization: str | None = Header (default=None),
    otp_service: OtpService = Depends(get_otp_service),
)-> StartResponse:
    firebase_user = await _get_current_firebase_user(authorization)
    user_id = await _resolver_user_id(firebase_user["uid"])
    try:
        result = await otp_service.start_verification(
            user_id = user_id,
            phone_e164 = body.phone,
        )
    except OtpRateLimited as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc
    
    except OtpError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    ttl_seconds = max(0,int((result.expires_at - datetime.now(timezone.utc)).total_seconds()))
    return StartResponse(
        sent = True,
        phone=result.phone_e164,
        expires_in_seconds=ttl_seconds
    )

@router.post("/verify",response_model=VerifyResponse)

async def verify_otp(
    body: VerifyRequest,
    authorization: str | None = Header(default=None),
    otp_service: OtpService =  Depends(get_otp_service),
) -> VerifyResponse:
    firebase_user = await _get_current_firebase_user(authorization)
    user_id = await _resolver_user_id(firebase_user["uid"])

    try:
        result = await otp_service.verify(
            user_id = user_id,
            phone_e164 = body.phone,
            otp = body.otp,
        )
    except OtpNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail = str(exc),
        ) from exc
    
    except OtpInvalid as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except OtpError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    
    return VerifyResponse(verified=True,phone=result.phone_e164)

@router.get("/status",response_model=StatusResponse)

async def phone_status(
    authorization: str | None = Header(default=None),
) -> StatusResponse:
    firebase_user = await _get_current_firebase_user(authorization)
    user_id = await _resolver_user_id(firebase_user["uid"])

    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            "SELECT phone_number, is_phone_verified FROM users WHERE id = $1",
            user_id,
        )

        if row is None:
            raise HTTPException(
                status_code = status.HTTP_404_NOT_FOUND,
                detail="User profile not found",
            )
        
        return StatusResponse(
            phone_number=row["phone_number"],
            is_phone_verifiedd=bool(row["is_phone_verified"]),
        )