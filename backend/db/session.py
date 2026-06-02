from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import asyncpg

from backend.core.config import get_settings


CREATE_USERS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT UNIQUE NOT NULL,
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

CREATE_PROVIDERS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_type TEXT NOT NULL,
    CHECK (provider_type IN ('licensed_isp','local_provider')),
    provider_name TEXT NOT NULL,
    business_name TEXT,
    logo_url TEXT,
    year_started INT,
    primary_city TEXT,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    CHECK (status IN ('draft','pending_review','approved','rejected','suspended')),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

CREATE_PROVIDER_SERVICES_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS provider_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    service_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider_id, service_type)
);
"""

CREATE_PROVIDER_COVERAGE_AREAS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS provider_coverage_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    area_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_km NUMERIC NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

CREATE_PROVIDER_CONTACTS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS provider_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    contact_type TEXT NOT NULL,
    CHECK (contact_type IN ('email','phone','website','social')),
    contact_value TEXT NOT NULL,
    social_platform TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

CREATE_PROVIDER_DOCUMENTS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS provider_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    file_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    CHECK (status IN ('pending','approved','rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

CREATE_PROVIDER_PACKAGES_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS provider_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    package_name TEXT NOT NULL,
    speed_mbps INT NOT NULL,
    monthly_price NUMERIC NOT NULL,
    installation_fee NUMERIC NOT NULL DEFAULT 0,
    fair_usage_policy TEXT,
    billing_cycle TEXT NOT NULL DEFAULT 'monthly',
    contract_type TEXT NOT NULL DEFAULT 'no_contract',
    installation_period TEXT,
    router_included BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

ENSURE_USERS_ID_SQL = """
ALTER TABLE users
ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
"""

BACKFILL_USERS_ID_SQL = """
UPDATE users
SET id = gen_random_uuid()
WHERE id IS NULL;
"""

ENSURE_USERS_ID_INDEX_SQL = """
CREATE UNIQUE INDEX IF NOT EXISTS users_id_unique_idx ON users(id);
"""


@asynccontextmanager
async def get_db_connection() -> AsyncIterator[asyncpg.Connection]:
    settings = get_settings()
    ssl = "require" if "supabase.co" in settings.database_url else None
    connection = await asyncpg.connect(settings.database_url, ssl=ssl)
    try:
        await connection.execute(CREATE_USERS_TABLE_SQL)
        await connection.execute(ENSURE_USERS_ID_SQL)
        await connection.execute(BACKFILL_USERS_ID_SQL)
        await connection.execute(ENSURE_USERS_ID_INDEX_SQL)
        await connection.execute(CREATE_PROVIDERS_TABLE_SQL)
        await connection.execute(CREATE_PROVIDER_SERVICES_TABLE_SQL)
        await connection.execute(CREATE_PROVIDER_COVERAGE_AREAS_TABLE_SQL)
        await connection.execute(CREATE_PROVIDER_CONTACTS_TABLE_SQL)
        await connection.execute(CREATE_PROVIDER_DOCUMENTS_TABLE_SQL)
        await connection.execute(CREATE_PROVIDER_PACKAGES_TABLE_SQL)
        yield connection
    finally:
        await connection.close()
