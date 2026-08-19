from __future__ import annotations

import logging
from html import escape
from uuid import UUID

from backend.db.session import get_db_connection
from backend.core.config import settings
from backend.services.email_service import email_service


logger = logging.getLogger(__name__)


async def _deliver(**message: object) -> None:
    """Deliver a notification without failing the completed business action."""
    try:
        await email_service.send(**message)  # type: ignore[arg-type]
    except Exception:
        logger.exception("Transactional email could not be delivered")


async def send_email_verification_otp(
    *, email: str, otp: str, expires_in_minutes: int
) -> None:
    await email_service.send(
        to=email,
        subject="Your OnaNet verification code",
        html=(
            "<h1>Verify your email</h1>"
            "<p>Enter this code in OnaNet to finish creating your account:</p>"
            f"<p style=\"font-size:32px;font-weight:700;letter-spacing:6px;\">{escape(otp)}</p>"
            f"<p>This code expires in {expires_in_minutes} minutes. Do not share it with anyone.</p>"
        ),
        text=(
            f"Your OnaNet verification code is {otp}.\n\n"
            f"It expires in {expires_in_minutes} minutes. Do not share it with anyone."
        ),
        tags={"category": "email_verification"},
    )


async def send_welcome_email(email: str, first_name: str | None) -> None:
    name = (first_name or "there").strip() or "there"
    safe_name = escape(name)
    await _deliver(
        to=email,
        subject="Welcome to OnaNet — let’s get you connected",
        html=f"""
        <!doctype html>
        <html lang="en">
          <body style="margin:0;background:#f7f5f2;font-family:Arial,sans-serif;color:#102a43;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
              <tr>
                <td align="center" style="padding:32px 16px;">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0"
                         style="max-width:600px;background:#ffffff;border-radius:18px;overflow:hidden;">
                    <tr>
                      <td style="background:#102a43;padding:28px 32px;">
                        <div style="font-size:28px;font-weight:800;color:#ffffff;">
                          Ona<span style="color:#00a6d6;">Net</span>
                        </div>
                      </td>
                    </tr>
                    <tr>
                      <td style="padding:36px 32px;">
                        <h1 style="margin:0 0 16px;font-size:28px;line-height:1.25;color:#102a43;">
                          Hey {safe_name}, welcome to better internet choices.
                        </h1>
                        <p style="margin:0 0 22px;font-size:16px;line-height:1.65;color:#52606d;">
                          OnaNet helps you discover internet providers that actually cover your area,
                          compare their packages clearly, and request an installation without the usual runaround.
                        </p>
                        <div style="background:#fff8e8;border-left:4px solid #f5a623;border-radius:10px;padding:18px 20px;margin:0 0 24px;">
                          <strong style="display:block;margin-bottom:8px;color:#102a43;">Here’s where to start:</strong>
                          <span style="font-size:15px;line-height:1.7;color:#52606d;">
                            Set your location, explore providers near you, then compare packages before choosing what fits.
                          </span>
                        </div>
                        <p style="margin:0;font-size:16px;line-height:1.65;color:#52606d;">
                          Open OnaNet when you’re ready—we’ll help you take it from there.
                        </p>
                      </td>
                    </tr>
                    <tr>
                      <td style="padding:20px 32px;background:#f7f5f2;font-size:13px;line-height:1.5;color:#7b8794;">
                        You received this because an OnaNet account was created with {escape(email)}.
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
        </html>
        """,
        text=(
            f"Hey {name}, welcome to better internet choices.\n\n"
            "OnaNet helps you discover providers that cover your area, compare "
            "packages clearly, and request an installation without the usual runaround.\n\n"
            "Start by setting your location, exploring nearby providers, and comparing "
            "packages before choosing what fits.\n\n"
            "Open OnaNet when you're ready—we'll help you take it from there."
        ),
        tags={"category": "welcome"},
        idempotency_key=f"welcome-{email.strip().lower()}",
    )


async def send_support_email(
    *,
    to: str,
    subject: str,
    html: str | None = None,
    text: str | None = None,
    reply_to: str | None = None,
) -> None:
    """Send customer-service mail using the dedicated support identity."""
    await _deliver(
        to=to,
        from_email=settings.RESEND_SUPPORT_FROM_EMAIL,
        reply_to=reply_to or settings.RESEND_REPLY_TO,
        subject=subject,
        html=html,
        text=text,
        tags={"category": "support"},
    )


