from __future__ import annotations

import hashlib
import hmac
import json
import secrets
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import UUID

import httpx

from backend.core.config import settings
from backend.db.session import get_db_connection


PAYSTACK_API_URL = "https://api.paystack.co"
CURRENCY = "KES"
SUBSCRIPTION_DAYS = 30


class PaystackConfigurationError(RuntimeError):
    pass


class PaystackRequestError(RuntimeError):
    pass


@dataclass(frozen=True)
class PaymentPlan:
    tier: str
    code: str
    amount_kes: int

    @property
    def amount_minor(self) -> int:
        return self.amount_kes * 100


def configured_plan(plan_code: str) -> PaymentPlan:
    normalized = plan_code.strip()
    growth_code = (
        settings.PAYSTACK_GROWTH_PLAN_CODE
        or settings.PAYSTACK_GROWTH_KEY
        or "growth"
    ).strip()
    pro_code = (
        settings.PAYSTACK_PRO_PLAN_CODE
        or settings.PAYSTACK_PRO_KEY
        or "pro"
    ).strip()
    aliases = {
        "growth": PaymentPlan(
            tier="growth",
            code=growth_code,
            amount_kes=settings.PAYSTACK_GROWTH_AMOUNT_KES,
        ),
        growth_code: PaymentPlan(
            tier="growth",
            code=growth_code,
            amount_kes=settings.PAYSTACK_GROWTH_AMOUNT_KES,
        ),
        "pro": PaymentPlan(
            tier="pro",
            code=pro_code,
            amount_kes=settings.PAYSTACK_PRO_AMOUNT_KES,
        ),
        pro_code: PaymentPlan(
            tier="pro",
            code=pro_code,
            amount_kes=settings.PAYSTACK_PRO_AMOUNT_KES,
        ),
    }
    plan = aliases.get(normalized)
    if plan is None:
        raise ValueError("Unknown Paystack plan code.")
    return plan


def verify_webhook_signature(body: bytes, signature: str | None) -> bool:
    secret = settings.PAYSTACK_SECRET_KEY
    if not secret or not signature:
        return False
    expected = hmac.new(
        secret.encode("utf-8"),
        body,
        hashlib.sha512,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def _secret_key() -> str:
    secret = (settings.PAYSTACK_SECRET_KEY or "").strip()
    if not secret:
        raise PaystackConfigurationError(
            "Paystack is not configured. Add PAYSTACK_SECRET_KEY in Railway."
        )
    return secret


def _headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {_secret_key()}",
        "Content-Type": "application/json",
    }


def new_reference(provider_id: UUID, tier: str) -> str:
    token = secrets.token_hex(8)
    return f"ona_{tier}_{str(provider_id)[:8]}_{token}"


