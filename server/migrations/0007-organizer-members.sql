-- Canonical owner/seller stays in ca_organizer; collaboration needs acceptance.
CREATE TABLE ca_organizer_member (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 role text NOT NULL DEFAULT 'manager' CHECK(role='manager'),
 status text NOT NULL DEFAULT 'invited' CHECK(status IN('invited','active','revoked')),
 invited_by text NOT NULL REFERENCES "user"(id),
 expires_at timestamptz NOT NULL DEFAULT NOW()+INTERVAL '7 days',
 accepted_at timestamptz,version integer NOT NULL DEFAULT 1 CHECK(version>0),
 UNIQUE(profile_id,user_id),CHECK(status<>'active' OR accepted_at IS NOT NULL)
);
CREATE INDEX ca_organizer_member_person ON ca_organizer_member(user_id,profile_id) WHERE status='active';
REVOKE ALL ON ca_organizer_member FROM PUBLIC;
