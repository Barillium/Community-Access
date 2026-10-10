-- Additive upgrade. Existing accepted applications remain accepted; no production data.
ALTER TABLE ca_membership ADD COLUMN accepted_at timestamptz DEFAULT NOW();
ALTER TABLE ca_membership ADD COLUMN expires_at timestamptz;
ALTER TABLE ca_event_grant ADD COLUMN expires_at timestamptz;
ALTER TABLE ca_event_grant ADD COLUMN revoked_at timestamptz;
CREATE TABLE ca_event_community_access (
 event_id uuid REFERENCES ca_event(id) ON DELETE CASCADE,
 community_id uuid REFERENCES ca_community(id) ON DELETE CASCADE,
 approved boolean NOT NULL DEFAULT false, grants_visibility boolean NOT NULL DEFAULT false,
 PRIMARY KEY(event_id,community_id)
);
INSERT INTO ca_event_community_access SELECT id,community_id,true,membership_required FROM ca_event;
CREATE INDEX ca_event_community_access_target ON ca_event_community_access(community_id,event_id);
CREATE TABLE ca_community_staff (
 community_id uuid REFERENCES ca_community(id) ON DELETE CASCADE,
 user_id text REFERENCES "user"(id) ON DELETE CASCADE,
 expires_at timestamptz NOT NULL, PRIMARY KEY(community_id,user_id)
);
CREATE TABLE ca_restriction (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id text NOT NULL REFERENCES "user"(id),
 event_id uuid REFERENCES ca_event(id), community_id uuid REFERENCES ca_community(id),
 profile_id uuid REFERENCES ca_organizer(id), platform boolean NOT NULL DEFAULT false,
 created_by text NOT NULL REFERENCES "user"(id), reviewed_by text REFERENCES "user"(id),
 expires_at timestamptz, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT NOW(),
 CHECK(num_nonnulls(event_id,community_id,profile_id)+platform::integer=1),
 CHECK(expires_at IS NULL OR expires_at>created_at),
 CHECK(reviewed_by IS NULL OR reviewed_by<>created_by),
 CHECK(expires_at IS NOT NULL OR reviewed_by IS NOT NULL)
);
CREATE INDEX ca_restriction_person ON ca_restriction(user_id) WHERE revoked_at IS NULL;
CREATE TABLE ca_moderation_case (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), community_id uuid NOT NULL REFERENCES ca_community(id),
 subject_id text NOT NULL REFERENCES "user"(id), assigned_to text NOT NULL REFERENCES "user"(id),
 created_by text NOT NULL REFERENCES "user"(id), details text NOT NULL,
 restriction_id uuid REFERENCES ca_restriction(id), created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE ca_moderation_appeal (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), case_id uuid NOT NULL REFERENCES ca_moderation_case(id),
 user_id text NOT NULL REFERENCES "user"(id), details text NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW(),
 UNIQUE(case_id,user_id)
);
CREATE TABLE ca_ticket_type (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid NOT NULL REFERENCES ca_event(id),
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
 price_cents integer NOT NULL CHECK(price_cents>0), currency text NOT NULL DEFAULT 'EUR' CHECK(currency='EUR'),
 quota integer NOT NULL CHECK(quota>0),
 visibility_mode text NOT NULL CHECK(visibility_mode IN('inherit_event','community_subset','explicit_grant')),
 purchase_rule text NOT NULL CHECK(purchase_rule IN('visible_authenticated','event_approval_required')),
 sales_start timestamptz, sales_end timestamptz, enabled boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1, provider_ready boolean NOT NULL DEFAULT false,
 UNIQUE(id,event_id), CHECK(sales_end IS NULL OR sales_start IS NULL OR sales_end>sales_start)
);
CREATE INDEX ca_ticket_type_event ON ca_ticket_type(event_id);
CREATE TABLE ca_ticket_type_community (
 type_id uuid REFERENCES ca_ticket_type(id), community_id uuid REFERENCES ca_community(id), PRIMARY KEY(type_id,community_id)
);
CREATE TABLE ca_ticket_type_grant (
 type_id uuid REFERENCES ca_ticket_type(id), user_id text REFERENCES "user"(id),
 expires_at timestamptz NOT NULL, revoked_at timestamptz, PRIMARY KEY(type_id,user_id)
);
ALTER TABLE ca_ticket_order ADD COLUMN type_id uuid;
ALTER TABLE ca_ticket_order ADD CONSTRAINT ca_ticket_order_type_event FOREIGN KEY(type_id,event_id) REFERENCES ca_ticket_type(id,event_id);
ALTER TABLE ca_ticket_order ADD COLUMN admission_state text NOT NULL DEFAULT 'pending'
 CHECK(admission_state IN('pending','active','admission_hold','used','cancelled'));
UPDATE ca_ticket_order SET admission_state=CASE WHEN blocked THEN 'admission_hold' WHEN state='paid' THEN 'active' ELSE 'pending' END;
CREATE TABLE ca_ticket_token (
 order_id uuid PRIMARY KEY REFERENCES ca_ticket_order(id), digest text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE ca_scanner (
 event_id uuid REFERENCES ca_event(id), user_id text REFERENCES "user"(id),
 expires_at timestamptz NOT NULL, PRIMARY KEY(event_id,user_id)
);
CREATE TABLE ca_checkin (
 order_id uuid PRIMARY KEY REFERENCES ca_ticket_order(id), event_id uuid NOT NULL,
 actor_id text NOT NULL REFERENCES "user"(id), checked_at timestamptz NOT NULL DEFAULT NOW(),
 UNIQUE(order_id,event_id)
);
CREATE TABLE ca_policy_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor_id text NOT NULL,
 action text NOT NULL, resource_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW()
);
-- New tables are not exposed to browser SQL. Authentication and all actor checks
-- live in narrow HTTP endpoints; auth_app is a trusted backend role, never a client.
REVOKE ALL ON ca_event_community_access,ca_community_staff,ca_restriction,ca_moderation_case,
 ca_moderation_appeal,ca_ticket_type,ca_ticket_type_community,ca_ticket_type_grant,
 ca_ticket_token,ca_scanner,ca_checkin,ca_policy_audit FROM PUBLIC;
