import {extendedProduct} from './product_scope.mjs';
// Aggregate only verified accounts. Never return bookmark identities or user rows.
export function bookmarkCount(column,target){
 if(!['profile_id','series_id','event_id'].includes(column))throw new Error('Invalid bookmark target');
 if(!extendedProduct)return 'NULL::integer';
 return `(SELECT count(*)::int FROM ca_bookmark interest JOIN "user" interested ON interested.id=interest.user_id WHERE interest.${column}=${target} AND interested."emailVerified")`;
}
export const publicSeries=`s.is_public AND p.is_public AND c.is_public AND EXISTS(SELECT 1 FROM ca_host current_host WHERE current_host.user_id=p.owner_id AND current_host.community_id=c.id)`;
export const profileInterest=`CASE WHEN p.is_public THEN ${bookmarkCount('profile_id','p.id')} END`;
export const seriesInterest=`CASE WHEN ${publicSeries} THEN ${bookmarkCount('series_id','s.id')} END`;
