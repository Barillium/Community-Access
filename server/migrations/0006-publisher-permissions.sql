CREATE TABLE ca_community_publisher (
 profile_id uuid REFERENCES ca_organizer(id) ON DELETE CASCADE,
 community_id uuid REFERENCES ca_community(id),enabled boolean NOT NULL DEFAULT false,
 PRIMARY KEY(profile_id,community_id)
);
INSERT INTO ca_community_publisher SELECT pc.profile_id,pc.community_id,true FROM ca_profile_community pc JOIN ca_organizer p ON p.id=pc.profile_id JOIN ca_host h ON h.user_id=p.owner_id AND h.community_id=pc.community_id;
CREATE INDEX ca_publisher_community ON ca_community_publisher(community_id,profile_id) WHERE enabled;
REVOKE ALL ON ca_community_publisher FROM PUBLIC;
