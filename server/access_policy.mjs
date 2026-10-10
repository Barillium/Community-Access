// A single write lock is deliberate for this small, local prototype. Every
// access-affecting transaction takes it before row locks, including older paths.
export const accessWriteLock = 'SELECT pg_advisory_xact_lock(73100526)';
export const communityAllowed=(community,viewer='$1')=>`NOT EXISTS(SELECT 1 FROM ca_community_block cb WHERE cb.community_id=${community} AND cb.user_id=${viewer})
 AND NOT EXISTS(SELECT 1 FROM ca_restriction cr WHERE cr.community_id=${community} AND cr.user_id=${viewer}
 AND cr.revoked_at IS NULL AND (cr.expires_at IS NULL OR cr.expires_at>NOW()))`;
export const activeMembership = `EXISTS(SELECT 1 FROM ca_membership m
 WHERE m.user_id=$1 AND m.active AND m.accepted_at IS NOT NULL AND (m.expires_at IS NULL OR m.expires_at>NOW())
 AND (${communityAllowed('m.community_id')}) AND (m.community_id=e.community_id OR EXISTS(
 SELECT 1 FROM ca_event_community_access ec WHERE ec.event_id=e.id AND ec.community_id=m.community_id AND ec.approved AND ec.grants_visibility)))`;
export const eventNotRestricted=`NOT EXISTS(SELECT 1 FROM ca_restriction r WHERE r.user_id=$1
 AND r.revoked_at IS NULL AND (r.expires_at IS NULL OR r.expires_at>NOW())
 AND (r.platform OR r.event_id=e.id OR r.profile_id=e.profile_id))`;
export const profileNotRevoked = `NOT EXISTS(SELECT 1 FROM ca_profile_request b
 WHERE b.profile_id=p.id AND b.user_id=$1 AND b.status='revoked')`;
export const activeProfileHost = `EXISTS(SELECT 1 FROM ca_profile_community pc
 JOIN ca_host h ON h.community_id=pc.community_id AND h.user_id=p.owner_id
 WHERE pc.profile_id=p.id)`;
export const confirmedParticipation = `(EXISTS(SELECT 1 FROM ca_event_interest i
 WHERE i.event_id=e.id AND i.user_id=$1 AND i.status='approved')
 AND (e.ticket_mode='none' OR EXISTS(SELECT 1 FROM ca_ticket_order t
 WHERE t.event_id=e.id AND t.user_id=$1 AND t.state='paid' AND NOT t.blocked))
 AND (NOT e.membership_required OR ${activeMembership} OR EXISTS(SELECT 1 FROM ca_event_grant eg WHERE eg.event_id=e.id AND eg.user_id=$1 AND eg.active AND eg.revoked_at IS NULL AND (eg.expires_at IS NULL OR eg.expires_at>NOW()))) AND ${profileNotRevoked} AND ${eventNotRestricted})`;
