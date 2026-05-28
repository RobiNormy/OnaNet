from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials

from backend.core.config import get_settings


def init_firebase() -> None:
    if firebase_admin._apps:
        return

    settings = get_settings()
    options: dict[str, str] = {}
    if settings.firebase_project_id:
        options["projectId"] = settings.firebase_project_id

    credential = _load_credential(settings.firebase_service_account_path)
    firebase_admin.initialize_app(credential, options=options or None)


def verify_firebase_token(token: str) -> dict[str, Any]:
    init_firebase()
    return auth.verify_id_token(token)


def _load_credential(path: str | None) -> credentials.Base:
    if not path:
        return credentials.ApplicationDefault()

    credential_path = Path(path).expanduser()
    if not credential_path.exists():
        return credentials.ApplicationDefault()

    os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", str(credential_path))

    try:
        data = json.loads(credential_path.read_text())
    except (OSError, json.JSONDecodeError):
        return credentials.ApplicationDefault()

    if data.get("type") == "service_account":
        return credentials.Certificate(str(credential_path))

    return credentials.ApplicationDefault()
