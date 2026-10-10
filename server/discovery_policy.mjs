// Compatibility exports for the existing access/retention paths.
import {eventPolicy} from './event_policy.mjs';
export {retainedEvent} from './event_policy.mjs';
export {confirmedParticipation as approvedGuest} from './access_policy.mjs';
const rules=eventPolicy();
export const releasedTime=rules.time;
export const releasedLocation=rules.location;
export const safeContent=rules.content;
