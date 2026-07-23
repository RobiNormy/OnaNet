CREATE INDEX IF NOT EXISTS provider_packages_provider_price_idx
    ON provider_packages(provider_id, monthly_price);

CREATE INDEX IF NOT EXISTS provider_coverage_provider_created_idx
    ON provider_coverage_areas(provider_id, created_at);

CREATE INDEX IF NOT EXISTS provider_reviews_provider_updated_idx
    ON provider_reviews(provider_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS providers_status_created_idx
    ON providers(created_at DESC)
    WHERE status != 'suspended';

CREATE INDEX IF NOT EXISTS users_firebase_uid_idx
    ON users(firebase_uid);
