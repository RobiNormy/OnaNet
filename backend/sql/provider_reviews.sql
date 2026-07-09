CREATE TABLE IF NOT EXISTS provider_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    installation_request_id uuid NOT NULL REFERENCES installation_requests(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    package_id uuid NOT NULL REFERENCES provider_packages(id) ON DELETE CASCADE,
    rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT provider_reviews_one_per_request UNIQUE (installation_request_id)
);

CREATE INDEX IF NOT EXISTS provider_reviews_provider_id_idx
    ON provider_reviews(provider_id);

CREATE INDEX IF NOT EXISTS provider_reviews_user_id_idx
    ON provider_reviews(user_id);
