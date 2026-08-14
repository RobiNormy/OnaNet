from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_user
from backend.db.session import get_db_connection
from backend.services.email_otp_service import (
    EmailOtpError,
    EmailOtpInvalid,
    EmailOtpNotFound,
    EmailOtpRateLimited,
    EmailOtpService,
    get_email_otp_service,
)


router = APIRouter(prefix="/email-verification", tags=["email-verification"])


class VerifyRequest(BaseModel):
    otp: str = Field(min_length=4, max_length=8)


class StartResponse(BaseModel):
    sent: bool
    email: str
    expires_in_seconds: int


class StatusResponse(BaseModel):
    is_email_verified: bool


async def _user_id(firebase_uid: str) -> UUID:
    async with get_db_connection() as connection:
        value = await connection.fetchval(
            "SELECT id FROM users WHERE firebase_uid = $1",
            firebase_uid,
        )
    if value is None:
        raise HTTPException(status_code=404, detail="User profile not found.")
    return UUID(str(value))


@router.post("/start", response_model=StartResponse)
async def start_verification(
    authorization: str | None = Header(default=None),
    otp_service: EmailOtpService = Depends(get_email_otp_service),
) -> StartResponse:
    firebase_user = await _get_current_user(authorization)
    try:
        result = await otp_service.start(user_id=await _user_id(firebase_user["uid"]))
    except EmailOtpRateLimited as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except EmailOtpError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    seconds = max(0, int((result.expires_at - datetime.now(timezone.utc)).total_seconds()))
    return StartResponse(sent=True, email=result.email, expires_in_seconds=seconds)


@router.post("/verify")
async def verify_email(
    body: VerifyRequest,
    authorization: str | None = Header(default=None),
    otp_service: EmailOtpService = Depends(get_email_otp_service),
) -> dict[str, bool]:
    firebase_user = await _get_current_user(authorization)
    try:
        await otp_service.verify(
            user_id=await _user_id(firebase_user["uid"]),
            otp=body.otp,
        )
    except EmailOtpNotFound as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except (EmailOtpInvalid, EmailOtpError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"verified": True}


@router.get("/status", response_model=StatusResponse)
async def verification_status(
    authorization: str | None = Header(default=None),
    otp_service: EmailOtpService = Depends(get_email_otp_service),
) -> StatusResponse:
    firebase_user = await _get_current_user(authorization)
    try:
        verified = await otp_service.is_verified(
            user_id=await _user_id(firebase_user["uid"])
        )
    except EmailOtpError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return StatusResponse(is_email_verified=verified)
