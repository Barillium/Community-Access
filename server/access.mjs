import {assertAccountAction} from './account_policy.mjs';
import { randomBytes, createHash } from 'node:crypto';
import { DirectoryError } from './directory.mjs';
import { checkedForm } from './form_policy.mjs';
import { accessWriteLock, confirmedParticipation,activeMembership,profileNotRevoked,communityAllowed } from './access_policy.mjs';
import { retainedEvent,eventPolicy,eventJoins } from './event_policy.mjs';
const eventRules=eventPolicy();
import { publicEvent, personalEvent } from './catalog.mjs';

const fail = (status, code) => { throw new DirectoryError(status, code); };
const uuid = value => {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)) fail(404, 'NOT_FOUND');
  return value;
};
const text = (value, max, required = false) => {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) fail(422, 'INVALID_FIELDS');
  return value.trim();
};
const verified = user => {
  if (!user) fail(401, 'UNAUTHENTICATED');
  if (!user.emailVerified) fail(403, 'VERIFY_EMAIL');
};
const hash = value => createHash('sha256').update(value).digest('hex');
const tokenDigest = value => {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) fail(404, 'INVALID_INVITATION');
  return hash(value);
};
function organizerAnswers(body) {
  const allowed = ['name','description','event_types','awareness_concept','awareness_team','history','venues','organization'];
  if (Object.keys(body).some(k => !allowed.includes(k))) fail(422, 'INVALID_FIELDS');
  const out = {};
  for (const key of ['name','description','event_types']) out[key] = text(body[key], key === 'name' ? 120 : 4000, true);
  for (const key of ['history','venues','organization']) out[key] = text(body[key] ?? '', 4000);
  for (const key of ['awareness_concept','awareness_team']) {
    if (typeof body[key] !== 'boolean') fail(422, 'INVALID_FIELDS');
    out[key] = body[key];
  }
  return out;
}
function answersFor(fields, answers) {
  if (!answers || typeof answers !== 'object' || Array.isArray(answers) || Object.keys(answers).some(k => !fields.some(f => f.key === k))) fail(422, 'INVALID_ANSWERS');
  return Object.fromEntries(fields.map(f => [f.key, text(answers[f.key] ?? '', 2000, f.required)]));
}

