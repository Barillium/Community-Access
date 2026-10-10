import {DirectoryError} from './directory.mjs';
import {createPrivateAccess} from './private_access.mjs';
import {organizerManager} from './organizer_access.mjs';
import {activeProfileHost} from './access_policy.mjs';
export const legalTermsVersion='local-responsibility-draft-20261009';
const fail=(s,c)=>{throw new DirectoryError(s,c);};
const uuid=v=>{if(typeof v!=='string'||!/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(v))fail(422,'INVALID_FIELDS');return v;};
const text=(v,n)=>{if(typeof v!=='string'||!v.trim()||v.length>n||/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(v))fail(422,'INVALID_FIELDS');return v.trim();};
const fields=(b,keys)=>{if(!b||typeof b!=='object'||Array.isArray(b)||Object.keys(b).some(k=>!keys.includes(k)))fail(422,'INVALID_FIELDS');};
const verified=u=>{if(!u)fail(401,'UNAUTHENTICATED');if(!u.emailVerified)fail(403,'VERIFY_EMAIL');};
export const legalReadySQL=`EXISTS(SELECT 1 FROM ca_ticket_seller ls JOIN ca_event_declaration ld ON ld.event_id=e.id
 WHERE ls.profile_id=e.profile_id AND ld.version=(SELECT MAX(version) FROM ca_event_declaration WHERE event_id=e.id)
 AND ld.terms_version='${legalTermsVersion}' AND ld.confirmed AND ld.event_version=e.version AND ld.seller_version=ls.version)`;