async def send_staff_account_email(
    email: str, display_name: str, provider_name: str, role: str
) -> None:
    safe_name = escape(display_name)
    safe_provider = escape(provider_name)
    safe_role = escape(role)
    await _deliver(
        to=email,
        subject=f"You have been added to {provider_name} on OnaNet",
        html=(
            f"<h1>Hello {safe_name}</h1><p>You now have a <strong>{safe_role}</strong> "
            f"account for <strong>{safe_provider}</strong> on OnaNet.</p>"
        ),
        text=(
            f"Hello {display_name}. You now have a {role} account for "
            f"{provider_name} on OnaNet."
        ),
        tags={"category": "staff_account"},
    )


async def send_provider_review_email(
    email: str, provider_name: str, provider_id: UUID
) -> None:
    safe_provider = escape(provider_name)
    await _deliver(
        to=email,
        subject="Your OnaNet provider profile is under review",
        html=(
            f"<h1>{safe_provider} was submitted</h1>"
            "<p>We received your provider profile and it is now pending review.</p>"
        ),
        text=(
            f"{provider_name} was submitted. Your provider profile is now pending review."
        ),
        tags={"category": "provider_review"},
        idempotency_key=f"provider-review-{provider_id}",
    )


async def send_provider_status_email(
    provider_id: UUID, status: str, reason: str | None = None
) -> None:
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT u.email, p.provider_name
            FROM providers p
            JOIN users u ON u.id = p.user_id
            WHERE p.id = $1
            """,
            provider_id,
        )
    if row is None:
        return
    provider_name = str(row["provider_name"])
    safe_provider = escape(provider_name)
    normalized_status = status.strip().lower().replace("_", " ")
    clean_reason = (reason or "").strip()
    safe_reason = escape(clean_reason or "The submitted details or documents did not meet our verification requirements.")

    if normalized_status in {"verified", "approved"}:
        subject = "Your OnaNet provider verification has been approved"
        html = (
            f"<h1>Congratulations, {safe_provider} is verified</h1>"
            "<p>Our team has reviewed your provider details and supporting documents. "
            "Your verification has been approved, and your verified status is now visible on OnaNet.</p>"
            "<p>You can continue managing your coverage areas, packages, and installation requests from your provider dashboard.</p>"
            "<p>Thank you for helping clients choose internet providers with confidence.</p>"
        )
        text = (
            f"Congratulations, {provider_name} is verified.\n\n"
            "Our team reviewed your provider details and supporting documents. "
            "Your verification has been approved, and your verified status is now visible on OnaNet.\n\n"
            "You can continue managing your coverage areas, packages, and installation requests from your provider dashboard."
        )
    elif normalized_status in {"verification rejected", "rejected"}:
        subject = "Action needed: update your OnaNet provider verification"
        html = (
            f"<h1>Your verification needs some changes</h1>"
            f"<p>We reviewed the verification submission for <strong>{safe_provider}</strong>, "
            "but we could not approve it in its current form.</p>"
            f"<div style=\"background:#fff4f4;border-left:4px solid #dc2626;padding:16px;margin:20px 0;\">"
            f"<strong>Reason from our verification team:</strong><br>{safe_reason}</div>"
            "<p><strong>What to do next:</strong></p>"
            "<ol>"
            "<li>Open your OnaNet provider profile.</li>"
            "<li>Correct the details mentioned above and replace any unclear, incorrect, expired, or mismatched documents.</li>"
            "<li>Check that every name and business detail matches the official documents.</li>"
            "<li>Submit the profile for verification again.</li>"
            "</ol>"
            "<p>Once you resubmit, our team will review the corrected information. "
            "If you need help understanding the decision, reply to this email and OnaNet Support will assist you.</p>"
        )
        text = (
            f"Your verification for {provider_name} needs some changes.\n\n"
            "We could not approve the submission in its current form.\n\n"
            f"Reason from our verification team: {clean_reason or 'The submitted details or documents did not meet our verification requirements.'}\n\n"
            "What to do next:\n"
            "1. Open your OnaNet provider profile.\n"
            "2. Correct the details mentioned above and replace unclear, incorrect, expired, or mismatched documents.\n"
            "3. Check that names and business details match the official documents.\n"
            "4. Submit your provider profile for verification again.\n\n"
            "Reply to this email if you need help from OnaNet Support."
        )
    else:
        label = normalized_status
        subject = f"Update to your OnaNet provider account: {label}"
        reason_sentence = f"\n\nReason: {clean_reason}" if clean_reason else ""
        html_reason = f"<p><strong>Reason:</strong> {escape(clean_reason)}</p>" if clean_reason else ""
        html = (
            f"<h1>Provider account update</h1>"
            f"<p>The status of <strong>{safe_provider}</strong> has been updated to "
            f"<strong>{escape(label)}</strong>.</p>{html_reason}"
            "<p>Reply to this email if you need assistance from OnaNet Support.</p>"
        )
        text = f"The status of {provider_name} has been updated to {label}.{reason_sentence}"

    await _deliver(
        to=str(row["email"]),
        from_email=settings.RESEND_SUPPORT_FROM_EMAIL,
        reply_to=settings.RESEND_REPLY_TO,
        subject=subject,
        html=html,
        text=text,
        tags={"category": "provider_status"},
    )


async def send_installation_created_emails(request_id: UUID) -> None:
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT customer.email AS customer_email,
                   p.provider_name,
                   pkg.package_name
            FROM installation_requests ir
            JOIN users customer ON customer.id = ir.user_id
            JOIN providers p ON p.id = ir.provider_id
            JOIN provider_packages pkg ON pkg.id = ir.package_id
            WHERE ir.id = $1
            """,
            request_id,
        )
    if row is None:
        return
    provider_name = str(row["provider_name"])
    package_name = str(row["package_name"])
    await _deliver(
        to=str(row["customer_email"]),
        subject="Installation request submitted",
        html=(
            f"<h1>Request submitted</h1><p>Your request for "
            f"<strong>{escape(package_name)}</strong> from "
            f"<strong>{escape(provider_name)}</strong> was sent.</p>"
        ),
        text=f"Your request for {package_name} from {provider_name} was submitted.",
        tags={"category": "installation_created"},
        idempotency_key=f"installation-customer-{request_id}",
    )