export function createAccess(pool, catalog) {
  async function tx(work) {
    const db = await pool.connect();
    try {
      await db.query('BEGIN');
      await db.query(accessWriteLock);await assertAccountAction(db);
      const result = await work(db);
      await db.query('COMMIT');
      return result;
    } catch (error) { await db.query('ROLLBACK'); throw error; }
    finally { db.release(); }
  }
  async function team(db, user) {
    verified(user);
    if (!(await db.query('SELECT 1 FROM ca_team WHERE user_id=$1', [user.id])).rowCount) fail(403, 'TEAM_REQUIRED');
  }
  async function communityModerator(db, user, community) {
    verified(user);
    if (!(await db.query('SELECT 1 FROM ca_community_staff WHERE user_id=$1 AND community_id=$2 AND expires_at>NOW() FOR SHARE', [user.id, uuid(community)])).rowCount) fail(403, 'COMMUNITY_DENIED');
  }
  async function submitOrganizer(user, body) {
    verified(user);
    const answers = organizerAnswers(body);
    return tx(async db => {
      if ((await db.query('SELECT 1 FROM ca_organizer_block WHERE user_id=$1', [user.id])).rowCount) fail(403, 'ACCESS_BLOCKED');
      if ((await db.query('SELECT 1 FROM ca_host WHERE user_id=$1 UNION ALL SELECT 1 FROM ca_organizer_application WHERE user_id=$1 AND status IN(\'pending\',\'approved\')', [user.id])).rowCount) fail(409, 'REQUEST_EXISTS');
      return (await db.query('INSERT INTO ca_organizer_application(user_id,answers) VALUES($1,$2) RETURNING id,status', [user.id, JSON.stringify(answers)])).rows[0];
    });
  }
  async function decideOrganizer(user, id, body) {
    return tx(async db => {
      await team(db, user);
      const a = (await db.query('SELECT * FROM ca_organizer_application WHERE id=$1 FOR UPDATE', [uuid(id)])).rows[0];
      if (!a) fail(404, 'NOT_FOUND');
      if (!['approved','rejected'].includes(body.status)) fail(422, 'INVALID_FIELDS');
      if (a.status === body.status) return {status:a.status,community_id:a.community_id,profile_id:a.profile_id};
      if (a.status !== 'pending') fail(409, 'INVALID_TRANSITION');
      let community = null, profile = null;
      if (body.status === 'approved') {
        community = (await db.query('INSERT INTO ca_community(name) VALUES($1) RETURNING id', [a.answers.name])).rows[0].id;
        await db.query('INSERT INTO ca_host VALUES($1,$2)', [a.user_id,community]);
        profile = (await db.query(`INSERT INTO ca_organizer(owner_id,display_name,description,awareness_concept,awareness_team)
          VALUES($1,$2,$3,$4,$5) RETURNING id`, [a.user_id,a.answers.name,a.answers.description,a.answers.awareness_concept,a.answers.awareness_team])).rows[0].id;
        await db.query('INSERT INTO ca_profile_community VALUES($1,$2)', [profile,community]);
        await db.query('INSERT INTO ca_community_form(community_id) VALUES($1)', [community]);
      } else await db.query('INSERT INTO ca_organizer_block VALUES($1) ON CONFLICT DO NOTHING', [a.user_id]);
      await db.query('UPDATE ca_organizer_application SET status=$2,decided_at=NOW(),community_id=$3,profile_id=$4 WHERE id=$1', [id,body.status,community,profile]);
      return {status:body.status,community_id:community,profile_id:profile};
    });
  }
  async function withdrawOrganizer(user, id) {
    verified(user);
    return tx(async db => {
      const a = (await db.query('SELECT status FROM ca_organizer_application WHERE id=$1 AND user_id=$2 FOR UPDATE', [uuid(id),user.id])).rows[0];
      if (!a) fail(404,'NOT_FOUND');
      if (a.status === 'withdrawn') return {status:'withdrawn'};
      if (a.status !== 'pending') fail(409,'INVALID_TRANSITION');
      await db.query("UPDATE ca_organizer_application SET status='withdrawn',decided_at=NOW() WHERE id=$1", [id]);
      return {status:'withdrawn'};
    });
  }
  async function teamView(user) {
    return tx(async db => {
      await team(db,user);
      return {
        applications:(await db.query('SELECT a.*,u.name AS applicant,u.email AS contact FROM ca_organizer_application a JOIN "user" u ON u.id=a.user_id ORDER BY a.created_at,a.id')).rows,
        blocks:(await db.query('SELECT b.user_id,u.name FROM ca_organizer_block b JOIN "user" u ON u.id=b.user_id')).rows,
        hosts:(await db.query('SELECT h.user_id,h.community_id,c.name AS community,u.name FROM ca_host h JOIN ca_community c ON c.id=h.community_id JOIN "user" u ON u.id=h.user_id')).rows,
      };
    });
  }
  async function unblockOrganizer(user, body) {
    return tx(async db => { await team(db,user); await db.query('DELETE FROM ca_organizer_block WHERE user_id=$1',[text(body.user_id,255,true)]); return {unblocked:true}; });
  }
  async function revokeHost(user, body) {
    return tx(async db => {
      await team(db,user);
      await db.query('DELETE FROM ca_host WHERE user_id=$1 AND community_id=$2',[text(body.user_id,255,true),uuid(body.community_id)]);
      return {revoked:true};
    });
  }
  async function hostView(user, community) {
    return tx(async db => {
      await communityModerator(db,user,community);
      return {
        form:(await db.query('SELECT * FROM ca_community_form WHERE community_id=$1',[community])).rows[0] ?? {community_id:community,fields:[],version:0,host_contact:''},
        applications:(await db.query('SELECT a.*,u.name AS applicant FROM ca_community_application a JOIN "user" u ON u.id=a.user_id WHERE community_id=$1 ORDER BY a.created_at,a.id',[community])).rows,
        memberships:(await db.query('SELECT m.*,u.name AS guest FROM ca_membership m JOIN "user" u ON u.id=m.user_id WHERE community_id=$1',[community])).rows,
        invitations:(await db.query('SELECT id,user_id,expires_at,used_at,revoked FROM ca_community_invitation WHERE community_id=$1',[community])).rows,
      };
    });
  }
  async function saveForm(user, community, body) {
    return tx(async db => {
      await communityModerator(db,user,community);
      const fields=checkedForm(body.fields);
      if (!fields.length) fail(422,'EMPTY_FORM');
      const existing=(await db.query('SELECT version FROM ca_community_form WHERE community_id=$1',[community])).rows[0];
      if (body.version !== (existing?.version ?? 0)) fail(409,'FORM_CHANGED');
      return (await db.query(`INSERT INTO ca_community_form VALUES($1,$2,1,$3)
        ON CONFLICT(community_id) DO UPDATE SET fields=$2,version=ca_community_form.version+1,host_contact=$3 RETURNING version`,[community,JSON.stringify(fields),text(body.host_contact??'',1000)])).rows[0];
    });
  }
  async function issueInvitation(user, community, body) {
    return tx(async db => {
      await communityModerator(db,user,community);
      const target=(await db.query('SELECT id FROM "user" WHERE email=$1 AND "emailVerified"=true',[text(body.email,255,true).toLowerCase()])).rows[0];
      if (!target || target.id===user.id) fail(422,'INVALID_RECIPIENT');
      if (!(await db.query("SELECT 1 FROM ca_community_form WHERE community_id=$1 AND jsonb_array_length(fields)>0",[community])).rowCount) fail(422,'EMPTY_FORM');
      const token=randomBytes(32).toString('hex');
      const row=(await db.query(`INSERT INTO ca_community_invitation(community_id,user_id,issuer_id,digest,expires_at)
        VALUES($1,$2,$3,$4,NOW()+INTERVAL '7 days') RETURNING id,expires_at`,[community,target.id,user.id,hash(token)])).rows[0];
      return {...row,token,url:`http://127.0.0.1:8300/#invite=${token}`};
    });
  }
  async function revokeInvitation(user, id) {
    return tx(async db => {
      const l=(await db.query('SELECT * FROM ca_community_invitation WHERE id=$1',[uuid(id)])).rows[0];
      if (!l) fail(404,'NOT_FOUND');
      await communityModerator(db,user,l.community_id);
      if (l.used_at) fail(409,'INVALID_TRANSITION');
      await db.query('UPDATE ca_community_invitation SET revoked=true WHERE id=$1',[id]);
      return {revoked:true};
    });
  }
  async function invitation(db,user,token) {
    verified(user);
    const l=(await db.query(`SELECT l.*,c.name AS community FROM ca_community_invitation l JOIN ca_community c ON c.id=l.community_id
      WHERE l.digest=$1 AND l.user_id=$2 AND NOT l.revoked AND l.used_at IS NULL AND l.expires_at>NOW()
      AND EXISTS(SELECT 1 FROM ca_community_staff h WHERE h.user_id=l.issuer_id AND h.community_id=l.community_id AND h.expires_at>NOW())`,[tokenDigest(token),user.id])).rows[0];
    if (!l) fail(404,'INVALID_INVITATION');
    if(!(await db.query(`SELECT 1 WHERE ${communityAllowed('$1','$2')} AND NOT EXISTS(SELECT 1 FROM ca_restriction r WHERE r.user_id=$2 AND r.platform AND r.revoked_at IS NULL AND (r.expires_at IS NULL OR r.expires_at>NOW()))`,[l.community_id,user.id])).rowCount)fail(403,'ACCESS_BLOCKED');
    if ((await db.query('SELECT 1 FROM ca_community_block WHERE community_id=$1 AND user_id=$2',[l.community_id,user.id])).rowCount) fail(403,'ACCESS_BLOCKED');
    return l;
  }
  async function preview(user,body) {
    return tx(async db => {
      const l=await invitation(db,user,body.token);
      const f=(await db.query('SELECT * FROM ca_community_form WHERE community_id=$1',[l.community_id])).rows[0];
      return {community_id:l.community_id,community:l.community,rule:(await db.query('SELECT id,version,rules FROM ca_community_rule_version WHERE community_id=$1 ORDER BY version DESC LIMIT 1',[l.community_id])).rows[0]??null,host_contact:f.host_contact,form:{id:l.community_id,version:f.version,questions:checkedForm(f.fields)}};
    });
  }
  async function apply(user,body) {
    return tx(async db => {
      const l=await invitation(db,user,body.token);
      const f=(await db.query('SELECT * FROM ca_community_form WHERE community_id=$1',[l.community_id])).rows[0];
      if (body.version!==f.version) fail(409,'FORM_CHANGED');
      const rule=(await db.query('SELECT id FROM ca_community_rule_version WHERE community_id=$1 ORDER BY version DESC LIMIT 1',[l.community_id])).rows[0];
      if(rule&&body.rule_version_id!==rule.id)fail(409,'RULES_CHANGED');
      const fields=checkedForm(f.fields),answers=answersFor(fields,body.answers);
      if ((await db.query('SELECT 1 FROM ca_community_application WHERE community_id=$1 AND user_id=$2 AND status=\'pending\' UNION ALL SELECT 1 FROM ca_membership WHERE community_id=$1 AND user_id=$2 AND active',[l.community_id,user.id])).rowCount) fail(409,'REQUEST_EXISTS');
      await db.query('UPDATE ca_community_invitation SET used_at=NOW() WHERE id=$1',[l.id]);
      return (await db.query('INSERT INTO ca_community_application(community_id,user_id,form_snapshot,answers,rule_version_id) VALUES($1,$2,$3,$4,$5) RETURNING id,status',[l.community_id,user.id,JSON.stringify(fields),JSON.stringify(answers),rule?.id??null])).rows[0];
    });
  }
  async function decideApplication(user,id,body) {
    return tx(async db => {
      const a=(await db.query('SELECT * FROM ca_community_application WHERE id=$1 FOR UPDATE',[uuid(id)])).rows[0];
      if (!a) fail(404,'NOT_FOUND');
      await communityModerator(db,user,a.community_id);
      if (!['approved','rejected'].includes(body.status)) fail(422,'INVALID_FIELDS');
      if (a.status===body.status) return {status:a.status};
      if (a.status!=='pending') fail(409,'INVALID_TRANSITION');
      if (body.status==='approved') {
        if ((await db.query('SELECT 1 FROM ca_community_block WHERE community_id=$1 AND user_id=$2',[a.community_id,a.user_id])).rowCount) fail(403,'ACCESS_BLOCKED');
        await db.query('INSERT INTO ca_membership(community_id,user_id,approved_by,approved_at,application_id) VALUES($1,$2,$3,NOW(),$4) ON CONFLICT(community_id,user_id) DO NOTHING',[a.community_id,a.user_id,user.id,a.id]);
      } else await db.query('INSERT INTO ca_community_block VALUES($1,$2,\'rejected\') ON CONFLICT DO NOTHING',[a.community_id,a.user_id]);
      await db.query('UPDATE ca_community_application SET status=$2,decided_at=NOW() WHERE id=$1',[id,body.status]);
      return {status:body.status};
    });
  }
  async function withdrawApplication(user,id) {
    verified(user);
    return tx(async db => {
      const a=(await db.query('SELECT status FROM ca_community_application WHERE id=$1 AND user_id=$2 FOR UPDATE',[uuid(id),user.id])).rows[0];
      if (!a) fail(404,'NOT_FOUND');
      if (a.status==='withdrawn') return {status:'withdrawn'};
      if (a.status!=='pending') fail(409,'INVALID_TRANSITION');
      await db.query('UPDATE ca_community_application SET status=\'withdrawn\',decided_at=NOW() WHERE id=$1',[id]);
      return {status:'withdrawn'};
    });
  }
  async function revokeMembership(user,id) {
    return tx(async db => {
      const m=(await db.query('SELECT * FROM ca_membership WHERE id=$1 FOR UPDATE',[uuid(id)])).rows[0];
      if (!m) fail(404,'NOT_FOUND');
      await communityModerator(db,user,m.community_id);
      await db.query('UPDATE ca_membership SET active=false WHERE id=$1',[id]);
      await db.query("INSERT INTO ca_community_block VALUES($1,$2,'revoked') ON CONFLICT(community_id,user_id) DO UPDATE SET reason='revoked'",[m.community_id,m.user_id]);
      await db.query(`UPDATE ca_event_interest i SET status='revoked',answers='{}',version=i.version+1 FROM ca_event e
        WHERE i.event_id=e.id AND e.community_id=$1 AND e.membership_required AND i.user_id=$2 AND i.status IN('pending','approved','purchase_eligible') AND NOT EXISTS(SELECT 1 FROM ca_membership alt JOIN ca_event_community_access ec ON ec.community_id=alt.community_id WHERE ec.event_id=e.id AND ec.approved AND ec.grants_visibility AND alt.user_id=$2 AND alt.active AND alt.accepted_at IS NOT NULL AND (alt.expires_at IS NULL OR alt.expires_at>NOW()) AND NOT EXISTS(SELECT 1 FROM ca_community_block cb WHERE cb.community_id=alt.community_id AND cb.user_id=$2) AND NOT EXISTS(SELECT 1 FROM ca_restriction cr WHERE cr.community_id=alt.community_id AND cr.user_id=$2 AND cr.revoked_at IS NULL AND (cr.expires_at IS NULL OR cr.expires_at>NOW()))) AND NOT EXISTS(SELECT 1 FROM ca_event_grant eg WHERE eg.event_id=e.id AND eg.user_id=$2 AND eg.active AND eg.revoked_at IS NULL AND (eg.expires_at IS NULL OR eg.expires_at>NOW()))`,[m.community_id,m.user_id]);
      return {revoked:true};
    });
  }
  async function location(user,event) {
    verified(user);
    const r=(await pool.query(`SELECT l.exact_location ${eventJoins}
      JOIN ca_event_location l ON l.event_id=e.id WHERE e.id=$2 AND ${eventRules.exactLocation}`,[user.id,uuid(event)])).rows[0];
    if (!r) fail(404,'NOT_FOUND');
    return {location:r.exact_location};
  }
  async function snapshot(user) {
    if(!user)fail(401,'UNAUTHENTICATED');
    const q=(sql)=>pool.query(sql,[user.id]);
    return {
      is_team:!!(await q('SELECT 1 FROM ca_team WHERE user_id=$1')).rowCount,
      organizer_blocked:!!(await q('SELECT 1 FROM ca_organizer_block WHERE user_id=$1')).rowCount,
      organizer_applications:(await q('SELECT id,status,community_id,profile_id FROM ca_organizer_application WHERE user_id=$1 ORDER BY created_at')).rows,
      moderated_communities:(await q('SELECT c.id,c.name FROM ca_community_staff h JOIN ca_community c ON c.id=h.community_id WHERE h.user_id=$1 AND h.expires_at>NOW() ORDER BY c.name')).rows,
      host_communities:(await q('SELECT c.id,c.name FROM ca_host h JOIN ca_community c ON c.id=h.community_id WHERE h.user_id=$1 ORDER BY c.name')).rows,
      applications:(await q('SELECT a.id,a.community_id,c.name AS community,a.status FROM ca_community_application a JOIN ca_community c ON c.id=a.community_id WHERE a.user_id=$1 ORDER BY a.created_at')).rows,
      memberships:(await q('SELECT m.id,m.community_id,c.name AS community,m.active FROM ca_membership m JOIN ca_community c ON c.id=m.community_id WHERE m.user_id=$1')).rows,
      application_blocks:(await q('SELECT b.community_id,b.reason,c.name AS community,f.host_contact FROM ca_community_block b JOIN ca_community c ON c.id=b.community_id LEFT JOIN ca_community_form f ON f.community_id=b.community_id WHERE b.user_id=$1')).rows,
      events:(await q(`SELECT e.id,e.title,e.status,i.status AS request_status,e.membership_required,e.capacity,e.ticket_mode,
        CASE WHEN ${eventRules.time} THEN e.starts_at END AS starts_at,${confirmedParticipation} AS confirmed,
        e.event_content->'minimum_age' AS minimum_age
        FROM ca_event e JOIN ca_organizer p ON p.id=e.profile_id JOIN ca_community c ON c.id=e.community_id
        LEFT JOIN ca_series s ON s.id=e.series_id LEFT JOIN ca_event_interest i ON i.event_id=e.id AND i.user_id=$1
        WHERE ${retainedEvent} AND e.status='published' AND ${profileNotRevoked}
        AND (i.user_id=$1 OR (e.membership_required AND ${activeMembership}))
        AND (${eventRules.visible})
        AND EXISTS(SELECT 1 FROM ca_host h WHERE h.user_id=p.owner_id AND h.community_id=e.community_id)`)).rows,
    };
  }
  async function purge(at=null) {
    return tx(async db => {
      // Europe/Berlin calendar months, including end-of-month clamping. Events
      // continue to use their independent 168-hour retention and cascades.
      let count=0;
      for (const table of ['ca_organizer_application','ca_community_application']) {
        const r=await db.query(`DELETE FROM ${table} WHERE decided_at IS NOT NULL
          AND ((decided_at AT TIME ZONE 'Europe/Berlin') + INTERVAL '2 months') AT TIME ZONE 'Europe/Berlin' <= COALESCE($1::timestamptz,NOW())`,[at]);
        count+=r.rowCount;
      }
      await db.query('DELETE FROM ca_community_invitation WHERE expires_at<=NOW() OR used_at IS NOT NULL OR revoked');
      return {deleted:count};
    });
  }
  async function route(user,path,method,body) {
    verified(user);
    await purge();
    const m=/^(organizer-applications|communities|invitations|applications|memberships|events)\/([0-9a-f-]{36})(?:\/(decide|withdraw|form|invite|revoke|location))?$/.exec(path);
    if (method==='GET') {
      if(path==='team')return teamView(user);
      if(m?.[1]==='communities'&&!m[3])return hostView(user,m[2]);
      if(m?.[1]==='events'&&m[3]==='location')return location(user,m[2]);
    } else if(method==='POST') {
      if(path==='organizer-applications')return submitOrganizer(user,body);
      if(path==='team/unblock')return unblockOrganizer(user,body);
      if(path==='team/revoke-host')return revokeHost(user,body);
      if(path==='invitations/preview')return preview(user,body);
      if(path==='applications')return apply(user,body);
      if(m?.[1]==='organizer-applications'&&m[3]==='decide')return decideOrganizer(user,m[2],body);
      if(m?.[1]==='organizer-applications'&&m[3]==='withdraw')return withdrawOrganizer(user,m[2]);
      if(m?.[1]==='communities'&&m[3]==='form')return saveForm(user,m[2],body);
      if(m?.[1]==='communities'&&m[3]==='invite')return issueInvitation(user,m[2],body);
      if(m?.[1]==='invitations'&&m[3]==='revoke')return revokeInvitation(user,m[2]);
      if(m?.[1]==='applications'&&m[3]==='decide')return decideApplication(user,m[2],body);
      if(m?.[1]==='applications'&&m[3]==='withdraw')return withdrawApplication(user,m[2]);
      if(m?.[1]==='memberships'&&m[3]==='revoke')return revokeMembership(user,m[2]);
    }
    fail(404,'NOT_FOUND');
  }
  return {route,snapshot,purge,location};
}
