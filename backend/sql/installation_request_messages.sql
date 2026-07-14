ALTER TABLE installation_requests
    ADD COLUMN IF NOT EXISTS customer_message text;

ALTER TABLE installation_requests
    DROP CONSTRAINT IF EXISTS installation_requests_customer_message_length;

ALTER TABLE installation_requests
    ADD CONSTRAINT installation_requests_customer_message_length
    CHECK (customer_message IS NULL OR char_length(customer_message) <= 1000);