async def initialize_transaction(
    *,
    provider_id: UUID,
    firebase_uid: str,
    email: str,
    plan_code: str,
) -> dict[str, Any]:
    plan = configured_plan(plan_code)
    reference = new_reference(provider_id, plan.tier)

    async with get_db_connection() as db:
        account = await db.fetchrow(
            """
            SELECT u.id AS user_id, u.email, p.provider_name
            FROM providers p
            JOIN users u ON u.id = p.user_id
            WHERE p.id = $1 AND u.firebase_uid = $2
            """,
            provider_id,
            firebase_uid,
        )
        if account is None:
            raise PermissionError(
                "Provider not found or you do not own this provider account."
            )
        payment_id = await db.fetchval(
            """
            INSERT INTO provider_payments(
                provider_id, user_id, reference, plan_code, tier,
                amount_minor, currency, customer_email, status
            )
            VALUES($1,$2,$3,$4,$5,$6,$7,$8,'initializing')
            RETURNING id
            """,
            provider_id,
            account["user_id"],
            reference,
            plan.code,
            plan.tier,
            plan.amount_minor,
            CURRENCY,
            email.strip().lower(),
        )

    callback_url = (settings.PAYSTACK_CALLBACK_URL or "").strip()
    payload: dict[str, Any] = {
        "email": email.strip().lower(),
        "amount": str(plan.amount_minor),
        "currency": CURRENCY,
        "reference": reference,
        "metadata": {
            "payment_id": str(payment_id),
            "provider_id": str(provider_id),
            "provider_name": account["provider_name"],
            "tier": plan.tier,
        },
    }
    if callback_url:
        payload["callback_url"] = callback_url
    if plan.code.startswith("PLN_"):
        payload["plan"] = plan.code

    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                f"{PAYSTACK_API_URL}/transaction/initialize",
                headers=_headers(),
                json=payload,
            )
            result = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        await _mark_initialization_failed(reference, str(exc))
        raise PaystackRequestError(
            "Could not connect to Paystack. Please try again."
        ) from exc

    data = result.get("data") if isinstance(result, dict) else None
    if response.status_code >= 400 or not result.get("status") or not data:
        message = result.get("message", "Paystack rejected the transaction.")
        await _mark_initialization_failed(reference, message)
        raise PaystackRequestError(message)

    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE provider_payments
            SET status='pending', access_code=$2, authorization_url=$3,
                updated_at=now()
            WHERE reference=$1
            """,
            reference,
            data.get("access_code"),
            data.get("authorization_url"),
        )

    return {
        "payment_id": str(payment_id),
        "provider_id": str(provider_id),
        "tier": plan.tier,
        "amount": plan.amount_kes,
        "amount_minor": plan.amount_minor,
        "currency": CURRENCY,
        "reference": reference,
        "access_code": data.get("access_code"),
        "authorization_url": data.get("authorization_url"),
        "status": "pending",
    }


async def _mark_initialization_failed(reference: str, message: str) -> None:
    async with get_db_connection() as db:
        await db.execute(
            """
            UPDATE provider_payments
            SET status='failed', failure_reason=$2, updated_at=now()
            WHERE reference=$1
            """,
            reference,
            message[:1000],
        )


async def verify_transaction(reference: str) -> dict[str, Any]:
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.get(
                f"{PAYSTACK_API_URL}/transaction/verify/{reference}",
                headers=_headers(),
            )
            result = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise PaystackRequestError(
            "Could not verify the Paystack transaction."
        ) from exc

    if response.status_code >= 400 or not result.get("status"):
        raise PaystackRequestError(
            result.get("message", "Paystack could not verify this transaction.")
        )
    data = result.get("data") or {}
    if data.get("status") != "success":
        return {
            "reference": reference,
            "status": data.get("status", "pending"),
            "paid": False,
        }
    return await fulfill_successful_payment(data)


async def fulfill_successful_payment(data: dict[str, Any]) -> dict[str, Any]:
    reference = str(data.get("reference") or "")
    if not reference:
        raise PaystackRequestError("Paystack response did not include a reference.")

    async with get_db_connection() as db:
        async with db.transaction():
            payment = await db.fetchrow(
                """
                SELECT *
                FROM provider_payments
                WHERE reference=$1
                FOR UPDATE
                """,
                reference,
            )
            if payment is None:
                raise PaystackRequestError("Payment reference is not recognized.")
            if payment["status"] == "success":
                return _payment_result(payment, paid=True)

            received_amount = int(data.get("amount") or 0)
            received_currency = str(data.get("currency") or "").upper()
            if received_amount != payment["amount_minor"]:
                raise PaystackRequestError("Verified payment amount does not match.")
            if received_currency != payment["currency"]:
                raise PaystackRequestError("Verified payment currency does not match.")

            paid_at = _parse_paystack_datetime(data.get("paid_at"))
            transaction_id = str(data.get("id") or "")
            await db.execute(
                """
                UPDATE provider_payments
                SET status='success', paystack_transaction_id=$2,
                    channel=$3, paid_at=coalesce($4,now()),
                    gateway_response=$5, raw_response=$6::jsonb,
                    updated_at=now()
                WHERE id=$1
                """,
                payment["id"],
                transaction_id or None,
                data.get("channel"),
                paid_at,
                data.get("gateway_response"),
                json.dumps(data, default=str),
            )
            await db.execute(
                """
                UPDATE providers
                SET subscription_tier=$2,
                    subscription_expires_at=
                        greatest(now(),coalesce(subscription_expires_at,now()))
                        + ($3::int * interval '1 day'),
                    updated_at=now()
                WHERE id=$1
                """,
                payment["provider_id"],
                payment["tier"],
                SUBSCRIPTION_DAYS,
            )
            await db.execute(
                """
                INSERT INTO admin_invoices(
                    invoice_number, provider_id, plan, amount,
                    period, due_date, status
                )
                VALUES(
                    $1,$2,$3,$4,
                    to_char(now(),'Mon YYYY'),current_date,'paid'
                )
                ON CONFLICT(invoice_number) DO UPDATE SET status='paid'
                """,
                reference,
                payment["provider_id"],
                payment["tier"],
                payment["amount_minor"] / 100,
            )
            completed = dict(payment)
            completed["status"] = "success"
            completed["paid_at"] = paid_at
            return _payment_result(completed, paid=True)


def _parse_paystack_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _payment_result(payment: Any, *, paid: bool) -> dict[str, Any]:
    return {
        "payment_id": str(payment["id"]),
        "provider_id": str(payment["provider_id"]),
        "reference": payment["reference"],
        "tier": payment["tier"],
        "amount": payment["amount_minor"] / 100,
        "currency": payment["currency"],
        "customer_email": payment["customer_email"],
        "status": "success" if paid else payment["status"],
        "paid": paid,
    }
