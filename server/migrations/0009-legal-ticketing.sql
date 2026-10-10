-- Local additive upgrade. No invented sellers or accepted declarations for old events.
CREATE TABLE ca_ticket_seller (
 profile_id uuid PRIMARY KEY, legal_name text NOT NULL, address text NOT NULL,
 contact text NOT NULL, seller_status text NOT NULL CHECK(seller_status IN('private','business')),
 version integer NOT NULL DEFAULT 1, updated_by text NOT NULL, updated_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE ca_event_declaration (
 event_id uuid NOT NULL, version integer NOT NULL, event_version integer NOT NULL,
 seller_version integer NOT NULL, confirmed boolean NOT NULL,
 terms_version text NOT NULL, actor_id text NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW(),
 PRIMARY KEY(event_id,version)
);
ALTER TABLE ca_event ADD COLUMN legal_state text NOT NULL DEFAULT 'active'
 CHECK(legal_state IN('active','sales_paused','blocked'));
ALTER TABLE ca_event ADD COLUMN legal_version integer NOT NULL DEFAULT 0;
ALTER TABLE ca_ticket_order ADD COLUMN seller_snapshot jsonb NOT NULL DEFAULT '{}';
ALTER TABLE ca_ticket_order ADD COLUMN declaration_snapshot jsonb NOT NULL DEFAULT '{}';
ALTER TABLE ca_ticket_order ADD COLUMN legal_stopped boolean NOT NULL DEFAULT false;
CREATE FUNCTION ca_legal_snapshot_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.seller_snapshot IS DISTINCT FROM OLD.seller_snapshot OR NEW.declaration_snapshot IS DISTINCT FROM OLD.declaration_snapshot THEN
  RAISE EXCEPTION 'Ticket legal snapshot is immutable';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ca_ticket_legal_snapshot BEFORE UPDATE ON ca_ticket_order
 FOR EACH ROW EXECUTE FUNCTION ca_legal_snapshot_immutable();
-- No foreign keys to events/accounts: reports and minimal financial proof survive deletion.
CREATE TABLE ca_legal_report (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid, reference text NOT NULL,
 details text NOT NULL, reporter_name text NOT NULL, reporter_email text NOT NULL,
 contact_exception boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'open' CHECK(status IN('open','decided')),
 assigned_to text, version integer NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE ca_legal_action (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), report_id uuid NOT NULL REFERENCES ca_legal_report(id),
 event_id uuid, profile_id uuid, actor_id text NOT NULL,
 action text NOT NULL CHECK(action IN('sales_paused','blocked','active','no_action')),
 basis text NOT NULL CHECK(basis IN('clarification','prohibition','danger','cancellation','resolved','unsubstantiated')),
 reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE ca_legal_statement (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action_id uuid NOT NULL REFERENCES ca_legal_action(id),
 actor_id text NOT NULL, details text NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW(),
 UNIQUE(action_id,actor_id)
);
CREATE TABLE ca_legal_notice (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient text NOT NULL, kind text NOT NULL,
 report_id uuid NOT NULL REFERENCES ca_legal_report(id), message text NOT NULL,
 synthetic boolean NOT NULL DEFAULT true CHECK(synthetic), created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE INDEX ca_legal_report_queue ON ca_legal_report(status,created_at);
CREATE INDEX ca_legal_actions_event ON ca_legal_action(event_id,created_at);
REVOKE ALL ON ca_ticket_seller,ca_event_declaration,ca_legal_report,ca_legal_action,ca_legal_statement,ca_legal_notice FROM PUBLIC;
