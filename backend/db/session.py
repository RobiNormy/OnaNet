from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import asyncpg

from backend.core.config import get_settings


CREATE_USERS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS users (
    firebase_uid TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    first_name TEXT,
    last_name TEXT,
    phone_number TEXT,
    profile_image_url TEXT,
    auth_provider TEXT,
    role TEXT NOT NULL DEFAULT 'user',
    is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""


@asynccontextmanager
async def get_db_connection() -> AsyncIterator[asyncpg.Connection]:
    settings = get_settings()
    ssl = "require" if "supabase.co" in settings.database_url else None
    connection = await asyncpg.connect(settings.database_url, ssl=ssl)
    try:
        await connection.execute(CREATE_USERS_TABLE_SQL)
        yield connection
    finally:
        await connection.close()
