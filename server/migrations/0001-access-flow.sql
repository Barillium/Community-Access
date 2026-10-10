CREATE TABLE ca_team (user_id text PRIMARY KEY REFERENCES "user"(id) ON DELETE CASCADE);
CREATE TABLE ca_organizer_application (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','approved','rejected','withdrawn')),
 answers jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW(), decided_at timestamptz,
 community_id uuid REFERENCES ca_community(id), profile_id uuid REFERENCES ca_organizer(id)
);
CREATE UNIQUE INDEX ca_organizer_application_pending ON ca_organizer_application(user_id) WHERE status='pending';
CREATE TABLE ca_organizer_block (user_id text PRIMARY KEY REFERENCES "user"(id) ON DELETE CASCADE);
CREATE TABLE ca_community_form (
 community_id uuid PRIMARY KEY REFERENCES ca_community(id) ON DELETE CASCADE,
 fields jsonb NOT NULL DEFAULT '[]', version integer NOT NULL DEFAULT 1,
 host_contact text NOT NULL DEFAULT ''
);
CREATE TABLE ca_community_invitation (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), community_id uuid NOT NULL REFERENCES ca_community(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 issuer_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 digest text NOT NULL UNIQUE, expires_at timestamptz NOT NULL, used_at timestamptz,
 revoked boolean NOT NULL DEFAULT false
);
CREATE TABLE ca_community_application (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), community_id uuid NOT NULL REFERENCES ca_community(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','approved','rejected','withdrawn')),
 form_snapshot jsonb NOT NULL, answers jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT NOW(), decided_at timestamptz
);
CREATE UNIQUE INDEX ca_community_application_pending ON ca_community_application(community_id,user_id) WHERE status='pending';
CREATE TABLE ca_membership (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), community_id uuid NOT NULL REFERENCES ca_community(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE, active boolean NOT NULL DEFAULT true,
 UNIQUE(community_id,user_id)
);
CREATE TABLE ca_community_block (
 community_id uuid REFERENCES ca_community(id) ON DELETE CASCADE,
 user_id text REFERENCES "user"(id) ON DELETE CASCADE,
 reason text NOT NULL CHECK(reason IN('rejected','revoked')), PRIMARY KEY(community_id,user_id)
);
ALTER TABLE ca_event ADD COLUMN membership_required boolean NOT NULL DEFAULT false;
ALTER TABLE ca_event ADD COLUMN capacity integer CHECK(capacity>0);
CREATE TABLE ca_event_location (
 event_id uuid PRIMARY KEY REFERENCES ca_event(id) ON DELETE CASCADE, exact_location text NOT NULL
);
ALTER TABLE ca_event_interest ADD COLUMN age_acknowledged boolean NOT NULL DEFAULT false;
CREATE INDEX ca_membership_guest ON ca_membership(user_id,active);
CREATE INDEX ca_invitation_guest ON ca_community_invitation(user_id,community_id);
