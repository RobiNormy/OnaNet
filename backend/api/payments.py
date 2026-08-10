from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse
from pydantic import EmailStr

from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection
from backend.services.paystack_service import (
    PaystackConfigurationError,
    PaystackRequestError,
    fulfill_successful_payment,
    initialize_transaction,
    verify_transaction,
    verify_webhook_signature,
)
from backend.services.email_notifications import send_payment_confirmation_email


router = APIRouter(prefix="/api/payments", tags=["payments"])


async def ensure_payments_schema() -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS provider_payments (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                provider_id uuid NOT NULL REFERENCES providers(id)
                    ON DELETE CASCADE,
                user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                reference text UNIQUE NOT NULL,
                plan_code text NOT NULL,
                tier text NOT NULL CHECK(tier IN ('growth','pro')),
                amount_minor bigint NOT NULL CHECK(amount_minor > 0),
                currency text NOT NULL DEFAULT 'KES',
                customer_email text NOT NULL,
                status text NOT NULL DEFAULT 'initializing',
                access_code text,
                authorization_url text,
                paystack_transaction_id text UNIQUE,
                channel text,
                gateway_response text,
                failure_reason text,
                raw_response jsonb,
                paid_at timestamptz,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS provider_payments_provider_created_idx
                ON provider_payments(provider_id,created_at DESC);
            CREATE INDEX IF NOT EXISTS provider_payments_status_idx
                ON provider_payments(status);
            """
        )


@router.post("/initialize")
async def initialize_paystack_payment(
    provider_id: UUID,
    plan_code: str = Query(min_length=2, max_length=100),
    email: EmailStr = Query(),
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    try:
        return await initialize_transaction(
            provider_id=provider_id,
            firebase_uid=firebase_user["uid"],
            email=str(email),
            plan_code=plan_code,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PaystackConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except PaystackRequestError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/verify/{reference}")
async def verify_paystack_payment(
    reference: str,
    background_tasks: BackgroundTasks,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as db:
        owned = await db.fetchval(
            """
            SELECT EXISTS(
                SELECT 1
                FROM provider_payments payment
                JOIN users ON users.id=payment.user_id
                WHERE payment.reference=$1 AND users.firebase_uid=$2
            )
            """,
            reference,
            firebase_user["uid"],
        )
    if not owned:
        raise HTTPException(status_code=404, detail="Payment not found.")
    try:
        payment = await verify_transaction(reference)
        if payment.get("paid"):
            background_tasks.add_task(send_payment_confirmation_email, payment)
        return payment
    except PaystackConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except PaystackRequestError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/callback", response_class=HTMLResponse)
async def paystack_callback(reference: str = Query(min_length=8)) -> HTMLResponse:
    try:
        result = await verify_transaction(reference)
        paid = bool(result.get("paid"))
        title = "Payment successful" if paid else "Payment pending"
        message = (
            "Your OnaNet subscription is active. You may return to the app."
            if paid
            else "Your payment is still processing. Return to OnaNet and refresh shortly."
        )
    except (PaystackConfigurationError, PaystackRequestError):
        title = "Payment verification delayed"
        message = (
            "We could not verify this payment yet. Return to OnaNet and use "
            "Refresh payment; your plan will only activate after verification."
        )
    return HTMLResponse(
        f"""
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>{title} · OnaNet</title>
        </head>
        <body style="margin:0;background:#081725;color:#f8fafc;
          font-family:system-ui,sans-serif;display:grid;place-items:center;
          min-height:100vh">
          <main style="max-width:440px;padding:32px;text-align:center">
            <div style="font-size:42px;color:#00a6d6">✓</div>
            <h1>{title}</h1>
            <p style="color:#94a3b8;line-height:1.6">{message}</p>
          </main>
        </body>
        </html>
        """
    )


@router.get("/{reference}")
async def payment_status(
    reference: str,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    async with get_db_connection() as db:
        payment = await db.fetchrow(
            """
            SELECT payment.id,payment.provider_id,payment.reference,
                   payment.tier,payment.amount_minor,payment.currency,
                   payment.status,payment.paid_at
            FROM provider_payments payment
            JOIN users ON users.id=payment.user_id
            WHERE payment.reference=$1 AND users.firebase_uid=$2
            """,
            reference,
            firebase_user["uid"],
        )
    if payment is None:
        raise HTTPException(status_code=404, detail="Payment not found.")
    return {
        "payment_id": str(payment["id"]),
        "provider_id": str(payment["provider_id"]),
        "reference": payment["reference"],
        "tier": payment["tier"],
        "amount": payment["amount_minor"] / 100,
        "currency": payment["currency"],
        "status": payment["status"],
        "paid_at": (
            payment["paid_at"].isoformat() if payment["paid_at"] else None
        ),
    }


@router.post("/paystack/webhook")
async def paystack_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    x_paystack_signature: str | None = Header(default=None),
) -> dict[str, bool]:
    body = await request.body()
    if not verify_webhook_signature(body, x_paystack_signature):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Paystack signature.",
        )
    try:
        event = json.loads(body)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid webhook body.") from exc

    if event.get("event") == "charge.success":
        try:
            payment = await fulfill_successful_payment(event.get("data") or {})
            background_tasks.add_task(send_payment_confirmation_email, payment)
        except PaystackRequestError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"received": True}
