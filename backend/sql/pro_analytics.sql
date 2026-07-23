CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS provider_views (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(), provider_id uuid REFERENCES providers(id) ON DELETE CASCADE,
    view_type text NOT NULL CHECK (view_type IN ('search','profile','package')), area_name text,
    latitude double precision, longitude double precision, speed_filter_mbps integer,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE provider_views
  ADD COLUMN IF NOT EXISTS package_id uuid
    REFERENCES provider_packages(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS provider_views_provider_date_idx ON provider_views(provider_id,created_at DESC);
CREATE INDEX IF NOT EXISTS provider_views_package_date_idx ON provider_views(package_id,created_at DESC);
CREATE TABLE IF NOT EXISTS search_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(), search_id uuid NOT NULL,
    provider_id uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    result_position integer NOT NULL CHECK(result_position>0), area_name text,
    latitude double precision, longitude double precision, speed_filter_mbps integer,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS search_logs_provider_date_idx ON search_logs(provider_id,created_at DESC);
ALTER TABLE installation_requests ADD COLUMN IF NOT EXISTS installation_area text,
 ADD COLUMN IF NOT EXISTS installation_latitude double precision,
 ADD COLUMN IF NOT EXISTS installation_longitude double precision,
 ADD COLUMN IF NOT EXISTS installer_name text,
 ADD COLUMN IF NOT EXISTS commission_amount numeric(12,2) NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS installed_at timestamptz;
