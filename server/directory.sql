-- Additive schema, exclusively for the verified local synthetic database.
CREATE TABLE IF NOT EXISTS ca_community (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL,is_public boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS ca_host (
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 community_id uuid NOT NULL REFERENCES ca_community(id) ON DELETE CASCADE,PRIMARY KEY(user_id,community_id)
);
CREATE TABLE IF NOT EXISTS ca_organizer (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 display_name text NOT NULL,description text NOT NULL DEFAULT '',is_public boolean NOT NULL DEFAULT false,
 allow_application boolean NOT NULL DEFAULT false,allow_form boolean NOT NULL DEFAULT false,allow_link boolean NOT NULL DEFAULT false,
 form jsonb NOT NULL DEFAULT '[]',form_version integer NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS ca_profile_community (
 profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 community_id uuid NOT NULL REFERENCES ca_community(id) ON DELETE CASCADE,PRIMARY KEY(profile_id,community_id)
);
CREATE TABLE IF NOT EXISTS ca_profile_request (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,method text NOT NULL CHECK(method IN('application','form','link')),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','approved','rejected','withdrawn','revoked')),
 form_snapshot jsonb NOT NULL DEFAULT '[]',answers jsonb NOT NULL DEFAULT '{}',created_at timestamptz NOT NULL DEFAULT NOW(),UNIQUE(profile_id,user_id)
);
CREATE TABLE IF NOT EXISTS ca_profile_link (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,digest text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,used_at timestamptz,revoked boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS ca_event (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),community_id uuid NOT NULL REFERENCES ca_community(id),title text NOT NULL,
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','cancelled')),is_public boolean NOT NULL DEFAULT false,
 starts_at timestamptz,starts_public boolean NOT NULL DEFAULT false,public_location text NOT NULL DEFAULT '',location_public boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS ca_request_user_status ON ca_profile_request(user_id,status);
CREATE INDEX IF NOT EXISTS ca_event_community ON ca_event(community_id);

-- Local-only additive extension. Existing events retain their current public flags.
CREATE TABLE IF NOT EXISTS ca_series (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 community_id uuid NOT NULL REFERENCES ca_community(id),title text NOT NULL,description text NOT NULL DEFAULT '',
 is_public boolean NOT NULL DEFAULT false,version integer NOT NULL DEFAULT 1
);
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES ca_organizer(id) ON DELETE CASCADE;
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS series_id uuid REFERENCES ca_series(id);
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS ca_series_grant (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),series_id uuid NOT NULL REFERENCES ca_series(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1,UNIQUE(series_id,user_id)
);
CREATE TABLE IF NOT EXISTS ca_event_grant (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),event_id uuid NOT NULL REFERENCES ca_event(id) ON DELETE CASCADE,
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1,UNIQUE(event_id,user_id)
);
CREATE INDEX IF NOT EXISTS ca_series_profile ON ca_series(profile_id);
CREATE INDEX IF NOT EXISTS ca_event_profile ON ca_event(profile_id);
CREATE INDEX IF NOT EXISTS ca_event_series ON ca_event(series_id);

-- Local synthetic upgrade: one host account may own several independent profiles.
ALTER TABLE ca_organizer DROP CONSTRAINT IF EXISTS ca_organizer_owner_id_key;
CREATE INDEX IF NOT EXISTS ca_organizer_owner ON ca_organizer(owner_id);
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS access_details jsonb NOT NULL DEFAULT '{}';
CREATE TABLE IF NOT EXISTS ca_bookmark (
 user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
 profile_id uuid REFERENCES ca_organizer(id) ON DELETE CASCADE,
 series_id uuid REFERENCES ca_series(id) ON DELETE CASCADE,
 CHECK ((profile_id IS NOT NULL)::integer + (series_id IS NOT NULL)::integer = 1)
);
CREATE UNIQUE INDEX IF NOT EXISTS ca_bookmark_profile ON ca_bookmark(user_id,profile_id) WHERE profile_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ca_bookmark_series ON ca_bookmark(user_id,series_id) WHERE series_id IS NOT NULL;

-- Local additive upgrade: each bookmark targets one profile, series or event.
ALTER TABLE ca_bookmark ADD COLUMN IF NOT EXISTS event_id uuid REFERENCES ca_event(id) ON DELETE CASCADE;
ALTER TABLE ca_bookmark DROP CONSTRAINT IF EXISTS ca_bookmark_check;
ALTER TABLE ca_bookmark ADD CONSTRAINT ca_bookmark_check CHECK (
 (profile_id IS NOT NULL)::integer + (series_id IS NOT NULL)::integer + (event_id IS NOT NULL)::integer = 1
);
CREATE UNIQUE INDEX IF NOT EXISTS ca_bookmark_event ON ca_bookmark(user_id,event_id) WHERE event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ca_bookmark_profile_target ON ca_bookmark(profile_id) WHERE profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ca_bookmark_series_target ON ca_bookmark(series_id) WHERE series_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ca_bookmark_event_target ON ca_bookmark(event_id) WHERE event_id IS NOT NULL;

-- Local synthetic editorial event content; existing events keep empty content.
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS event_content jsonb NOT NULL DEFAULT '{}';
