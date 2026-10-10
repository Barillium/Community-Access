// This grants management of one profile; it never grants community moderation.
export const organizerManager=(profile='p',viewer='$1')=>`(${profile}.owner_id=${viewer} OR EXISTS(
 SELECT 1 FROM ca_organizer_member om WHERE om.profile_id=${profile}.id AND om.user_id=${viewer}
 AND om.status='active' AND om.accepted_at IS NOT NULL))`;
export const managerCommunities=(viewer='$1')=>`SELECT h.community_id FROM ca_host h WHERE h.user_id=${viewer}
 UNION SELECT pc.community_id FROM ca_profile_community pc JOIN ca_organizer p ON p.id=pc.profile_id
 JOIN ca_host h ON h.community_id=pc.community_id AND h.user_id=p.owner_id WHERE ${organizerManager('p',viewer)}`;
