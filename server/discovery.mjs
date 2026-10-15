import {extendedProduct,productEventScope} from './product_scope.mjs';
import {assertAccountAction} from './account_policy.mjs';
import {accessWriteLock,confirmedParticipation,activeProfileHost} from './access_policy.mjs';
import {organizerManager} from './organizer_access.mjs';
import {DirectoryError} from './directory.mjs';
import {checkedForm} from './form_policy.mjs';
import {retainedEvent,eventPolicy,eventJoins} from './event_policy.mjs';
const rules=eventPolicy();
const fail=(status,code)=>{throw new DirectoryError(status,code);};
const id=v=>{if(typeof v!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v))fail(404,'NOT_FOUND');return v;};
const text=(v,max,required=false)=>{if(typeof v!=='string'||v.length>max||(required&&!v.trim()))fail(422,'INVALID_FIELDS');return v.trim();};
const signed=u=>{if(!u)fail(401,'UNAUTHENTICATED');};
const verified=u=>{signed(u);if(!u.emailVerified)fail(403,'VERIFY_EMAIL');};
const futureDate=v=>{if(v===null||v===undefined||v==='')return null;if(typeof v!=='string'||v.length>40||!/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,3})?)?(?:Z|[+-]\d\d:\d\d)$/.test(v)||!Number.isFinite(Date.parse(v)))fail(422,'INVALID_DATE');return new Date(v).toISOString();};
export function cleanPreferences(body){
 if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).some(k=>!['event_types','music','favorites','leisure'].includes(k)))fail(422,'INVALID_PREFERENCES');
 const out={};for(const key of ['event_types','music','favorites','leisure']){
  const a=body[key]??[];if(!Array.isArray(a)||a.length>12)fail(422,'INVALID_PREFERENCES');
  out[key]=[...new Set(a.map(v=>text(v,80,true)))];
 }return out;
}
export function createDiscovery(pool,catalog){
 async function tx(fn){const db=await pool.connect();try{await db.query('BEGIN');await db.query(accessWriteLock);await assertAccountAction(db);const r=await fn(db);await db.query('COMMIT');return r;}catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}}
 async function owner(db,u,profile){verified(u);const p=(await db.query(`SELECT p.* FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()} AND ${activeProfileHost} FOR UPDATE`,[u.id,id(profile)])).rows[0];if(!p)fail(404,'NOT_FOUND');return p;}
 async function eventOwner(db,u,event){const row=(await db.query('SELECT profile_id FROM ca_event WHERE id=$1',[id(event)])).rows[0];if(!row)fail(404,'NOT_FOUND');const p=await owner(db,u,row.profile_id);const e=(await db.query(`SELECT e.* FROM ca_event e WHERE e.id=$1 AND ${retainedEvent} AND EXISTS(SELECT 1 FROM ca_host h WHERE h.user_id=$2 AND h.community_id=e.community_id) FOR UPDATE`,[event,p.owner_id])).rows[0];if(!e)fail(404,'NOT_FOUND');return e;}
 async function preferences(u,body){signed(u);if(body!==undefined){const clean=cleanPreferences(body);await tx(db=>db.query('INSERT INTO ca_guest_preferences VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET preferences=$2',[u.id,JSON.stringify(clean)]));}const row=(await pool.query('SELECT preferences FROM ca_guest_preferences WHERE user_id=$1',[u.id])).rows[0];const visits=(await pool.query(`SELECT v.profile_id AS id,CASE WHEN ${activeProfileHost} AND (p.is_public OR p.owner_id=$1 OR EXISTS(SELECT 1 FROM ca_profile_request r WHERE r.profile_id=p.id AND r.user_id=$1 AND r.status='approved')) THEN p.display_name ELSE '' END AS name FROM ca_organizer_visit v JOIN ca_organizer p ON p.id=v.profile_id WHERE v.user_id=$1 ORDER BY v.profile_id`,[u.id])).rows;return {preferences:row?.preferences??cleanPreferences({}),configured:!!row,visited_organizers:visits};}
 async function forgetVisit(u,body){signed(u);await tx(db=>db.query('DELETE FROM ca_organizer_visit WHERE user_id=$1 AND profile_id=$2',[u.id,id(body.id)]));return {forgotten:true};}
 async function follow(u,body){verified(u);if(typeof body.following!=='boolean')fail(422,'INVALID_FIELDS');const c=(await pool.query('SELECT id FROM ca_community WHERE id=$1 AND is_public',[id(body.id)])).rows[0];if(!c)fail(404,'NOT_FOUND');await tx(db=>body.following?db.query('INSERT INTO ca_community_follow VALUES($1,$2) ON CONFLICT DO NOTHING',[u.id,c.id]):db.query('DELETE FROM ca_community_follow WHERE user_id=$1 AND community_id=$2',[u.id,c.id]));return {following:body.following};}
 async function communities(u){return {items:(await pool.query(`WITH visible_events AS (
  SELECT e.id,e.community_id ${eventJoins} WHERE ${rules.upcoming}
 ), assignments AS (
  SELECT id,community_id FROM visible_events
  UNION
  SELECT e.id,linked.community_id FROM visible_events e
   JOIN ca_event_community_access linked ON linked.event_id=e.id AND linked.approved
 ), counts AS (
  SELECT community_id,count(*)::int AS event_count FROM assignments GROUP BY community_id
 ) SELECT listed.id,listed.name,
  EXISTS(SELECT 1 FROM ca_community_follow f WHERE f.community_id=listed.id AND f.user_id=$1) AS following,
  COALESCE(counts.event_count,0) AS event_count
  FROM ca_community listed LEFT JOIN counts ON counts.community_id=listed.id
  WHERE listed.is_public ORDER BY listed.name,listed.id`,[u?.id??null])).rows,signed_in:!!u};}
 async function saveForm(u,body){return tx(async db=>{await owner(db,u,body.profile_id);const fields=checkedForm(body.fields);if(!fields.length)fail(422,'EMPTY_FORM');const title=text(body.title,120,true);let r;if(body.id){r=await db.query('UPDATE ca_event_form SET title=$1,fields=$2,version=version+1 WHERE id=$3 AND profile_id=$4 AND version=$5 RETURNING id,version',[title,JSON.stringify(fields),id(body.id),body.profile_id,body.version]);if(!r.rowCount)fail(409,'FORM_CHANGED');}else r=await db.query('INSERT INTO ca_event_form(profile_id,title,fields) VALUES($1,$2,$3) RETURNING id,version',[body.profile_id,title,JSON.stringify(fields)]);return r.rows[0];});}
 async function forms(u,profile){signed(u);return (await pool.query(`SELECT f.* FROM ca_event_form f JOIN ca_organizer p ON p.id=f.profile_id WHERE ${organizerManager()} AND p.id=$2 AND ${activeProfileHost} ORDER BY f.title,f.id`,[u.id,profile])).rows;}
 async function eventOptions(db,body,profile,existing,publication){
  const mode=publication.mode;
  const method=body.review_method??existing?.review_method??'manual';if(!['manual','form','invite'].includes(method))fail(422,'INVALID_FIELDS');
  const formId=body.form_id===undefined?existing?.form_id??null:body.form_id;
  if(formId&&!(await db.query('SELECT id FROM ca_event_form WHERE id=$1 AND profile_id=$2',[id(formId),profile])).rowCount)fail(422,'INVALID_FORM');
  if(method==='form'&&!formId)fail(422,'EMPTY_FORM');
  const time=futureDate(body.time_release_at===undefined?existing?.time_release_at?.toISOString():body.time_release_at),location=futureDate(body.location_release_at===undefined?existing?.location_release_at?.toISOString():body.location_release_at);
  const deadline=futureDate(body.request_deadline_at===undefined?existing?.request_deadline_at?.toISOString():body.request_deadline_at);
  if(mode==='semi_public'&&body.status==='published'&&(!time||!location))fail(422,'RELEASE_REQUIRED');
  if(mode==='semi_public'&&body.status==='published'&&!deadline)fail(422,'REQUEST_DEADLINE_REQUIRED');
  if(mode==='semi_public'&&(body.starts_public||body.location_public||(body.event_content?.flyer_data??existing?.event_content?.flyer_data)))fail(422,'SEMI_PUBLIC_CONTENT');
  if(['published','cancelled'].includes(body.status)&&!(body.event_content??existing?.event_content)?.ends_at)fail(422,'END_REQUIRED');
  if(mode==='public'&&body.status==='published'&&(!body.starts_at||!body.starts_public||!body.location_public||!body.public_location?.trim()||!body.event_content?.description?.trim()))fail(422,'PUBLIC_INFO_REQUIRED');
  return {mode,method,formId,time,location,deadline};
 }
 async function eligible(db,e,userId) {
  if(!(await db.query(`SELECT e.id ${eventJoins} WHERE e.id=$2 AND ${rules.visible}`,[userId,e.id])).rowCount)fail(403,'ACCESS_BLOCKED');
  const blocked=(await db.query("SELECT 1 FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2 AND status='revoked'",[e.profile_id,userId])).rowCount;
  if(blocked)fail(403,'ACCESS_BLOCKED');
 }
 async function beforeStart(db,e){
  if(e.status!=='published'||!e.starts_at)fail(409,'EVENT_UNAVAILABLE');
  if((await db.query('SELECT $1::timestamptz<=NOW() AS started',[e.starts_at])).rows[0].started)fail(409,'EVENT_STARTED');
 }
 async function interest(u,event,body){verified(u);return tx(async db=>{
  await catalog.eventDetail(event,u,db);
  const e=(await db.query(`SELECT e.*,${rules.requestWindow} AS request_open ${eventJoins}
   WHERE e.id=$2 AND ${rules.visible} FOR UPDATE OF e`,[u.id,id(event)])).rows[0];if(!e)fail(404,'NOT_FOUND');
  if(e.ticket_mode==='public')fail(409,'USE_TICKET_CHECKOUT');
  if(!e.request_open)fail(409,'REQUEST_CLOSED');await eligible(db,e,u.id);
  if(e.review_method==='invite'&&!(await db.query('SELECT 1 FROM ca_event_grant WHERE event_id=$1 AND user_id=$2 AND active',[e.id,u.id])).rowCount)fail(403,'ACCESS_DISABLED');
  const f=e.form_id?(await db.query('SELECT * FROM ca_event_form WHERE id=$1',[e.form_id])).rows[0]:null;
  const fields=e.review_method==='form'?checkedForm(f?.fields??[]):[];
  if(e.review_method==='form'&&(!f||body.form_version!==f.version))fail(409,'FORM_CHANGED');
  if(!body.answers||typeof body.answers!=='object'||Array.isArray(body.answers)||Object.keys(body.answers).some(k=>!fields.some(f=>f.key===k)))fail(422,'INVALID_ANSWERS');
  const answers={};for(const f of fields)answers[f.key]=text(body.answers[f.key]??'',500,f.required);
  if(e.event_content.minimum_age!==null&&e.event_content.minimum_age!==undefined&&body.age_acknowledged!==true)fail(422,'AGE_ACKNOWLEDGEMENT_REQUIRED');
  const old=(await db.query('SELECT status FROM ca_event_interest WHERE event_id=$1 AND user_id=$2 FOR UPDATE',[event,u.id])).rows[0];
  if(old&&old.status!=='withdrawn')fail(409,'REQUEST_EXISTS');
  await db.query(`INSERT INTO ca_event_interest(event_id,user_id,answers,form_snapshot,age_acknowledged) VALUES($1,$2,$3,$4,$5)
   ON CONFLICT(event_id,user_id) DO UPDATE SET status='pending',answers=$3,form_snapshot=$4,age_acknowledged=$5,version=ca_event_interest.version+1`,[event,u.id,JSON.stringify(answers),JSON.stringify(fields),body.age_acknowledged===true]);return {status:'pending'};
 });}
 async function decide(u,body){return tx(async db=>{
  const e=await eventOwner(db,u,body.event_id);
  const i=(await db.query('SELECT * FROM ca_event_interest WHERE event_id=$1 AND user_id=$2 FOR UPDATE',[e.id,text(body.user_id,255,true)])).rows[0];
  if(!i)fail(404,'NOT_FOUND');
  if(body.version!==i.version)fail(409,'CATALOG_CHANGED');
  if(!['approved','rejected','revoked'].includes(body.status))fail(422,'INVALID_FIELDS');
  const target=body.status==='approved'&&e.ticket_mode!=='none'?'purchase_eligible':body.status;
  if(i.status===target)return {status:i.status};
  if(!(i.status==='pending'&&['approved','rejected'].includes(body.status)||['approved','purchase_eligible'].includes(i.status)&&body.status==='revoked'))fail(409,'INVALID_TRANSITION');
  if(body.status==='approved'){
   await beforeStart(db,e);await eligible(db,e,i.user_id);
   if(e.event_content.minimum_age!==null&&e.event_content.minimum_age!==undefined&&!i.age_acknowledged)fail(422,'AGE_ACKNOWLEDGEMENT_REQUIRED');
   const n=(await db.query("SELECT COUNT(*)::int AS n FROM ca_event_interest WHERE event_id=$1 AND status='approved'",[e.id])).rows[0].n;
   if(e.ticket_mode==='none'&&e.capacity!==null&&n>=e.capacity)fail(409,'EVENT_FULL');
   const previous=(await db.query('SELECT status FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2 FOR UPDATE',[e.profile_id,i.user_id])).rows[0];
   if(previous?.status==='revoked')fail(403,'ACCESS_BLOCKED');
   // Event admission is independent of organizer-profile access.
  }
  await db.query(`UPDATE ca_event_interest SET status=$3,answers=CASE WHEN $3 IN('revoked','rejected') THEN '{}'::jsonb ELSE answers END,version=version+1 WHERE event_id=$1 AND user_id=$2`,[e.id,i.user_id,target]);return {status:target};
 });}
 async function withdraw(u,event){verified(u);return tx(async db=>{
  // Check both the event and the viewer's own live request before consulting time.
  const e=(await db.query(`SELECT e.id,${rules.withdrawalWindow} AS withdrawal_open ${eventJoins}
   JOIN ca_event_interest i ON i.event_id=e.id AND i.user_id=$1 AND i.status IN('pending','approved','purchase_eligible')
   WHERE e.id=$2 AND ${rules.visible} FOR UPDATE OF e,i`,[u.id,id(event)])).rows[0];if(!e)fail(404,'NOT_FOUND');
  if(!e.withdrawal_open)fail(409,'REQUEST_CLOSED');
  const r=(await db.query("UPDATE ca_event_interest SET status='withdrawn',answers='{}',version=version+1 WHERE event_id=$1 AND user_id=$2 AND status IN('pending','approved','purchase_eligible') RETURNING status",[e.id,u.id])).rows[0];
  if(!r)fail(409,'INVALID_TRANSITION');return r;
 });}
 async function access(u,event){
  await catalog.eventDetail(event,u);
  const info=(await pool.query(`SELECT e.ticket_mode,e.review_method,e.form_id,e.event_content,e.membership_required,e.capacity,e.community_id,e.request_deadline_at,
   CASE WHEN ${rules.time} THEN e.starts_at>NOW() END AS before_start,
   ${rules.exactLocation} AS can_location,${rules.requestWindow} AS can_request,${rules.withdrawalWindow} AS withdrawal_open,${rules.visitWindow} AS can_visit
   ${eventJoins} WHERE e.id=$2 AND ${rules.visible}`,[u?.id??null,id(event)])).rows[0];if(!info)fail(404,'NOT_FOUND');
  const f=info?.form_id?(await pool.query('SELECT fields,version FROM ca_event_form WHERE id=$1',[info.form_id])).rows[0]:null;
  const member=!!u&&!!(await pool.query('SELECT 1 FROM ca_membership WHERE community_id=$1 AND user_id=$2 AND active',[info.community_id,u.id])).rowCount;
  const ownRequest=u?(await pool.query('SELECT status,version FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,u.id])).rows[0]??null:null;
  return {signed_in:!!u,ticket_mode:info.ticket_mode,method:info.review_method,form:info.review_method==='form'?f?.fields??[]:[],form_version:f?.version??null,
   minimum_age:info.event_content?.minimum_age??null,membership_required:info.membership_required,is_member:member,capacity:info.capacity,
   personally_invited:!!u&&!!(await pool.query('SELECT 1 FROM ca_event_grant WHERE event_id=$1 AND user_id=$2 AND active',[event,u.id])).rowCount,
   before_start:info.before_start,request_deadline_at:info.request_deadline_at,can_request:info.can_request,
   can_location:info.can_location,can_withdraw:info.withdrawal_open&&['pending','approved','purchase_eligible'].includes(ownRequest?.status),request:ownRequest,can_visit:extendedProduct&&info.can_visit};
 }
 async function visit(u,event){verified(u);return tx(async db=>{
  const e=await catalog.eventDetail(event,u,db);
  if(!e.event_content?.ends_at)fail(403,'ACCESS_DISABLED');
  const row=(await db.query(`SELECT e.profile_id,e.event_content->>'ends_at' AS ends_at FROM ca_event e JOIN ca_organizer p ON p.id=e.profile_id WHERE e.id=$2 AND ${confirmedParticipation} FOR UPDATE OF e`,[u.id,id(event)])).rows[0];
  if(!row)fail(403,'ACCESS_DISABLED');
  if(!row.ends_at||Date.parse(row.ends_at)>Date.now())fail(409,'EVENT_NOT_ENDED');
  await db.query('INSERT INTO ca_organizer_visit VALUES($1,$2) ON CONFLICT DO NOTHING',[u.id,row.profile_id]);return {visited:true};
 });}
 async function management(u,profile){return {forms:await forms(u,profile),event_requests:(await pool.query(`SELECT i.event_id,i.user_id,i.status,i.version,i.answers,i.form_snapshot,e.title,e.ticket_mode,u.name AS guest FROM ca_event_interest i JOIN ca_event e ON e.id=i.event_id JOIN ca_organizer p ON p.id=e.profile_id JOIN "user" u ON u.id=i.user_id WHERE ${productEventScope} AND ${organizerManager()} AND p.id=$2 AND EXISTS(SELECT 1 FROM ca_host h WHERE h.user_id=p.owner_id AND h.community_id=e.community_id) AND ${retainedEvent} ORDER BY e.title,i.user_id`,[u.id,profile])).rows};}
 async function purge(){return tx(async db=>{await db.query('SELECT pg_advisory_xact_lock(73100426)');const r=await db.query(`DELETE FROM ca_event e WHERE e.event_content->>'ends_at' IS NOT NULL AND NOT (${retainedEvent}) AND NOT EXISTS(SELECT 1 FROM ca_ticket_type tt WHERE tt.event_id=e.id) AND NOT EXISTS(SELECT 1 FROM ca_restriction r WHERE r.event_id=e.id) AND NOT EXISTS(SELECT 1 FROM ca_scanner sc WHERE sc.event_id=e.id) RETURNING id`);return {deleted:r.rowCount};});}
 async function home(u){
  const data=await catalog.discover(u);
  const prefs=extendedProduct&&u?(await preferences(u)).preferences:cleanPreferences({});
  const publicData=u?await catalog.discover(null):data;
  return {signed_in:!!u,events:data.events,hero:publicData.events.slice(0,5),
   communities:(await communities(u)).items,preferences:prefs};
 }
 return {preferences,forgetVisit,follow,communities,saveForm,eventOptions,interest,decide,withdraw,access,visit,management,purge,home};
}
