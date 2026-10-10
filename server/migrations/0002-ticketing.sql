-- Additive, local synthetic migration. Financial references deliberately have
-- no cascading foreign keys to events, profiles, or accounts.
ALTER TABLE ca_event ADD COLUMN ticket_mode text NOT NULL DEFAULT 'none'
 CHECK(ticket_mode IN('none','public','approval'));
ALTER TABLE ca_event_interest DROP CONSTRAINT ca_event_interest_status_check;
ALTER TABLE ca_event_interest ADD CONSTRAINT ca_event_interest_status_check
 CHECK(status IN('pending','purchase_eligible','approved','rejected','withdrawn','revoked'));
CREATE TABLE ca_ticket_connection (
 profile_id uuid PRIMARY KEY, account_id text NOT NULL,
 ready boolean NOT NULL DEFAULT false, synthetic boolean NOT NULL DEFAULT true
);
CREATE TABLE ca_ticket_fee (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 basis_points integer NOT NULL CHECK(basis_points BETWEEN 0 AND 9999),
 version integer NOT NULL DEFAULT 1
);
CREATE TABLE ca_ticket_config (
 event_id uuid PRIMARY KEY, profile_id uuid NOT NULL,
 mode text NOT NULL CHECK(mode IN('public','approval')),
 item_name text NOT NULL, price_cents integer NOT NULL CHECK(price_cents>0),
 quota integer NOT NULL CHECK(quota>0), version integer NOT NULL DEFAULT 1,
 provider_ready boolean NOT NULL DEFAULT false
);
CREATE TABLE ca_ticket_order (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid NOT NULL,
 profile_id uuid NOT NULL, user_id text NOT NULL, account_id text NOT NULL,
 state text NOT NULL DEFAULT 'creating' CHECK(state IN('creating','pending','paid','expired','failed','refunded')),
 blocked boolean NOT NULL DEFAULT false, age_acknowledged boolean NOT NULL,
 total_cents integer NOT NULL CHECK(total_cents>0), fee_cents integer NOT NULL CHECK(fee_cents>=0 AND fee_cents<total_cents),
 fee_version integer NOT NULL, fee_basis_points integer NOT NULL CHECK(fee_basis_points BETWEEN 0 AND 9999), refunded_cents integer NOT NULL DEFAULT 0,
 fee_refunded_cents integer NOT NULL DEFAULT 0,
 CHECK(refunded_cents BETWEEN 0 AND total_cents),
 CHECK(fee_refunded_cents BETWEEN 0 AND fee_cents),
 expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT NOW(),
 updated_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX ca_ticket_order_active ON ca_ticket_order(event_id,user_id)
 WHERE state IN('creating','pending','paid');
CREATE TABLE ca_ticket_refund (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES ca_ticket_order(id),
 reason text NOT NULL, state text NOT NULL DEFAULT 'review' CHECK(state IN('review','processing','done')),
 amount_cents integer, created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX ca_ticket_refund_open ON ca_ticket_refund(order_id) WHERE state IN('review','processing');
CREATE TABLE ca_ticket_handoff (
 digest text PRIMARY KEY, order_id uuid NOT NULL REFERENCES ca_ticket_order(id),
 user_id text NOT NULL, browser_digest text NOT NULL, expires_at timestamptz NOT NULL,
 consumed boolean NOT NULL DEFAULT false
);
-- Owner-operated native mapping only; no browser route may assign item IDs.
CREATE TABLE ca_ticket_native_binding (
 event_id uuid PRIMARY KEY, item_id integer NOT NULL CHECK(item_id>0)
);
