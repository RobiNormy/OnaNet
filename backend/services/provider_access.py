from __future__ import annotations

import json
from contextvars import ContextVar
from typing import Any

from fastapi import Request, status
from fastapi.responses import JSONResponse

from backend.core.firebase import verify_firebase_token
from backend.db.session import get_db_connection


_staff_actor: ContextVar[dict[str, Any] | None] = ContextVar(
    "provider_staff_actor",
    default=None,
)

PROVIDER_SECTIONS = (
    "dashboard",
    "packages",
    "coverage",
    "documents",
    "installation_requests",
    "customers",
    "reviews",
    "messages",
    "analytics",
)


def default_permissions(*, can_edit: bool = False) -> dict[str, dict[str, bool]]:
    return {
        section: {"view": True, "edit": can_edit}
        for section in PROVIDER_SECTIONS
    }


def current_staff_actor() -> dict[str, Any] | None:
    return _staff_actor.get()


def _permissions(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {}
    return {}


def _section_for_path(path: str) -> str:
    if "/packages" in path:
        return "packages"
    if "/coverage-areas" in path:
        return "coverage"
    if "/documents" in path:
        return "documents"
    if path.startswith("/installation-requests"):
        return "messages" if "/messages" in path else "installation_requests"
    if "/customers" in path:
        return "customers"
    if "/reviews" in path or path.startswith("/reviews"):
        return "reviews"
    if path.startswith("/pro-analytics"):
        return "analytics"
    return "dashboard"


async def provider_staff_access_middleware(
    request: Request,
    call_next,
):
    authorization = request.headers.get("authorization")
    if not authorization or not authorization.lower().startswith("bearer "):
        return await call_next(request)

    path = request.url.path
    if not (
        path.startswith("/providers")
        or path.startswith("/installation-requests")
        or path.startswith("/subscriptions")
        or path.startswith("/pro-analytics")
        or path.startswith("/provider-staff")
        or path.startswith("/reviews")
    ):
        return await call_next(request)

    decoded = await verify_firebase_token(authorization.split(" ", 1)[1])
    if not decoded:
        return await call_next(request)

    async with get_db_connection() as db:
        staff = await db.fetchrow(
            """
            SELECT
              staff.provider_id,
              staff.role,
              staff.permissions,
              staff.is_active,
              owner.firebase_uid AS owner_firebase_uid
            FROM provider_staff_accounts staff
            JOIN users member ON member.id = staff.user_id
            JOIN providers provider ON provider.id = staff.provider_id
            JOIN users owner ON owner.id = provider.user_id
            WHERE member.firebase_uid = $1
            LIMIT 1;
            """,
            decoded["uid"],
        )

    if staff is None:
        return await call_next(request)
    if not staff["is_active"]:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "This provider staff account is inactive."},
        )
    if path.startswith("/subscriptions") or (
        path.startswith("/provider-staff") and path != "/provider-staff/me"
    ):
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "detail": (
                    "Only the provider owner can manage billing and staff accounts."
                )
            },
        )

    permissions = _permissions(staff["permissions"])
    if path not in {"/providers/me", "/provider-staff/me"}:
        section = _section_for_path(path)
        section_permissions = dict(permissions.get(section) or {})
        can_view = section_permissions.get("view") is True
        can_edit = section_permissions.get("edit") is True
        is_write = request.method.upper() not in {"GET", "HEAD", "OPTIONS"}
        if not can_view or (is_write and not can_edit):
            action = "edit" if is_write else "view"
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={
                    "detail": (
                        f"You do not have permission to {action} "
                        f"{section.replace('_', ' ')}."
                    )
                },
            )

    actor = {
        "staff_firebase_uid": decoded["uid"],
        "owner_firebase_uid": staff["owner_firebase_uid"],
        "provider_id": str(staff["provider_id"]),
        "role": staff["role"],
        "permissions": permissions,
    }
    token = _staff_actor.set(actor)
    try:
        return await call_next(request)
    finally:
        _staff_actor.reset(token)
