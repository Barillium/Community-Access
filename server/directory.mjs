import {extendedProduct,productEventScope} from './product_scope.mjs';
import {assertAccountAction} from './account_policy.mjs';
import {createPrivateAccess} from './private_access.mjs';
import { randomBytes, createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import {createCatalog,publicEvent,eventInterest} from './catalog.mjs';
import {eventContent} from './event_content.mjs';
import {profileInterest} from './interest_counts.mjs';
import {checkedForm} from './form_policy.mjs';
import {createDiscovery} from './discovery.mjs';
import {retainedEvent} from './discovery_policy.mjs';
import {createAccess} from './access.mjs';
import {migrateAccess} from './access_migrations.mjs';
import {accessWriteLock,activeProfileHost} from './access_policy.mjs';
import {organizerManager,managerCommunities} from './organizer_access.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const idPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export class DirectoryError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
const fail = (status, code) => { throw new DirectoryError(status, code); };
const text = (value, max, required = false) => {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) fail(422, 'INVALID_FIELDS');
  return value.trim();
};
const identifier = value => { if (!idPattern.test(value ?? '')) fail(404, 'NOT_FOUND'); return value; };
const bool = value => { if (typeof value !== 'boolean') fail(422, 'INVALID_FIELDS'); return value; };
const form=checkedForm;
function accessDetails(value){
 if(!value||typeof value!=='object'||Array.isArray(value))fail(422,'INVALID_FIELDS');
 const choices=['step_free','accessible_toilet','seating','quiet_space'];
 const notes=['access_notes','awareness_notes','awareness_contact'];
 if(Object.keys(value).some(k=>![...choices,...notes].includes(k)))fail(422,'INVALID_FIELDS');
 const out={};for(const key of choices){const state=value[key]??'unknown';if(!['unknown','yes','no'].includes(state))fail(422,'INVALID_FIELDS');out[key]=state;}
 for(const key of notes)out[key]=text(value[key]??'',key==='awareness_contact'?240:2000);return out;
}
export async function createDirectory(pool, {migrate=true} = {}) {
  // The caller has already verified a private, local synthetic database socket.
  if (migrate) {
    await pool.query(await readFile(new URL('./directory.sql', import.meta.url), 'utf8'));
    await pool.query(await readFile(new URL('./discovery.sql', import.meta.url), 'utf8'));
    await migrateAccess(pool);
  }
  const catalog=createCatalog(pool);
  const discovery=createDiscovery(pool,catalog);
  const accessFlow=createAccess(pool,catalog);
  await discovery.purge();
  const query = (sql, args = []) => pool.query(sql, args);
  async function transaction(work) {
    const db = await pool.connect();
    try { await db.query('BEGIN'); await db.query(accessWriteLock);await assertAccountAction(db); const result = await work(db); await db.query('COMMIT'); return result; }
    catch (error) { await db.query('ROLLBACK'); throw error; } finally { db.release(); }
  }
  const verified = user => { if (!user) fail(401, 'UNAUTHENTICATED'); if (!user.emailVerified) fail(403, 'VERIFY_EMAIL'); };
  const host = async (db, user) => {
    verified(user);
    // Mutations and member revocation share accessWriteLock. Publication remains profile-scoped.
    const roles = await db.query(`SELECT community_id FROM (${managerCommunities()}) managed`, [user.id]);
    if (!roles.rowCount) fail(403, 'HOST_REQUIRED'); return roles.rows.map(r => r.community_id);
  };
  const visible = `p.is_public OR ${organizerManager()} OR ${extendedProduct?`EXISTS (SELECT 1 FROM ca_profile_request r WHERE r.profile_id=p.id AND r.user_id=$1 AND r.status='approved')`:'false'}`;
  async function communitiesFor(profileId, viewerId, db = pool) {
    return (await db.query(`SELECT c.id,c.name FROM ca_community c JOIN ca_profile_community pc ON pc.community_id=c.id
      JOIN ca_organizer p ON p.id=pc.profile_id JOIN ca_host h ON h.community_id=c.id AND h.user_id=p.owner_id
      WHERE p.id=$1 AND (c.is_public OR ${organizerManager('p','$2')}) ORDER BY c.name,c.id`, [profileId, viewerId])).rows;
  }
  async function projection(p, user) {
    return { id: p.id, name: p.display_name, description: p.description, is_public: p.is_public, awareness_concept:p.awareness_concept, awareness_team:p.awareness_team,
      communities: await communitiesFor(p.id, user?.id ?? null),signed_in:!!user,interest_count:p.interest_count??null };
  }
  async function profile(id, user, db = pool, lock = false) {
    const p = (await db.query(`SELECT p.*,${profileInterest} AS interest_count FROM ca_organizer p WHERE p.id=$1 AND ${activeProfileHost} ${lock ? 'FOR UPDATE' : ''}`, [identifier(id)])).rows[0];
    if (!p || !(await db.query(`SELECT 1 FROM ca_host WHERE user_id=$1 ${lock ? 'FOR SHARE' : ''}`, [p.owner_id])).rowCount) fail(404, 'NOT_FOUND');
    return p;
  }
  async function canSee(p, user) {
    return p.is_public || !!(await query(`SELECT 1 FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()}`,[user?.id??null,p.id])).rowCount || extendedProduct && !!(await query(`SELECT 1 FROM ca_profile_request
      WHERE profile_id=$1 AND user_id=$2 AND status='approved'`, [p.id, user?.id ?? null])).rowCount;
  }
  async function list(params, user) {
    const q = text(params.get('q') ?? '', 180);
    const community = params.get('community') || null;
    if (community) identifier(community);
    const page = Number(params.get('page') ?? '1');
    if (!Number.isInteger(page) || page < 1 || page > 10000) fail(422, 'INVALID_PAGE');
    const result = await query(`SELECT p.*,${profileInterest} AS interest_count FROM ca_organizer p WHERE (${visible})
      AND ${activeProfileHost}
      AND strpos(lower(p.display_name),lower($2))>0
      AND ($3::uuid IS NULL OR EXISTS (SELECT 1 FROM ca_profile_community pc JOIN ca_community c ON c.id=pc.community_id
        JOIN ca_host h ON h.community_id=c.id AND h.user_id=p.owner_id
        WHERE pc.profile_id=p.id AND c.id=$3 AND c.is_public))
      ORDER BY lower(p.display_name),p.id LIMIT 21 OFFSET $4`, [user?.id ?? null,q,community,(page-1)*20]);
    return { items: await Promise.all(result.rows.slice(0,20).map(p => projection(p,user))), page, has_more: result.rows.length>20, signed_in: !!user,
      communities: (await query('SELECT id,name FROM ca_community WHERE is_public ORDER BY name,id')).rows };
  }
  async function venues(params) {
    const q = text(params.get('q') ?? '',180);
    const page = Number(params.get('page') ?? '1');
    if (!Number.isInteger(page) || page<1 || page>10000) fail(422,'INVALID_PAGE');
    const items = (await query(`SELECT e.public_location AS name,count(*)::int AS event_count
      FROM ca_event e JOIN ca_community c ON c.id=e.community_id LEFT JOIN ca_organizer p ON p.id=e.profile_id LEFT JOIN ca_series s ON s.id=e.series_id WHERE ${publicEvent}
      AND e.status IN ('published','cancelled') AND e.access_mode<>'semi_public' AND ${retainedEvent} AND e.location_public AND trim(e.public_location)<>''
      AND strpos(lower(e.public_location),lower($1))>0 GROUP BY e.public_location ORDER BY e.public_location
      LIMIT 21 OFFSET $2`, [q,(page-1)*20])).rows;
    return { items: items.slice(0,20), page, has_more: items.length>20 };
  }
  async function venueEvents(params) {
    const name = text(params.get('name') ?? '',240,true);
    const items = (await query(`SELECT e.id,e.title,e.status,${eventInterest} AS interest_count,CASE WHEN e.starts_public THEN e.starts_at END AS starts_at,
      c.name AS community FROM ca_event e JOIN ca_community c ON c.id=e.community_id LEFT JOIN ca_organizer p ON p.id=e.profile_id LEFT JOIN ca_series s ON s.id=e.series_id
      WHERE ${publicEvent} AND e.status IN ('published','cancelled') AND e.access_mode<>'semi_public' AND ${retainedEvent} AND e.location_public
      AND e.public_location=$1 ORDER BY CASE WHEN e.starts_public THEN e.starts_at END DESC NULLS LAST,e.id LIMIT 100`, [name])).rows;
    if (!items.length) fail(404,'NOT_FOUND'); return { name, events: items };
  }
  async function access(id,user) {
    const p = await profile(id,user);
    if(!extendedProduct){if(!await canSee(p,user))fail(404,'NOT_FOUND');return {id:p.id,name:p.display_name,signed_in:!!user,allow_application:false,allow_form:false,allow_link:false,form:[],version:null,request:null};}
    if (!p.is_public && !user) fail(404,'NOT_FOUND');
    if (!user) return {id:p.id,name:p.display_name,signed_in:false,allow_application:false,allow_form:false,allow_link:false,form:[],version:null,request:null};
    if (!(p.allow_application || p.allow_form || p.allow_link) && !await canSee(p,user)) fail(404,'NOT_FOUND');
    return { id:p.id,name:await canSee(p,user)?p.display_name:'Profilzugang',signed_in:!!user,allow_application:p.allow_application,allow_form:p.allow_form,
      allow_link:p.allow_link,form:p.allow_form?form(p.form):[],version:p.form_version,
      request: user ? (await query('SELECT id,status FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[p.id,user.id])).rows[0]??null:null };
  }
  async function apply(id,user,body) {
    if(!extendedProduct)fail(404,'NOT_FOUND');
    verified(user);
    return transaction(async db => {
      const p=await profile(id,user,db,true);
      if ((await db.query(`SELECT 1 FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()}`,[user.id,p.id])).rowCount) fail(409,'OWN_PROFILE');
      const method=body.method;
      if (!(method==='application'&&p.allow_application || method==='form'&&p.allow_form)) fail(403,'ACCESS_DISABLED');
      if (body.version!==p.form_version) fail(409,'FORM_CHANGED');
      const fields=method==='form'?form(p.form):[];
      const answers=body.answers;
      if (!answers || typeof answers!=='object' || Array.isArray(answers) || Object.keys(answers).some(k=>!fields.some(f=>f.key===k))) fail(422,'INVALID_ANSWERS');
      const clean={}; for(const f of fields) clean[f.key]=text(answers[f.key]??'',2000,f.required);
      if ((await db.query('SELECT 1 FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[p.id,user.id])).rowCount) fail(409,'REQUEST_EXISTS');
      return (await db.query(`INSERT INTO ca_profile_request(profile_id,user_id,method,form_snapshot,answers)
        VALUES($1,$2,$3,$4,$5) RETURNING id,status`,[p.id,user.id,method,JSON.stringify(fields),JSON.stringify(clean)])).rows[0];
    });
  }
  async function management(user,selected=null) {
    verified(user);
    const roles=(await query(`SELECT c.id,c.name FROM ca_community c WHERE c.id IN(${managerCommunities()}) ORDER BY c.name,c.id`,[user.id])).rows;
    if(!roles.length)fail(403,'HOST_REQUIRED');
    const rows=(await query(`SELECT p.* FROM ca_organizer p WHERE ${organizerManager()} AND ${activeProfileHost} ORDER BY display_name,id`,[user.id])).rows;
    if(selected)identifier(selected);
    const p=selected?rows.find(p=>p.id===selected):rows[0];if(selected&&!p)fail(404,'NOT_FOUND');
    const profiles=[];
    for(const r of rows)profiles.push({id:r.id,is_owner:r.owner_id===user.id,name:r.display_name,description:r.description,is_public:r.is_public,awareness_concept:r.awareness_concept,awareness_team:r.awareness_team,
      allow_application:r.allow_application,allow_form:r.allow_form,allow_link:r.allow_link,form:r.form,version:r.form_version,
      community_ids:(await query('SELECT community_id FROM ca_profile_community WHERE profile_id=$1',[r.id])).rows.map(c=>c.community_id)});
    return {...await catalog.management(user,p?.id??null),...await discovery.management(user,p?.id??null),can_create_profile:!!(await query('SELECT 1 FROM ca_host WHERE user_id=$1',[user.id])).rowCount,communities:roles,profiles,profile:profiles.find(r=>r.id===p?.id)??null,
      requests:extendedProduct&&p?(await query(`SELECT r.id,r.status,r.method,r.form_snapshot,r.answers,u.name AS applicant
        FROM ca_profile_request r JOIN "user" u ON u.id=r.user_id WHERE r.profile_id=$1 ORDER BY r.created_at,r.id`,[p.id])).rows:[],
      links:extendedProduct&&p?(await query('SELECT id,expires_at,used_at,revoked FROM ca_profile_link WHERE profile_id=$1 ORDER BY expires_at DESC',[p.id])).rows:[],
      events:p?(await query(`SELECT e.*,COALESCE((SELECT exact_location FROM ca_event_location WHERE event_id=e.id),'') AS exact_location,
        counts.pending_count,counts.confirmed_count,
        CASE WHEN e.capacity IS NULL THEN NULL ELSE GREATEST(0,e.capacity-counts.confirmed_count) END AS available_places
        FROM ca_event e JOIN ca_host h ON h.community_id=e.community_id
        CROSS JOIN LATERAL (SELECT COUNT(*) FILTER (WHERE i.status='pending')::int AS pending_count,
          COUNT(*) FILTER (WHERE i.status='approved')::int AS confirmed_count FROM ca_event_interest i WHERE i.event_id=e.id) counts
        WHERE h.user_id=(SELECT p.owner_id FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()}) AND e.profile_id=$2 AND ${retainedEvent} AND ${productEventScope} ORDER BY e.starts_at DESC NULLS LAST,e.id`,[user.id,p.id])).rows:[]};
  }
  async function save(user,body) {
    return transaction(async db => {
      await host(db,user);
      await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',['profile:'+user.id]);
      const fields=form(body.form);
      if (body.allow_form && !fields.length) fail(422,'EMPTY_FORM');
      const ids=body.community_ids;
      if (!Array.isArray(ids)||!ids.length||ids.length>30||new Set(ids).size!==ids.length) fail(403,'COMMUNITY_DENIED');
      const rows=(await db.query(`SELECT p.* FROM ca_organizer p WHERE ${organizerManager()} AND ${activeProfileHost} ORDER BY id FOR UPDATE`,[user.id])).rows;
      const existing=body.id?rows.find(p=>p.id===identifier(body.id)):body.create===true?null:rows.length===1?rows[0]:null;
      if(body.id&&!existing)fail(404,'NOT_FOUND');
      const profileRoles=(await db.query('SELECT community_id FROM ca_host WHERE user_id=$1',[existing?.owner_id??user.id])).rows.map(r=>r.community_id);
      if(ids.some(id=>!profileRoles.includes(id)))fail(403,'COMMUNITY_DENIED');
      if(!body.id&&body.create!==true&&rows.length>1)fail(409,'PROFILE_REQUIRED');
      if(existing&&body.version!==existing.form_version)fail(409,'FORM_CHANGED');
      if(!existing&&!(await db.query('SELECT 1 FROM ca_host WHERE user_id=$1',[user.id])).rowCount)fail(403,'HOST_REQUIRED');
      const concept=bool(body.awareness_concept),team=bool(body.awareness_team);
      if(!extendedProduct&&['allow_application','allow_form','allow_link'].some(k=>body[k]===true&&existing?.[k]!==true))fail(404,'NOT_FOUND');
      const profileSettings=extendedProduct?body:existing??{allow_application:false,allow_form:false,allow_link:false,form:[]};
      const args=[existing?.owner_id??user.id,text(body.name,120,true),text(body.description,4000,true),bool(body.is_public),bool(profileSettings.allow_application),bool(profileSettings.allow_form),bool(profileSettings.allow_link),JSON.stringify(extendedProduct?fields:profileSettings.form)];
      const p=(await db.query(existing?`UPDATE ca_organizer SET display_name=$2,description=$3,is_public=$4,allow_application=$5,allow_form=$6,allow_link=$7,form=$8,
        form_version=form_version+1 WHERE owner_id=$1 AND id=$9 RETURNING *`:
        `INSERT INTO ca_organizer(owner_id,display_name,description,is_public,allow_application,allow_form,allow_link,form)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,existing?[...args,existing.id]:args)).rows[0];
      await db.query('UPDATE ca_organizer SET awareness_concept=$2,awareness_team=$3 WHERE id=$1',[p.id,concept,team]);
      await db.query('DELETE FROM ca_profile_community WHERE profile_id=$1',[p.id]);
      for(const id of ids){await db.query('INSERT INTO ca_profile_community VALUES($1,$2)',[p.id,id]);
        if((await db.query('SELECT 1 FROM ca_community_staff WHERE community_id=$1 AND user_id=$2 AND expires_at>NOW()',[id,user.id])).rowCount)await db.query('INSERT INTO ca_community_publisher VALUES($1,$2,true) ON CONFLICT(profile_id,community_id) DO UPDATE SET enabled=true',[p.id,id]);
      }
      return { id:p.id,version:p.form_version };
    });
  }
  async function decide(user,id,body) {
    return transaction(async db => {
      await host(db,user);
      // Lock profile before request, the same order as applying/link redemption.
      const request=(await db.query('SELECT profile_id FROM ca_profile_request WHERE id=$1',[identifier(id)])).rows[0];
      if (!request) fail(404,'NOT_FOUND');
      const p=await profile(request.profile_id,user,db,true); if(!(await db.query(`SELECT 1 FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()}`,[user.id,p.id])).rowCount) fail(404,'NOT_FOUND');
      const r=(await db.query('SELECT * FROM ca_profile_request WHERE id=$1 FOR UPDATE',[id])).rows[0];
      const target=body.status;
      if (!(r.status==='pending'&&['approved','rejected'].includes(target)||r.status==='approved'&&target==='revoked')) fail(409,'INVALID_TRANSITION');
      await db.query('UPDATE ca_profile_request SET status=$1,answers=CASE WHEN $1=\'revoked\' THEN \'{}\'::jsonb ELSE answers END WHERE id=$2',[target,id]);
      return {status:target};
    });
  }
  async function withdraw(user,id) {
    verified(user);
    const r=(await query(`UPDATE ca_profile_request SET status='withdrawn',answers='{}'::jsonb
      WHERE id=$1 AND user_id=$2 AND status='pending' RETURNING id,status`,[identifier(id),user.id])).rows[0];
    if (!r) fail(409,'INVALID_TRANSITION'); return r;
  }
  async function issueLink(user,body) {
    if(!extendedProduct)fail(404,'NOT_FOUND');
    return transaction(async db => {
      await host(db,user);
      const rows=(await db.query(`SELECT p.* FROM ca_organizer p WHERE ${organizerManager()} AND ${activeProfileHost} AND ($2::uuid IS NULL OR id=$2) FOR UPDATE`,[user.id,body.profile_id?identifier(body.profile_id):null])).rows;
      if(rows.length!==1)fail(409,'PROFILE_REQUIRED');const p=rows[0];
      if(!p.allow_link) fail(403,'ACCESS_DISABLED');
      const target=(await db.query('SELECT id FROM "user" WHERE email=$1 AND "emailVerified"=true',[text(body.email,255,true).toLowerCase()])).rows[0];
      if(!target || target.id===user.id) fail(422,'INVALID_RECIPIENT');
      const token=randomBytes(32).toString('hex');
      const r=(await db.query(`INSERT INTO ca_profile_link(profile_id,user_id,digest,expires_at,issuer_id)
        VALUES($1,$2,$3,NOW()+INTERVAL '7 days',$4) RETURNING id`,[p.id,target.id,hash(token),user.id])).rows[0];
      return {id:r.id,url:`http://127.0.0.1:8300/#organizer=${p.id}&profile_link=${token}`};
    });
  }
  async function revokeLink(user,id) {
    return transaction(async db => {
      await host(db,user);
      const r=(await db.query(`UPDATE ca_profile_link l SET revoked=true FROM ca_organizer p
        WHERE l.id=$1 AND l.profile_id=p.id AND ${organizerManager('p','$2')} AND l.used_at IS NULL RETURNING l.id`,[identifier(id),user.id])).rows[0];
      if(!r) fail(404,'NOT_FOUND');return {id:r.id};
    });
  }
  async function redeem(user,id,body) {
    if(!extendedProduct)fail(404,'NOT_FOUND');
    verified(user);
    if(typeof body.token!=='string'||! /^[0-9a-f]{64}$/.test(body.token)) fail(422,'INVALID_LINK');
    return transaction(async db=>{
      const p=await profile(id,user,db,true); if(!p.allow_link) fail(422,'INVALID_LINK');
      const l=(await db.query(`UPDATE ca_profile_link l SET used_at=NOW() WHERE profile_id=$1 AND user_id=$2
        AND digest=$3 AND used_at IS NULL AND NOT revoked AND expires_at>NOW()
        AND EXISTS(SELECT 1 FROM ca_organizer p WHERE p.id=l.profile_id AND ${organizerManager('p','l.issuer_id')}) RETURNING id`,[p.id,user.id,hash(body.token)])).rows[0];
      if(!l) fail(422,'INVALID_LINK');
      const previous=(await db.query('SELECT status FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2 FOR UPDATE',[p.id,user.id])).rows[0];
      if(previous && ['rejected','withdrawn','revoked'].includes(previous.status)) fail(403,'ACCESS_BLOCKED');
      await db.query(`INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'link','approved')
        ON CONFLICT(profile_id,user_id) DO UPDATE SET status='approved',answers='{}'::jsonb`,[p.id,user.id]);
      return {status:'approved'};
    });
  }
  async function saveEvent(user,body) {
    return transaction(async db=>{
      const roles=await host(db,user);if(!roles.includes(body.community_id)) fail(403,'COMMUNITY_DENIED');
      const context=await catalog.validateEvent(db,user,body,roles);
      const existing=body.id?(await db.query('SELECT * FROM ca_event WHERE id=$1 FOR UPDATE',[identifier(body.id)])).rows[0]:null;
      if(body.id&&(!existing||!roles.includes(existing.community_id))) fail(404,'NOT_FOUND');
      if(existing?.profile_id && existing.profile_id!==context.profile)fail(404,'NOT_FOUND');
      if(existing&&body.version!==existing.version)fail(409,'CATALOG_CHANGED');
      if(!['draft','published','cancelled'].includes(body.status)) fail(422,'INVALID_FIELDS');
      let starts=null;if(body.starts_at){ if(typeof body.starts_at!=='string'||body.starts_at.length>40||!/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,3})?)?(?:Z|[+-]\d\d:\d\d)$/.test(body.starts_at)) fail(422,'INVALID_DATE'); starts=new Date(body.starts_at);if(!Number.isFinite(starts.getTime())) fail(422,'INVALID_DATE'); }
      const location=text(body.public_location,240);
      if(body.location_public&&!location) fail(422,'INVALID_FIELDS');
      const details=accessDetails(body.access_details??existing?.access_details??{});
      const content=eventContent(body.event_content??existing?.event_content??{});
      if(content.ends_at&&(!starts||new Date(content.ends_at)<=starts))fail(422,'INVALID_EVENT_CONTENT');
      if(content.ends_at&&Date.parse(content.ends_at)+168*3600000<=Date.now())fail(422,'EXPIRED_EVENT');
      const options=await discovery.eventOptions(db,body,context.profile,existing,context.publication);
      const args=[text(body.title,180,true),body.community_id,body.status,context.publication.isPublic,starts,bool(body.starts_public),location,bool(body.location_public),context.profile,context.series,JSON.stringify(details),JSON.stringify(content)];
      const r=existing?await db.query(`UPDATE ca_event SET title=$1,community_id=$2,status=$3,is_public=$4,starts_at=$5,
        starts_public=$6,public_location=$7,location_public=$8,profile_id=$9,series_id=$10,access_details=$11,event_content=$12,version=version+1 WHERE id=$13 RETURNING id,version`,[...args,existing.id]):
        await db.query(`INSERT INTO ca_event(title,community_id,status,is_public,starts_at,starts_public,public_location,location_public,profile_id,series_id,access_details,event_content)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id,version`,args);
      await db.query('UPDATE ca_event SET access_mode=$2,review_method=$3,form_id=$4,time_release_at=$5,location_release_at=$6,request_deadline_at=$7 WHERE id=$1',[r.rows[0].id,options.mode,options.method,options.formId,options.time,options.location,options.deadline]);
      if(existing?.ticket_mode!=='none'&&existing?.ticket_mode){
        if(context.profile!==existing.profile_id||body.community_id!==existing.community_id)fail(409,'TICKET_CONFIG_LOCKED');
        if(existing.ticket_mode==='public'&&(body.membership_required===true||!context.publication.isPublic||options.mode==='semi_public'))fail(409,'TICKET_CONFIG_LOCKED');
        if(body.capacity!==undefined&&body.capacity!==existing.capacity)fail(409,'TICKET_QUOTA_MANAGED_BY_PRETIX');
      }
      const membership=body.membership_required??existing?.membership_required??false;
      const capacity=body.capacity===undefined?existing?.capacity??null:body.capacity;
      if(typeof membership!=='boolean'||capacity!==null&&(!Number.isInteger(capacity)||capacity<1||capacity>2147483647))fail(422,'INVALID_FIELDS');
      const confirmed=(await db.query("SELECT COUNT(*)::int AS n FROM ca_event_interest WHERE event_id=$1 AND status='approved'",[r.rows[0].id])).rows[0].n;
      if(capacity!==null&&confirmed>capacity)fail(409,'CAPACITY_BELOW_CONFIRMED');
      if(existing&&confirmed&&membership!==existing.membership_required)fail(409,'ACCESS_POLICY_LOCKED');
      await db.query('UPDATE ca_event SET membership_required=$2,capacity=$3 WHERE id=$1',[r.rows[0].id,membership,capacity]);
      if(!existing||existing.community_id!==body.community_id)await db.query(`INSERT INTO ca_event_community_access(event_id,community_id,approved,grants_visibility) SELECT $1,$2,EXISTS(SELECT 1 FROM ca_community_staff WHERE user_id=$3 AND community_id=$2 AND expires_at>NOW()),$4 ON CONFLICT(event_id,community_id) DO UPDATE SET approved=EXCLUDED.approved,grants_visibility=EXCLUDED.grants_visibility`,[r.rows[0].id,body.community_id,user.id,membership]);
      if(body.exact_location!==undefined){
        const exact=text(body.exact_location,2000);
        if(exact)await db.query('INSERT INTO ca_event_location VALUES($1,$2) ON CONFLICT(event_id) DO UPDATE SET exact_location=$2',[r.rows[0].id,exact]);
        else await db.query('DELETE FROM ca_event_location WHERE event_id=$1',[r.rows[0].id]);
      }
      return r.rows[0];
    });
  }
  return { privateAccess:createPrivateAccess(pool),list,venues,venueEvents,access,apply,management,save,decide,withdraw,issueLink,revokeLink,redeem,saveEvent,catalog,discovery,accessFlow,
    async detail(id,user){const p=await profile(id,user);if(!(await query(`SELECT 1 FROM ca_organizer p WHERE p.id=$1 AND ${activeProfileHost}`,[p.id])).rowCount||!await canSee(p,user))fail(404,'NOT_FOUND');return projection(p,user);},
    async isHost(user){return !!user&&(await query(`SELECT 1 FROM (${managerCommunities()}) managed LIMIT 1`,[user.id])).rowCount>0;},
  };
}