async def send_installation_status_email(request_id: UUID, status: str) -> None:
    async with get_db_connection() as db:
        row = await db.fetchrow(
            """
            SELECT u.email, p.provider_name, pkg.package_name, ir.decline_reason
            FROM installation_requests ir
            JOIN users u ON u.id = ir.user_id
            JOIN providers p ON p.id = ir.provider_id
            JOIN provider_packages pkg ON pkg.id = ir.package_id
            WHERE ir.id = $1
            """,
            request_id,
        )
    if row is None:
        return
    label = "completed" if status in {"complete", "completed"} else status
    reason = str(row["decline_reason"] or "").strip()
    reason_text = f" Reason: {reason}" if reason else ""
    await _deliver(
        to=str(row["email"]),
        subject=f"Installation request {label}",
        html=(
            f"<h1>Request {escape(label)}</h1><p>Your "
            f"<strong>{escape(str(row['package_name']))}</strong> request with "
            f"<strong>{escape(str(row['provider_name']))}</strong> was "
            f"{escape(label)}.{escape(reason_text)}</p>"
        ),
        text=(
            f"Your {row['package_name']} request with {row['provider_name']} "
            f"was {label}.{reason_text}"
        ),
        tags={"category": "installation_status"},
        idempotency_key=f"installation-{status}-{request_id}",
    )


async def send_payment_confirmation_email(payment: dict[str, object]) -> None:
    email = str(payment.get("customer_email") or "").strip()
    if not email:
        return
    tier = str(payment.get("tier") or "").title()
    reference = str(payment.get("reference") or "")
    amount = payment.get("amount")
    currency = str(payment.get("currency") or "")
    await _deliver(
        to=email,
        subject=f"Your OnaNet {tier} plan is active",
        html=(
            f"<h1>{escape(tier)} plan activated</h1><p>Payment of "
            f"<strong>{escape(currency)} {escape(str(amount))}</strong> was confirmed.</p>"
        ),
        text=f"Your OnaNet {tier} plan is active. Payment: {currency} {amount}.",
        tags={"category": "payment_confirmation"},
        idempotency_key=f"payment-{reference}",
    )
