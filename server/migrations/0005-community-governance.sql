-- Community administration is an explicitly assigned moderator scope.
CREATE TABLE ca_community_rule_version (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),community_id uuid NOT NULL REFERENCES ca_community(id),
 version integer NOT NULL CHECK(version>0),rules text NOT NULL CHECK(length(rules) BETWEEN 1 AND 8000),
 created_by text NOT NULL REFERENCES "user"(id),created_at timestamptz NOT NULL DEFAULT NOW(),UNIQUE(community_id,version)
);
ALTER TABLE ca_community_application ADD COLUMN rule_version_id uuid REFERENCES ca_community_rule_version(id);
ALTER TABLE ca_membership ADD COLUMN approved_by text REFERENCES "user"(id);
ALTER TABLE ca_membership ADD COLUMN approved_at timestamptz;
ALTER TABLE ca_membership ADD COLUMN application_id uuid REFERENCES ca_community_application(id) ON DELETE SET NULL;
CREATE INDEX ca_ticket_type_grant_person ON ca_ticket_type_grant(user_id,type_id);
CREATE INDEX ca_ticket_type_community_target ON ca_ticket_type_community(community_id,type_id);
CREATE INDEX ca_scanner_person ON ca_scanner(user_id,expires_at);
CREATE INDEX ca_checkin_event ON ca_checkin(event_id,checked_at);
CREATE INDEX ca_case_community ON ca_moderation_case(community_id,created_at);
CREATE INDEX ca_case_subject ON ca_moderation_case(subject_id);
CREATE INDEX ca_appeal_case ON ca_moderation_appeal(case_id);
REVOKE ALL ON ca_community_rule_version FROM PUBLIC;
