-- Additive account-service schema; no automatic erasure or financial cascade.
CREATE TABLE IF NOT EXISTS ca_account_deletion_request (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id text NOT NULL UNIQUE,
 status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','reviewing')),
 requested_at timestamptz NOT NULL DEFAULT NOW()
);
REVOKE ALL ON ca_account_deletion_request FROM PUBLIC;