export async function legalSnapshot(db,eventId){
 const seller=(await db.query('SELECT legal_name,address,contact,seller_status,version FROM ca_ticket_seller WHERE profile_id=(SELECT profile_id FROM ca_event WHERE id=$1)',[eventId])).rows[0]??null;
 const declaration=(await db.query('SELECT version,event_version,seller_version,confirmed,terms_version,created_at FROM ca_event_declaration WHERE event_id=$1 ORDER BY version DESC LIMIT 1',[eventId])).rows[0]??null;
 return {seller,declaration};
}
export function createLegal(pool){
 const access=createPrivateAccess(pool);
 async function team(db,u){verified(u);if(!(await db.query('SELECT 1 FROM ca_team WHERE user_id=$1',[u.id])).rowCount)fail(403,'TEAM_REQUIRED');}
 async function profile(db,u,pid,owner=false){verified(u);const p=(await db.query(`SELECT p.* FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()} AND ${activeProfileHost}`,[u.id,uuid(pid)])).rows[0];if(!p)fail(404,'NOT_FOUND');if(owner&&p.owner_id!==u.id)fail(403,'OWNER_REQUIRED');return p;}
 async function seller(u,pid,b){return access.tx(u,async db=>{
  const p=await profile(db,u,pid,b!==undefined);const old=(await db.query('SELECT legal_name,address,contact,seller_status,version FROM ca_ticket_seller WHERE profile_id=$1',[pid])).rows[0];
  if(b!==undefined){fields(b,['legal_name','address','contact','seller_status','version']);if(b.version!==(old?.version??0))fail(409,'SELLER_CHANGED');if(!['private','business'].includes(b.seller_status))fail(422,'INVALID_FIELDS');
   const name=text(b.legal_name,200),address=text(b.address,500),contact=text(b.contact,255).toLowerCase();if(!/^[^\s@]+@[^\s@]+\.example\.invalid$/.test(contact)&&!/^([^\s@]+)@example\.invalid$/.test(contact))fail(422,'SYNTHETIC_EMAIL_REQUIRED');
   await db.query(`INSERT INTO ca_ticket_seller(profile_id,legal_name,address,contact,seller_status,updated_by) VALUES($1,$2,$3,$4,$5,$6)
    ON CONFLICT(profile_id) DO UPDATE SET legal_name=$2,address=$3,contact=$4,seller_status=$5,updated_by=$6,version=ca_ticket_seller.version+1,updated_at=NOW()`,[pid,name,address,contact,b.seller_status,u.id]);
  }
  return {seller:(await db.query('SELECT legal_name,address,contact,seller_status,version FROM ca_ticket_seller WHERE profile_id=$1',[pid])).rows[0]??null,can_edit:p.owner_id===u.id,synthetic:true};
 });}
 async function declaration(u,eid,b){return access.tx(u,async db=>{
  const e=await access.owner(db,u,uuid(eid));const s=(await db.query('SELECT version FROM ca_ticket_seller WHERE profile_id=$1',[e.profile_id])).rows[0];
  const old=(await db.query('SELECT * FROM ca_event_declaration WHERE event_id=$1 ORDER BY version DESC LIMIT 1',[eid])).rows[0];
  if(b!==undefined){fields(b,['confirmed','version','event_version','seller_version','terms_version']);if(typeof b.confirmed!=='boolean')fail(422,'INVALID_FIELDS');if(b.terms_version!==legalTermsVersion||b.version!==(old?.version??0)||b.event_version!==e.version||b.seller_version!==(s?.version??0))fail(409,'DECLARATION_CHANGED');if(b.confirmed&&!s)fail(409,'SELLER_REQUIRED');
   await db.query('INSERT INTO ca_event_declaration(event_id,version,event_version,seller_version,confirmed,terms_version,actor_id) VALUES($1,$2,$3,$4,$5,$6,$7)',[eid,(old?.version??0)+1,e.version,s?.version??0,b.confirmed,legalTermsVersion,u.id]);
  }
  const snapshot=await legalSnapshot(db,eid);return {...snapshot,terms_version:legalTermsVersion,ready:snapshot.declaration?.terms_version===legalTermsVersion&&!!snapshot.declaration?.confirmed&&snapshot.declaration.event_version===e.version&&snapshot.declaration.seller_version===s?.version,event_version:e.version,seller_version:s?.version??0,legal_state:e.legal_state,legal_version:e.legal_version,synthetic:true};
 });}
 async function notice(db,email,kind,report,message){if(email)await db.query('INSERT INTO ca_legal_notice(recipient,kind,report_id,message) VALUES($1,$2,$3,$4)',[email,kind,report,message]);}
 async function submit(b){
  fields(b,['event_id','reference','details','name','email','good_faith','contact_exception']);if(b.good_faith!==true||b.contact_exception!==undefined&&typeof b.contact_exception!=='boolean')fail(422,'INVALID_FIELDS');
  const eid=b.event_id?uuid(b.event_id):null,reference=text(b.reference,500),details=text(b.details,4000);
  // Never dereference submitted URLs or disclose whether a private event exists.
  if(/[?#]/.test(reference)||/invite|invitation|token|profile_link/i.test(reference))fail(422,'PRIVATE_LINK_DENIED');
  const exception=b.contact_exception===true;
  const name=exception&&!b.name?'':text(b.name,200),email=exception&&!b.email?'':text(b.email,255).toLowerCase();
  if(email&&!/^[^\s@]+@example\.invalid$/.test(email))fail(422,'SYNTHETIC_EMAIL_REQUIRED');
  const db=await pool.connect();try{await db.query('BEGIN');const r=(await db.query('INSERT INTO ca_legal_report(event_id,reference,details,reporter_name,reporter_email,contact_exception) VALUES($1,$2,$3,$4,$5,$6) RETURNING id',[eid,reference,details,name,email,exception])).rows[0];
   await notice(db,email,'received',r.id,'Deine Meldung wurde empfangen. Sie wird vom Plattformteam geprüft.');await db.query('COMMIT');return {received:true,reference:r.id,synthetic:true};
  }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
 }
 async function reportRead(u,rid,db=pool){await team(db,u);const r=(await db.query('SELECT * FROM ca_legal_report WHERE id=$1',[uuid(rid)])).rows[0];if(!r)fail(404,'NOT_FOUND');return {...r,event:r.event_id?(await db.query('SELECT id,title,legal_state,legal_version FROM ca_event WHERE id=$1',[r.event_id])).rows[0]??null:null,actions:(await db.query('SELECT * FROM ca_legal_action WHERE report_id=$1 ORDER BY created_at,id',[rid])).rows,statements:(await db.query('SELECT s.* FROM ca_legal_statement s JOIN ca_legal_action a ON a.id=s.action_id WHERE a.report_id=$1 ORDER BY s.created_at',[rid])).rows};}
 async function assign(u,rid,b){return access.tx(u,async db=>{fields(b,['version']);await reportRead(u,rid,db);const r=(await db.query('UPDATE ca_legal_report SET assigned_to=$2,version=version+1 WHERE id=$1 AND version=$3 RETURNING id,version',[rid,u.id,b.version])).rows[0];if(!r)fail(409,'REVIEW_CHANGED');return r;});}
 async function decide(u,rid,b){return access.tx(u,async db=>{
  fields(b,['event_id','action','basis','reason','version','event_legal_version']);const report=await reportRead(u,rid,db);if(report.version!==b.version||report.assigned_to!==u.id)fail(409,'REVIEW_CHANGED');
  if(b.action==='no_action'){
   if(b.basis!=='unsubstantiated')fail(422,'INVALID_FIELDS');const reason=text(b.reason,2000);
   if(report.event_id&&b.event_id&&report.event_id!==b.event_id)fail(422,'EVENT_MISMATCH');const targetId=report.event_id??(b.event_id?uuid(b.event_id):null);
   const e=targetId?(await db.query('SELECT e.id,e.profile_id,p.owner_id FROM ca_event e JOIN ca_organizer p ON p.id=e.profile_id WHERE e.id=$1',[targetId])).rows[0]:null;
   if(e&&(e.owner_id===u.id||(await db.query("SELECT 1 FROM ca_organizer_member WHERE profile_id=$1 AND user_id=$2 AND status='active' AND accepted_at IS NOT NULL",[e.profile_id,u.id])).rowCount))fail(403,'INDEPENDENT_REVIEW_REQUIRED');
   const a=(await db.query("INSERT INTO ca_legal_action(report_id,event_id,profile_id,actor_id,action,basis,reason) VALUES($1,$2,$3,$4,'no_action','unsubstantiated',$5) RETURNING id",[rid,e?.id??null,e?.profile_id??null,u.id,reason])).rows[0];
   await db.query("UPDATE ca_legal_report SET status='decided',version=version+1 WHERE id=$1",[rid]);
   await notice(db,report.reporter_email,'decision',rid,`Keine Maßnahme. ${reason}. Du kannst über Hilfe & Kontakt eine erneute Prüfung anfordern.`);
   await access.audit(db,u,'legal_no_action',rid);return {id:a.id,action:'no_action'};
  }
  const e=(await db.query('SELECT e.*,p.owner_id FROM ca_event e JOIN ca_organizer p ON p.id=e.profile_id WHERE e.id=$1 FOR UPDATE OF e',[uuid(b.event_id)])).rows[0];if(!e)fail(404,'NOT_FOUND');if(report.event_id&&report.event_id!==e.id)fail(422,'EVENT_MISMATCH');
  if(e.owner_id===u.id||(await db.query("SELECT 1 FROM ca_organizer_member WHERE profile_id=$1 AND user_id=$2 AND status='active' AND accepted_at IS NOT NULL",[e.profile_id,u.id])).rowCount)fail(403,'INDEPENDENT_REVIEW_REQUIRED');
  if(e.legal_version!==b.event_legal_version)fail(409,'REVIEW_CHANGED');
  const combinations={sales_paused:['clarification'],blocked:['prohibition','danger','cancellation'],active:['resolved']};if(!combinations[b.action]?.includes(b.basis))fail(422,'INVALID_FIELDS');const reason=text(b.reason,2000);
  await db.query('UPDATE ca_event SET legal_state=$2,legal_version=legal_version+1 WHERE id=$1',[e.id,b.action]);
  if(b.action!=='active'){
   await db.query("UPDATE ca_ticket_order SET blocked=true,legal_stopped=true,admission_state='admission_hold' WHERE event_id=$1 AND (state IN('creating','pending') OR $2='blocked' AND state='paid')",[e.id,b.action]);
   if(b.action==='blocked')await db.query("INSERT INTO ca_ticket_refund(order_id,reason) SELECT id,'legal_event_block' FROM ca_ticket_order WHERE event_id=$1 AND state='paid' AND refunded_cents<total_cents ON CONFLICT(order_id) WHERE state IN('review','processing') DO NOTHING",[e.id]);
  }
  const a=(await db.query('INSERT INTO ca_legal_action(report_id,event_id,profile_id,actor_id,action,basis,reason) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id',[rid,e.id,e.profile_id,u.id,b.action,b.basis,reason])).rows[0];
  await db.query("UPDATE ca_legal_report SET status='decided',version=version+1,event_id=$2 WHERE id=$1",[rid,e.id]);
  await notice(db,report.reporter_email,'decision',rid,`Entscheidung: ${b.action}. ${reason}. Du kannst über Hilfe & Kontakt eine erneute Prüfung anfordern.`);
  const email=(await db.query('SELECT email FROM "user" WHERE id=$1',[e.owner_id])).rows[0]?.email;
  await notice(db,email,'organizer_decision',rid,`Entscheidung: ${b.action}. Grundlage: ${b.basis}. ${reason}. Eine erneute Prüfung ist in der Veranstalteransicht möglich.`);
  await access.audit(db,u,'legal_'+b.action,e.id);return {id:a.id,legal_state:b.action,legal_version:e.legal_version+1};
 });}
 async function ownActions(u){verified(u);return {items:(await pool.query(`SELECT a.id,a.event_id,a.profile_id,a.action,a.basis,a.reason,a.created_at,EXISTS(SELECT 1 FROM ca_legal_statement s WHERE s.action_id=a.id AND s.actor_id=$1) AS statement_submitted FROM ca_legal_action a JOIN ca_organizer p ON p.id=a.profile_id WHERE ${organizerManager()} AND ${activeProfileHost} ORDER BY a.created_at DESC`,[u.id])).rows};}
 async function statement(u,aid,b){return access.tx(u,async db=>{fields(b,['details']);const a=(await db.query('SELECT * FROM ca_legal_action WHERE id=$1',[uuid(aid)])).rows[0];if(!a)fail(404,'NOT_FOUND');await profile(db,u,a.profile_id);const details=text(b.details,4000);const existing=(await db.query('SELECT details FROM ca_legal_statement WHERE action_id=$1 AND actor_id=$2',[aid,u.id])).rows[0];if(existing){if(existing.details!==details)fail(409,'STATEMENT_EXISTS');return {submitted:true};}await db.query('INSERT INTO ca_legal_statement(action_id,actor_id,details) VALUES($1,$2,$3) ON CONFLICT(action_id,actor_id) DO NOTHING',[aid,u.id,details]);await db.query("UPDATE ca_legal_report SET status='open',version=version+1 WHERE id=$1",[a.report_id]);return {submitted:true};});}
 async function route(u,path,method,b){
  if(path==='reports'&&method==='POST')return submit(b);
  verified(u);
  if(path==='mine'&&method==='GET')return ownActions(u);
  if(path==='reports'&&method==='GET'){await team(pool,u);return {items:(await pool.query('SELECT id,event_id,reference,status,assigned_to,version,created_at FROM ca_legal_report ORDER BY created_at DESC LIMIT 100')).rows};}
  if(path==='mailbox'&&method==='GET'){await team(pool,u);return {items:(await pool.query('SELECT recipient,kind,report_id,message,synthetic FROM ca_legal_notice ORDER BY created_at DESC LIMIT 100')).rows,synthetic:true};}
  const em=/^events\/([a-f0-9-]{36})$/.exec(path);if(em&&method==='GET'){await team(pool,u);const e=(await pool.query('SELECT id,title,legal_state,legal_version FROM ca_event WHERE id=$1',[uuid(em[1])])).rows[0];if(!e)fail(404,'NOT_FOUND');return e;}
  const m=/^reports\/([a-f0-9-]{36})(?:\/(assign|decision))?$/.exec(path);
  if(m&&method==='GET'&&!m[2])return reportRead(u,m[1]);
  if(m&&method==='POST'&&m[2]==='assign')return assign(u,m[1],b);
  if(m&&method==='POST'&&m[2]==='decision')return decide(u,m[1],b);
  const a=/^actions\/([a-f0-9-]{36})\/statement$/.exec(path);if(a&&method==='POST')return statement(u,a[1],b);
  fail(404,'NOT_FOUND');
 }
 return {route,seller,declaration};
}
