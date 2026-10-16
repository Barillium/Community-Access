import {extendedProduct,productEventScope} from './product_scope.mjs';
import {assertAccountAction} from './account_policy.mjs';
import {eventPolicy,eventColumns,eventJoins,publicEvent,eventInterest,ownerCurrent,retainedEvent,eventSearch,rankEvents,eventPublication,previewAudiences} from './event_policy.mjs';
export {publicEvent,eventInterest} from './event_policy.mjs';
import {seriesInterest,profileInterest,bookmarkCount} from './interest_counts.mjs';
import {accessWriteLock,activeProfileHost} from './access_policy.mjs';
import {organizerManager,managerCommunities} from './organizer_access.mjs';
import {DirectoryError} from './directory.mjs';
const fail=(status,code)=>{throw new DirectoryError(status,code);};
const uuid=value=>{if(typeof value!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value))fail(404,'NOT_FOUND');return value;};
const text=(value,max,required=false)=>{if(typeof value!=='string'||value.length>max||(required&&!value.trim()))fail(422,'INVALID_FIELDS');return value.trim();};
const boolean=value=>{if(typeof value!=='boolean')fail(422,'INVALID_FIELDS');return value;};
const verified=user=>{if(!user)fail(401,'UNAUTHENTICATED');if(!user.emailVerified)fail(403,'VERIFY_EMAIL');};
const rules=eventPolicy();
const {profile:profileVisible,series:seriesVisible}=rules;
export const personalEvent=`(${retainedEvent} AND ${rules.personal})`;
const joins=eventJoins;
export function createCatalog(pool){
 function searchPage(params){
  const q=text(params?.get('q')??'',180),page=Number(params?.get('page')??'1');
  if(!Number.isInteger(page)||page<1||page>10000)fail(422,'INVALID_PAGE');return {q,page};
 }
 async function discover(user,params=null){
  const {q,page}=searchPage(params);
  if(!extendedProduct){
   const rows=(await pool.query(`WITH visible_events AS (SELECT ${eventColumns(rules)} ${joins} WHERE ${rules.upcoming}) SELECT * FROM visible_events WHERE ${eventSearch()} ORDER BY starts_at ASC NULLS LAST,id LIMIT 21 OFFSET $3`,[user?.id??null,q,params?(page-1)*20:0])).rows;
   return {events:rows.slice(0,20),series:[],page,has_more:!!params&&rows.length>20,signed_in:!!user};
  }
  const rows=(await pool.query(`WITH visible_events AS (SELECT ${eventColumns(rules)},
   EXISTS(SELECT 1 FROM ca_bookmark b WHERE b.user_id=$1 AND (b.event_id=e.id
    OR (${rules.profile} AND b.profile_id=p.id) OR (${rules.profile} AND ${rules.series} AND b.series_id=s.id))) AS bookmarked,
   (c.is_public AND EXISTS(SELECT 1 FROM ca_community_follow f WHERE f.user_id=$1 AND f.community_id=c.id)) AS followed,
   (${rules.profile} AND EXISTS(SELECT 1 FROM ca_organizer_visit v WHERE v.user_id=$1 AND v.profile_id=p.id)) AS visited
   ${joins} WHERE ${rules.upcoming}) SELECT * FROM visible_events WHERE ${eventSearch()}`,[user?.id??null,q])).rows;
  const preferences=extendedProduct&&user?(await pool.query('SELECT preferences FROM ca_guest_preferences WHERE user_id=$1',[user.id])).rows[0]?.preferences??{}:{};
  const events=rankEvents(rows,preferences,extendedProduct&&!!user);
  return {events:params?events.slice((page-1)*20,page*20):events,series:[],page,
   has_more:!!params&&events.length>page*20,signed_in:!!user};
 }
 async function publicEvents(params,user=null){
  const scope=params.get('scope')??'public';
  if(scope==='upcoming')return discover(user,params);
  if(scope!=='public')fail(422,'INVALID_QUERY');
  const {q,page}=searchPage(params);
  const rows=(await pool.query(`WITH visible_events AS (SELECT ${eventColumns(rules)}
   ${joins} WHERE ${publicEvent} AND ${rules.visible})
   SELECT id,title,status,starts_at,request_deadline_at,location,community,communities,ticket_price_cents,access_mode,is_public,ticket_mode,organizer_id,organizer,interest_count
   FROM visible_events WHERE ${eventSearch()}
   ORDER BY starts_at DESC NULLS LAST,id LIMIT 21 OFFSET $3`,[null,q,(page-1)*20])).rows;
  return {events:rows.slice(0,20),series:[],page,has_more:rows.length>20};
 }
 async function transaction(work){const db=await pool.connect();try{await db.query('BEGIN');await db.query(accessWriteLock);await assertAccountAction(db);const out=await work(db);await db.query('COMMIT');return out;}catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}}
 async function owner(db,user,profileId=null){
  verified(user);
  if(!(await db.query(managerCommunities(),[user.id])).rowCount)fail(403,'HOST_REQUIRED');
  const rows=(await db.query(`SELECT p.* FROM ca_organizer p WHERE ${organizerManager()} AND ${activeProfileHost} AND ($2::uuid IS NULL OR id=$2) ORDER BY id FOR UPDATE`,[user.id,profileId?uuid(profileId):null])).rows;
  if(profileId&&!rows.length)fail(404,'NOT_FOUND');
  if(rows.length!==1)fail(409,'PROFILE_REQUIRED');
  const roles=(await db.query('SELECT community_id FROM ca_host WHERE user_id=$1 FOR SHARE',[rows[0].owner_id])).rows.map(r=>r.community_id);
  if(!roles.length)fail(403,'HOST_REQUIRED');return {p:rows[0],roles};
 }
 async function responsible(db,p,roles,community){if(!(await db.query('SELECT 1 FROM ca_community_publisher WHERE profile_id=$1 AND community_id=$2 AND enabled',[p.id,community])).rowCount)fail(403,'COMMUNITY_DENIED');if(!roles.includes(community)||!(await db.query('SELECT 1 FROM ca_profile_community WHERE profile_id=$1 AND community_id=$2',[p.id,community])).rowCount)fail(403,'COMMUNITY_DENIED');}
 async function seriesOwner(db,user,id){
  verified(user);const s=(await db.query('SELECT * FROM ca_series WHERE id=$1',[uuid(id)])).rows[0];if(!s)fail(404,'NOT_FOUND');
  const {p,roles}=await owner(db,user,s.profile_id);if(!roles.includes(s.community_id))fail(404,'NOT_FOUND');
  return (await db.query('SELECT * FROM ca_series WHERE id=$1 FOR UPDATE',[s.id])).rows[0];
 }
 async function eventOwner(db,user,id){
  verified(user);const e=(await db.query('SELECT * FROM ca_event WHERE id=$1',[uuid(id)])).rows[0];if(!e)fail(404,'NOT_FOUND');
  const {p,roles}=await owner(db,user,e.profile_id);if(p.id!==e.profile_id||!roles.includes(e.community_id))fail(404,'NOT_FOUND');
  return (await db.query('SELECT * FROM ca_event WHERE id=$1 FOR UPDATE',[e.id])).rows[0];
 }
 async function program(id,user,page=1,seriesId=null){
  page=Number(page);if(!Number.isInteger(page)||page<1||page>10000)fail(422,'INVALID_PAGE');
  const params=[user?.id??null,uuid(id)];
  const p=(await pool.query(`SELECT p.id FROM ca_organizer p WHERE p.id=$2 AND ${profileVisible} AND ${activeProfileHost}`,params)).rows[0];if(!p)fail(404,'NOT_FOUND');
  const series=!extendedProduct?[]:(await pool.query(`SELECT s.id,s.title,s.description,${seriesInterest} AS interest_count FROM ca_series s JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_community c ON c.id=s.community_id
   WHERE s.profile_id=$2 AND ${profileVisible} AND ${ownerCurrent} AND ${seriesVisible} AND ($3::uuid IS NULL OR s.id=$3) ORDER BY s.title,s.id LIMIT 21 OFFSET $4`,[...params,seriesId,(page-1)*20])).rows;
  const events=(await pool.query(`SELECT ${eventColumns(rules,{content:false})}
   ${joins} WHERE e.profile_id=$2 AND ${rules.visible} AND ($3::uuid IS NULL OR e.series_id=$3)
   ORDER BY ${rules.order} LIMIT 21 OFFSET $4`,[...params,seriesId,(page-1)*20])).rows;
  return {series:series.slice(0,20),events:events.slice(0,20),page,has_more:series.length>20||events.length>20};
 }
 async function eventDetail(id,user,db=pool){
  const e=(await db.query(`SELECT ${eventColumns(rules)} ${joins}
   WHERE e.id=$2 AND ${rules.visible}`,[user?.id??null,uuid(id)])).rows[0];
  if(!e)fail(404,'NOT_FOUND');return {...e,signed_in:!!user};
 }
 async function seriesDetail(id,user,page=1){if(!extendedProduct)fail(404,'NOT_FOUND');const s=(await pool.query(`SELECT s.id,s.profile_id,s.title,s.description,${seriesInterest} AS interest_count FROM ca_series s JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_community c ON c.id=s.community_id
   WHERE s.id=$2 AND ${profileVisible} AND ${ownerCurrent} AND ${seriesVisible}`,[user?.id??null,uuid(id)])).rows[0];if(!s)fail(404,'NOT_FOUND');const contents=await program(s.profile_id,user,page,s.id);return {id:s.id,title:s.title,description:s.description,interest_count:s.interest_count,signed_in:!!user,events:contents.events,page:contents.page,has_more:contents.has_more};}
 async function saveSeries(user,body){if(!extendedProduct)fail(404,'NOT_FOUND');return transaction(async db=>{const stored=body.id?(await db.query('SELECT profile_id FROM ca_series WHERE id=$1',[uuid(body.id)])).rows[0]:null;
  const {p,roles}=await owner(db,user,body.profile_id??stored?.profile_id);await responsible(db,p,roles,body.community_id);
  if(body.is_public&&!p.is_public)fail(422,'PUBLIC_PROFILE_REQUIRED');
  const existing=body.id?(await db.query('SELECT * FROM ca_series WHERE id=$1 FOR UPDATE',[uuid(body.id)])).rows[0]:null;
  if(body.id&&(!existing||existing.profile_id!==p.id||!roles.includes(existing.community_id)))fail(404,'NOT_FOUND');
  if(existing&&body.version!==existing.version)fail(409,'CATALOG_CHANGED');
  if(existing&&body.community_id!==existing.community_id&&(await db.query('SELECT 1 FROM ca_event WHERE series_id=$1 LIMIT 1',[existing.id])).rowCount)fail(409,'SERIES_COMMUNITY_LOCKED');
  const args=[text(body.title,180,true),text(body.description,4000),body.community_id,boolean(body.is_public),p.id];
  const result=existing?await db.query('UPDATE ca_series SET title=$1,description=$2,community_id=$3,is_public=$4,version=version+1 WHERE id=$6 AND profile_id=$5 RETURNING id,version',[...args,existing.id]):
   await db.query('INSERT INTO ca_series(title,description,community_id,is_public,profile_id) VALUES($1,$2,$3,$4,$5) RETURNING id,version',args);return result.rows[0];});}
 async function validateEvent(db,user,body,roles){
  const stored=body.id?(await db.query('SELECT profile_id,access_mode,is_public FROM ca_event WHERE id=$1',[uuid(body.id)])).rows[0]:null;
  const {p,roles:profileRoles}=await owner(db,user,body.profile_id??stored?.profile_id);
  const publication=eventPublication(body,stored);if(!publication)fail(422,'INVALID_FIELDS');
  if(publication.isPublic&&!p.is_public&&publication.mode!=='semi_public')fail(422,'PUBLIC_PROFILE_REQUIRED');
  await responsible(db,p,profileRoles,body.community_id);
  const seriesId=body.series_id??null;
  if(!extendedProduct&&seriesId)fail(404,'NOT_FOUND');
  if(seriesId){const s=(await db.query('SELECT * FROM ca_series WHERE id=$1 FOR UPDATE',[uuid(seriesId)])).rows[0];if(!s||s.profile_id!==p.id||s.community_id!==body.community_id)fail(403,'COMMUNITY_DENIED');}
  return {profile:p.id,series:seriesId,publication};
 }
 async function grant(user,body){if(!extendedProduct&&body.kind!=='event')fail(404,'NOT_FOUND');return transaction(async db=>{
  const type=body.kind;if(!['series','event'].includes(type))fail(422,'INVALID_FIELDS');
  const scope=type==='series'?await seriesOwner(db,user,body.id):await eventOwner(db,user,body.id);
  const recipient=(await db.query('SELECT id FROM "user" WHERE email=$1 AND "emailVerified"=true',[text(body.email,255,true).toLowerCase()])).rows[0];if(!recipient||recipient.id===user.id)fail(422,'INVALID_RECIPIENT');
  const table=type==='series'?'ca_series_grant':'ca_event_grant',column=type==='series'?'series_id':'event_id';
  const existing=(await db.query(`SELECT * FROM ${table} WHERE ${column}=$1 AND user_id=$2 FOR UPDATE`,[scope.id,recipient.id])).rows[0];
  if(existing&&body.version!==existing.version)fail(409,'CATALOG_CHANGED');
  const r=(await db.query(`INSERT INTO ${table}(${column},user_id,active) VALUES($1,$2,true) ON CONFLICT(${column},user_id) DO UPDATE SET active=true,version=${table}.version+1 RETURNING id,version`,[scope.id,recipient.id])).rows[0];if(type==='event'){const blocked=(await db.query('SELECT status FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2 FOR UPDATE',[scope.profile_id,recipient.id])).rows[0];if(blocked?.status==='revoked')fail(403,'ACCESS_BLOCKED');/* An event grant grants only this event. The revoked-profile check above remains enforced. */}return r;
 });}
 async function revoke(user,body){return transaction(async db=>{
  const type=body.kind;if(!['series','event'].includes(type))fail(422,'INVALID_FIELDS');
  const table=type==='series'?'ca_series_grant':'ca_event_grant',column=type==='series'?'series_id':'event_id';
  const r=(await db.query(`SELECT * FROM ${table} WHERE id=$1`,[uuid(body.id)])).rows[0];if(!r)fail(404,'NOT_FOUND');
  if(type==='series')await seriesOwner(db,user,r[column]);else await eventOwner(db,user,r[column]);
  const changed=(await db.query(`UPDATE ${table} SET active=false,version=version+1 WHERE id=$1 AND version=$2 AND active RETURNING id,version`,[r.id,body.version])).rows[0];if(!changed)fail(409,'CATALOG_CHANGED');return changed;
 });}
 async function management(user,profileId=null){verified(user);return {
  series:!extendedProduct?[]:(await pool.query(`SELECT s.* FROM ca_series s JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_host h ON h.community_id=s.community_id AND h.user_id=p.owner_id WHERE ${organizerManager()} AND ($2::uuid IS NULL OR p.id=$2) ORDER BY s.title,s.id`,[user.id,profileId])).rows,
  grants:(await pool.query(`SELECT g.id,'series' AS kind,s.id AS scope_id,s.title,u.name AS guest,u.email,g.active,g.version FROM ca_series_grant g JOIN ca_series s ON s.id=g.series_id JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_host h ON h.community_id=s.community_id AND h.user_id=p.owner_id JOIN "user" u ON u.id=g.user_id WHERE ${extendedProduct?'TRUE':'FALSE'} AND ${organizerManager()} AND ($2::uuid IS NULL OR p.id=$2)
   UNION ALL SELECT g.id,'event',e.id,e.title,u.name,u.email,g.active,g.version FROM ca_event_grant g JOIN ca_event e ON e.id=g.event_id JOIN ca_organizer p ON p.id=e.profile_id JOIN ca_host h ON h.community_id=e.community_id AND h.user_id=p.owner_id JOIN "user" u ON u.id=g.user_id WHERE ${productEventScope} AND ${organizerManager()} AND ($2::uuid IS NULL OR p.id=$2) ORDER BY title,id`,[user.id,profileId])).rows};}

 async function preview(user,body){
  if(!previewAudiences.includes(body.audience))fail(422,'INVALID_FIELDS');
  return transaction(async db=>{
   const event=await eventOwner(db,user,body.id),previewRules=eventPolicy(body.audience);
   const row=(await db.query(`SELECT ${previewRules.visible} AS visible,${eventColumns(previewRules,{guard:true})},
    (${previewRules.exactLocation}
     AND EXISTS(SELECT 1 FROM ca_event_location l WHERE l.event_id=e.id)) AS exact_location_available
    ${joins} WHERE e.id=$2 AND ${organizerManager()}`,[user.id,event.id])).rows[0];
   return {...row,audience:body.audience,participation_available:true};
  });
 }
 async function bookmarks(user){
  verified(user);
  const profiles=(await pool.query(`SELECT p.id,p.display_name AS title FROM ca_bookmark b JOIN ca_organizer p ON p.id=b.profile_id
   WHERE b.user_id=$1 AND ${profileVisible} AND ${activeProfileHost} ORDER BY p.display_name,p.id`,[user.id])).rows;
  const series=(await pool.query(`SELECT s.id,s.title FROM ca_bookmark b JOIN ca_series s ON s.id=b.series_id JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_community c ON c.id=s.community_id
   WHERE b.user_id=$1 AND ${profileVisible} AND ${ownerCurrent} AND ${seriesVisible} ORDER BY s.title,s.id`,[user.id])).rows;
  const events=(await pool.query(`SELECT ${eventColumns(rules,{content:false})} FROM ca_bookmark b
   JOIN ca_event e ON e.id=b.event_id JOIN ca_community c ON c.id=e.community_id
   LEFT JOIN ca_organizer p ON p.id=e.profile_id LEFT JOIN ca_series s ON s.id=e.series_id
   WHERE b.user_id=$1 AND ${rules.visible} ORDER BY e.title,e.id`,[user.id])).rows;
  return {profiles,series,events};
 }
 async function bookmark(user,body){
  verified(user);if(!['profile','series','event'].includes(body.kind)||typeof body.saved!=='boolean')fail(422,'INVALID_FIELDS');
  const id=uuid(body.id),column={profile:'profile_id',series:'series_id',event:'event_id'}[body.kind];
  if(!body.saved){await transaction(db=>db.query(`DELETE FROM ca_bookmark WHERE user_id=$1 AND ${column}=$2`,[user.id,id]));return {saved:false,interest_count:await interestCount(body.kind,id)};}
  if(body.kind==='event')await eventDetail(id,user);
  else if(body.kind==='series')await seriesDetail(id,user);
  else if(!(await pool.query(`SELECT p.id FROM ca_organizer p WHERE p.id=$2 AND ${profileVisible} AND ${activeProfileHost}`,[user.id,id])).rowCount)fail(404,'NOT_FOUND');
  await transaction(db=>db.query(`INSERT INTO ca_bookmark(user_id,${column}) VALUES($1,$2) ON CONFLICT DO NOTHING`,[user.id,id]));return {saved:true,interest_count:await interestCount(body.kind,id)};
 }
 async function interestCount(kind,id){
  const sql=kind==='profile'?`SELECT ${profileInterest} AS count FROM ca_organizer p WHERE p.id=$1 AND ${activeProfileHost}`:
   kind==='series'?`SELECT ${seriesInterest} AS count FROM ca_series s JOIN ca_organizer p ON p.id=s.profile_id JOIN ca_community c ON c.id=s.community_id WHERE s.id=$1`:
   `SELECT ${eventInterest} AS count ${joins} WHERE e.id=$1`;
  return (await pool.query(sql,[id])).rows[0]?.count??null;
 }
 return {publicEvents,discover,program,eventDetail,seriesDetail,saveSeries,validateEvent,grant,revoke,management,preview,bookmarks,bookmark};
}
