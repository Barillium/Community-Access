-- Only applied inside createDirectory's verified local synthetic database.
ALTER TABLE ca_organizer ADD COLUMN IF NOT EXISTS awareness_concept boolean;
ALTER TABLE ca_organizer ADD COLUMN IF NOT EXISTS awareness_team boolean;
CREATE TABLE IF NOT EXISTS ca_guest_preferences (
 user_id text PRIMARY KEY REFERENCES "user"(id) ON DELETE CASCADE,
 preferences jsonb NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS ca_community_follow (
 user_id text REFERENCES "user"(id) ON DELETE CASCADE,
 community_id uuid REFERENCES ca_community(id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,community_id)
);
-- A single boolean association; deliberately no event id, count or timestamp.
CREATE TABLE IF NOT EXISTS ca_organizer_visit (
 user_id text REFERENCES "user"(id) ON DELETE CASCADE,
 profile_id uuid REFERENCES ca_organizer(id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,profile_id)
);
CREATE TABLE IF NOT EXISTS ca_event_form (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 profile_id uuid NOT NULL REFERENCES ca_organizer(id) ON DELETE CASCADE,
 title text NOT NULL, fields jsonb NOT NULL,
 version integer NOT NULL DEFAULT 1
);
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS access_mode text NOT NULL DEFAULT 'legacy';
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS review_method text NOT NULL DEFAULT 'manual';
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS form_id uuid REFERENCES ca_event_form(id);
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS time_release_at timestamptz;
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS location_release_at timestamptz;
-- Explicitly public and independent of protected start/end/release times.
-- Existing rows stay NULL; never infer a deadline from a hidden timestamp.
ALTER TABLE ca_event ADD COLUMN IF NOT EXISTS request_deadline_at timestamptz;
CREATE TABLE IF NOT EXISTS ca_event_interest (
 event_id uuid REFERENCES ca_event(id) ON DELETE CASCADE,
 user_id text REFERENCES "user"(id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','withdrawn','revoked')),
 answers jsonb NOT NULL DEFAULT '{}', form_snapshot jsonb NOT NULL DEFAULT '[]',
 version integer NOT NULL DEFAULT 1,
 PRIMARY KEY(event_id,user_id)
);
CREATE INDEX IF NOT EXISTS ca_interest_guest ON ca_event_interest(user_id);
