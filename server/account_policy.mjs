import {AsyncLocalStorage} from 'node:async_hooks';
import {DirectoryError} from './directory.mjs';

// Request actor follows async calls; background payment/retention work has no actor.
// Recheck under the common access write lock, so a committed ban wins over a
// queued mutation. Complaint actions deliberately retain their scoped checks.
const actions=new AsyncLocalStorage();
export const runAccountAction=(user,work,{complaint=false}={})=>actions.run({user,complaint},work);
export async function platformBlocked(db,user){
 if(!db||!user)return false;
 return !!(await db.query(`SELECT 1 FROM ca_restriction WHERE user_id=$1 AND platform
 AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at>NOW())`,[user.id])).rowCount;
}
export async function assertAccountAction(db){
 const action=actions.getStore();
 if(action&&!action.complaint&&await platformBlocked(db,action.user))throw new DirectoryError(403,'PLATFORM_BLOCKED');
}
export async function enforceAccountAction(db,user,work,options={}){
 if(!options.complaint&&await platformBlocked(db,user))throw new DirectoryError(403,'PLATFORM_BLOCKED');
 return runAccountAction(user,work,options);
}
