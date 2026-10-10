-- This is a persistent pretix contract double, NOT the pretix schema/runtime.
CREATE TABLE IF NOT EXISTS pt_event (
 id uuid PRIMARY KEY, price_cents integer NOT NULL CHECK(price_cents>0),
 item_name text NOT NULL, quota integer NOT NULL CHECK(quota>0),
 version integer NOT NULL
);
CREATE TABLE IF NOT EXISTS pt_order (
 id uuid PRIMARY KEY, event_id uuid NOT NULL REFERENCES pt_event(id),
 subject text NOT NULL, account_id text NOT NULL,
 state text NOT NULL DEFAULT 'pending', blocked boolean NOT NULL DEFAULT false,
 valid_payment boolean NOT NULL DEFAULT false,
 total_cents integer NOT NULL, fee_cents integer NOT NULL,
 refunded_cents integer NOT NULL DEFAULT 0, fee_refunded_cents integer NOT NULL DEFAULT 0,
 expires_at timestamptz NOT NULL DEFAULT NOW()+INTERVAL '15 minutes',
 CHECK(state IN('pending','paid','expired','failed','refunded'))
);
CREATE UNIQUE INDEX IF NOT EXISTS pt_order_active ON pt_order(event_id,subject)
 WHERE state IN('pending','paid');
CREATE TABLE IF NOT EXISTS pt_refund (
 id uuid PRIMARY KEY, order_id uuid NOT NULL REFERENCES pt_order(id), amount_cents integer NOT NULL
);
CREATE TABLE IF NOT EXISTS pt_type (
 id uuid PRIMARY KEY,event_id uuid NOT NULL REFERENCES pt_event(id),
 price_cents integer NOT NULL CHECK(price_cents>0),quota integer NOT NULL CHECK(quota>0),
 version integer NOT NULL CHECK(version>0),UNIQUE(id,event_id)
);
ALTER TABLE pt_order ADD COLUMN IF NOT EXISTS type_id uuid;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='pt_order_type_event') THEN
 ALTER TABLE pt_order ADD CONSTRAINT pt_order_type_event FOREIGN KEY(type_id,event_id) REFERENCES pt_type(id,event_id);
 END IF;
END $$;
