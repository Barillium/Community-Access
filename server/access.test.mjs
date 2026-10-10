import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {migrateAccess} from './access_migrations.mjs';
import {randomUUID} from 'node:crypto';
import {retainedEvent} from './event_policy.mjs';

test('complete access flow: real PostgreSQL, restricted HTTP role and signed sessions',async t=>{
  const state=await createAuth();
  const admin=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_auth'});
  const server=createApp(state);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,body,key)=>new Promise((resolve,reject)=>{
    const req=request(base+'/api/'+path,{method:body===undefined?'GET':'POST',headers:{
      Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300','Content-Type':'application/json',Connection:'close',
      ...(tokens[key]?{Authorization:'Bearer '+tokens[key]}:{}),
    }},res=>{let raw='';res.setEncoding('utf8');res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,data:JSON.parse(raw)}));});
    req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
  });
  const tokens={},users=Object.fromEntries((await admin.query('SELECT id,email FROM "user"')).rows.map(u=>[u.email.split('@')[0],u]));
  for(const key of Object.keys(users))tokens[key]=(await call('auth/sign-in/email',{email:users[key].email,password:'Synthetic-2026!'})).headers['set-auth-token'];
  const payload={name:'Demo Kollektiv Mondbogen',description:'Synthetische Selbstdarstellung.',event_types:'Musik und Performance',awareness_concept:true,awareness_team:false};
  let application,community,profile,event,invitation,guestApplication,membership;
  const fields=[{key:'interest',label:'Was interessiert dich an unserem Programm?',required:true}];
  const invite=async key=>call(`access/communities/${community}/invite`,{email:users[key].email},'team');
  const apply=async (key,token)=>call('access/applications',{token,version:2,answers:{interest:'Synthetische Programmantwort'}},key);
  const admit=async key=>{
    const link=await invite(key);assert.equal(link.status,200);
    const a=await apply(key,link.data.token);assert.equal(a.status,200);
    assert.equal((await call(`access/applications/${a.data.id}/decide`,{status:'approved'},'team')).status,200);
    return a.data.id;
  };
  const requestEvent=key=>call(`directory/events/${event}/interest`,{answers:{},age_acknowledged:true},key);
  const decide=async(key,status='approved')=>{
    const row=(await admin.query('SELECT version FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,users[key].id])).rows[0];
    return call('directory/manage/interest',{event_id:event,user_id:users[key].id,version:row.version,status},'organizer');
  };
  try {
    await t.test('runtime has no DDL, admin, role-assignment or migration rights',async()=>{
      assert.equal(state.databaseRestricted,true);
      for(const sql of ['CREATE TABLE forbidden_runtime(id int)','ALTER TABLE ca_membership ADD COLUMN forbidden int','CREATE ROLE forbidden_role',"INSERT INTO ca_team SELECT id FROM \"user\" WHERE email='guest.a@example.invalid'",'DELETE FROM ca_access_migration'])await assert.rejects(()=>state.pool.query(sql));
      await migrateAccess(admin); // Repeatable owner bootstrap, runtime starts without it.
      assert.deepEqual((await admin.query('SELECT version FROM ca_access_migration ORDER BY version')).rows.map(row=>row.version),['0001-access-flow','0002-ticketing','0003-private-access','0004-native-categories','0005-community-governance','0006-publisher-permissions','0007-organizer-members','0008-organizer-link-issuers','0009-legal-ticketing']);
    });
    await t.test('organizer fields, authentication, team isolation, withdrawal and rejection block',async()=>{
      assert.equal((await call('access/organizer-applications',payload)).status,401);
      assert.equal((await call('access/organizer-applications',payload,'unverified')).status,403);
      assert.equal((await call('access/organizer-applications',{...payload,members:['forbidden']},'organizer')).status,422);
      assert.equal((await call('access/organizer-applications',{...payload,awareness_team:null},'organizer')).status,422);
      const a=await call('access/organizer-applications',payload,'other.host');
      assert.equal((await call(`access/organizer-applications/${a.data.id}/withdraw`,{},'other.host')).status,200);
      const b=await call('access/organizer-applications',payload,'other.host');
      assert.equal((await call(`access/organizer-applications/${b.data.id}/decide`,{status:'approved'},'guest.a')).status,403);
      assert.equal((await call(`access/organizer-applications/${b.data.id}/decide`,{status:'rejected'},'team')).status,200);
      assert.equal((await call('access/organizer-applications',payload,'other.host')).status,403);
      assert.equal((await call('access/team/unblock',{user_id:users['other.host'].id},'organizer')).status,403);
      assert.equal((await call('access/team/unblock',{user_id:users['other.host'].id},'team')).status,200);
      assert.equal((await call('access/organizer-applications',payload,'other.host')).status,200);
      assert.equal((await call('access/team',undefined,'organizer')).status,403);
      assert.equal((await call('access/team',undefined,'unverified')).status,403);
    });
    await t.test('atomic, idempotent organizer acceptance creates private profile and scoped host',async()=>{
      const submitted=await call('access/organizer-applications',payload,'organizer');assert.equal(submitted.status,200);application=submitted.data.id;
      const results=await Promise.all([0,1].map(()=>call(`access/organizer-applications/${application}/decide`,{status:'approved'},'team')));
      assert.ok(results.every(r=>r.status===200));community=results[0].data.community_id;profile=results[0].data.profile_id;
      assert.equal((await admin.query('SELECT count(*)::int AS n FROM ca_host WHERE user_id=$1',[users.organizer.id])).rows[0].n,1);
      assert.equal((await admin.query('SELECT is_public FROM ca_organizer WHERE id=$1',[profile])).rows[0].is_public,false);
      assert.equal((await call(`access/communities/${community}`,undefined,'guest.a')).status,403);
      assert.equal((await call('directory/manage',undefined,'organizer')).status,200);
      assert.equal((await call(`access/communities/${community}/invite`,{email:users['guest.a'].email},'organizer')).status,403);
      assert.equal((await call('access/policy/staff',{community_id:community,email:users.team.email,expires_at:new Date(Date.now()+86400000).toISOString()},'team')).status,200);
      assert.equal((await call(`access/policy/communities/${community}/publishers`,{profile_id:profile,enabled:true},'team')).status,200);
      assert.equal((await call(`directory/organizers/${profile}`)).status,404);
    });
    await t.test('invitation preview never consumes; wrong account, stale form, invalid answers and revoked/expired links deny',async()=>{
      assert.equal((await call(`access/communities/${community}/form`,{fields,version:1,host_contact:'Demokontakt'},'team')).status,200);
      invitation=await invite('guest.a');assert.equal(invitation.status,200);
      assert.equal((await call('access/invitations/preview',{token:invitation.data.token},'guest.b')).status,404);
      for(let i=0;i<2;i++)assert.equal((await call('access/invitations/preview',{token:invitation.data.token},'guest.a')).status,200);
      assert.equal((await call('access/applications',{token:invitation.data.token,version:1,answers:{interest:'Demo'}},'guest.a')).status,409);
      assert.equal((await call('access/applications',{token:invitation.data.token,version:2,answers:{}},'guest.a')).status,422);
      assert.equal((await admin.query('SELECT used_at FROM ca_community_invitation WHERE id=$1',[invitation.data.id])).rows[0].used_at,null);
      const expired=await invite('guest.b');await admin.query("UPDATE ca_community_invitation SET expires_at=NOW()-INTERVAL '1 second' WHERE id=$1",[expired.data.id]);
      assert.equal((await apply('guest.b',expired.data.token)).status,404);
      const revoked=await invite('guest.b');assert.equal((await call(`access/invitations/${revoked.data.id}/revoke`,{},'team')).status,200);
      assert.equal((await apply('guest.b',revoked.data.token)).status,404);
      const stored=(await admin.query('SELECT digest,expires_at>NOW()+INTERVAL \'6 days\' AS valid FROM ca_community_invitation WHERE id=$1',[invitation.data.id])).rows[0];
      assert.notEqual(stored.digest,invitation.data.token);assert.equal(stored.valid,true);
    });
    await t.test('parallel application and approval; rollback leaves invitation usable and no membership',async()=>{
      await admin.query(`CREATE FUNCTION ca_test_fault() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic failure'; END $$;
        CREATE TRIGGER ca_test_fault BEFORE INSERT ON ca_community_application FOR EACH ROW EXECUTE FUNCTION ca_test_fault()`);
      assert.equal((await apply('guest.a',invitation.data.token)).status,503);
      assert.equal((await admin.query('SELECT used_at FROM ca_community_invitation WHERE id=$1',[invitation.data.id])).rows[0].used_at,null);
      await admin.query('DROP TRIGGER ca_test_fault ON ca_community_application');
      const results=await Promise.all([0,1].map(()=>apply('guest.a',invitation.data.token)));
      assert.deepEqual(results.map(r=>r.status).sort(),[200,404]);guestApplication=results.find(r=>r.status===200).data.id;
      assert.equal((await call(`access/applications/${guestApplication}/decide`,{status:'approved'},'guest.a')).status,403);
      assert.equal((await call(`access/applications/${guestApplication}/withdraw`,{},'guest.b')).status,404);
      await admin.query('CREATE TRIGGER ca_test_fault BEFORE UPDATE ON ca_community_application FOR EACH ROW EXECUTE FUNCTION ca_test_fault()');
      assert.equal((await call(`access/applications/${guestApplication}/decide`,{status:'approved'},'team')).status,503);
      assert.equal((await admin.query('SELECT count(*)::int AS n FROM ca_membership')).rows[0].n,0);
      await admin.query('DROP TRIGGER ca_test_fault ON ca_community_application');
      const approvals=await Promise.all([0,1].map(()=>call(`access/applications/${guestApplication}/decide`,{status:'approved'},'team')));
      assert.ok(approvals.every(r=>r.status===200));membership=(await admin.query('SELECT id FROM ca_membership WHERE user_id=$1',[users['guest.a'].id])).rows[0].id;
      assert.equal((await call(`directory/organizers/${profile}`,undefined,'guest.a')).status,404); // membership is not profile access
      assert.equal((await call('account/me',undefined,'guest.a')).data.memberships.length,1);
    });
    await t.test('withdrawal allows a fresh invitation; rejection survives answer deletion',async()=>{
      const admissionLink=await invite('guest.d');const admission=await apply('guest.d',admissionLink.data.token);
      const admissionRace=await Promise.all([call(`access/applications/${admission.data.id}/withdraw`,{},'guest.d'),call(`access/applications/${admission.data.id}/decide`,{status:'approved'},'team')]);
      assert.deepEqual(admissionRace.map(r=>r.status).sort(),[200,409]);
      const admitted=(await admin.query('SELECT status FROM ca_community_application WHERE id=$1',[admission.data.id])).rows[0].status==='approved';
      assert.equal((await admin.query('SELECT 1 FROM ca_membership WHERE user_id=$1',[users['guest.d'].id])).rowCount,admitted?1:0);
      let link=await invite('guest.c');let a=await apply('guest.c',link.data.token);
      const race=await Promise.all([call(`access/applications/${a.data.id}/withdraw`,{},'guest.c'),call(`access/applications/${a.data.id}/decide`,{status:'rejected'},'team')]);
      assert.deepEqual(race.map(r=>r.status).sort(),[200,409]);
      const status=(await admin.query('SELECT status FROM ca_community_application WHERE id=$1',[a.data.id])).rows[0].status;
      if(status==='withdrawn'){
        link=await invite('guest.c');a=await apply('guest.c',link.data.token);assert.equal(a.status,200);
        assert.equal((await call(`access/applications/${a.data.id}/decide`,{status:'rejected'},'team')).status,200);
      }
      const blocked=await invite('guest.c');assert.equal((await apply('guest.c',blocked.data.token)).status,403);
    });
    await t.test('membership and age required; exact location separate from sight and confirmation',async()=>{
      const start=new Date(Date.now()+86400000).toISOString(),end=new Date(Date.now()+90000000).toISOString();
      const saved=await call('directory/manage/event',{profile_id:profile,community_id:community,title:'Demo Zugangsabend',status:'published',is_public:false,starts_at:start,starts_public:true,public_location:'Öffentliche synthetische Ortsangabe',location_public:true,access_mode:'private',review_method:'manual',membership_required:true,capacity:1,exact_location:'Geschützter synthetischer Testort',event_content:{description:'Demo',minimum_age:18,ends_at:end}},'organizer');
      assert.equal(saved.status,200);event=saved.data.id;
      assert.equal((await call(`access/policy/events/${event}/approve-share`,{community_id:community,approved:true},'team')).status,200);
      assert.equal((await call(`access/events/${event}/location`)).status,401);
      assert.equal((await call(`access/events/${event}/location`,undefined,'unverified')).status,403);
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.a')).status,404);
      assert.equal((await call(`directory/events/${event}/interest`,{answers:{}},'guest.a')).status,422);
      await admit('guest.b');
      assert.equal((await requestEvent('guest.a')).status,200);assert.equal((await requestEvent('guest.b')).status,200);
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.a')).status,404);
      const results=await Promise.all([decide('guest.a'),decide('guest.b')]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
      if(results[0].status!==200){await decide('guest.b','revoked');assert.equal((await decide('guest.a')).status,200);}
      const loc=await call(`access/events/${event}/location`,undefined,'guest.a');assert.equal(loc.status,200);assert.equal(loc.headers['cache-control'],'no-store');
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.b')).status,404);
      assert.equal((await call(`access/events/${event}/location`,undefined,'other.host')).status,404);
      assert.equal((await call(`access/events/${event}/location`,undefined,'organizer')).status,200);
      assert.equal((await call(`directory/events/${event}`,undefined,'guest.a')).data.exact_location,undefined);
    });
    await t.test('guest cancellation frees capacity and permits new request; grant cannot restore revoked admission',async()=>{
      assert.equal((await call(`directory/events/${event}/withdraw`,{},'guest.a')).status,200);
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.a')).status,404);
      assert.equal((await requestEvent('guest.a')).status,200);assert.equal((await decide('guest.a')).status,200);
      assert.equal((await call('directory/manage/grant',{kind:'event',id:event,email:users['guest.b'].email},'organizer')).status,200);
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.b')).status,404);
      assert.equal((await call(`directory/organizers/${profile}`,undefined,'guest.b')).status,404);
      // Independent profile access is a separate synthetic fixture for later revocation.
      await admin.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved') ON CONFLICT(profile_id,user_id) DO NOTHING",[profile,users['guest.b'].id]);
    });
    await t.test('revocation versus confirmation never resurrects membership or reserves a slot',async()=>{
      await admin.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved') ON CONFLICT(profile_id,user_id) DO NOTHING",[profile,users['guest.a'].id]);
      assert.equal((await call(`directory/events/${event}/withdraw`,{},'guest.a')).status,200);
      assert.equal((await requestEvent('guest.a')).status,200);
      const results=await Promise.all([decide('guest.a'),call(`access/memberships/${membership}/revoke`,{},'team')]);
      assert.equal(results[1].status,200);assert.ok([200,403,409].includes(results[0].status));
      assert.equal((await admin.query('SELECT active FROM ca_membership WHERE id=$1',[membership])).rows[0].active,false);
      assert.equal((await admin.query('SELECT status FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,users['guest.a'].id])).rows[0].status,'revoked');
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.a')).status,404);
      assert.equal((await call(`directory/organizers/${profile}`,undefined,'guest.a')).status,200); // independent profile stays
      const link=await invite('guest.a');assert.equal((await apply('guest.a',link.data.token)).status,403);
      assert.equal((await call('account/me',undefined,'guest.a')).data.events.length,0); // profile access alone does not reveal a withdrawn member event
    });
    await t.test('direct events survive membership revocation; profile revocation and release timing stay independent',async()=>{
      const direct=(await admin.query(`INSERT INTO ca_event(community_id,profile_id,title,status,access_mode,starts_at,request_deadline_at,event_content)
        VALUES($1,$2,'Demo direkter Weg','published','private',NOW()+INTERVAL '1 day',NOW()+INTERVAL '12 hours',jsonb_build_object('ends_at',NOW()+INTERVAL '2 days')) RETURNING id`,[community,profile])).rows[0].id;
      await admin.query('INSERT INTO ca_event_community_access VALUES($1,$2,true,false)',[direct,community]);
      await admin.query('INSERT INTO ca_event_location VALUES($1,$2)',[direct,'Demo direkter Testort']);
      await call('directory/manage/grant',{kind:'event',id:direct,email:users['guest.a'].email},'organizer');
      assert.equal((await call(`directory/events/${direct}/interest`,{answers:{},age_acknowledged:true},'guest.a')).status,200);
      let version=(await admin.query('SELECT version FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[direct,users['guest.a'].id])).rows[0].version;
      assert.equal((await call('directory/manage/interest',{event_id:direct,user_id:users['guest.a'].id,version,status:'approved'},'organizer')).status,200);
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,200);
      await call(`access/memberships/${membership}/revoke`,{},'team');
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,200);
      await admin.query("UPDATE ca_event SET access_mode='semi_public',location_release_at=NOW()+INTERVAL '1 hour' WHERE id=$1",[direct]);
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,404);
      await admin.query("UPDATE ca_event SET location_release_at=NOW()-INTERVAL '1 second' WHERE id=$1",[direct]);
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,200);
      const pr=(await admin.query('SELECT id FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[profile,users['guest.a'].id])).rows[0].id;
      assert.equal((await call(`directory/requests/${pr}/decide`,{status:'revoked'},'organizer')).status,200);
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,404);
      assert.ok([403,409].includes((await call('directory/manage/grant',{kind:'event',id:direct,email:users['guest.a'].email},'organizer')).status));
      assert.equal((await call(`access/events/${direct}/location`,undefined,'guest.a')).status,404);
      assert.equal((await call('account/me',undefined,'guest.a')).data.events.length,0);
      const otherProfileRequest=(await admin.query('SELECT id FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[profile,users['guest.b'].id])).rows[0].id;
      assert.equal((await call(`directory/requests/${otherProfileRequest}/decide`,{status:'revoked'},'organizer')).status,200);
      assert.equal((await admin.query('SELECT active FROM ca_membership WHERE user_id=$1',[users['guest.b'].id])).rows[0].active,true);
    });
    await t.test('calendar-month retention, live requests and independent memberships/blocks',async()=>{
      const membershipsBefore=(await admin.query('SELECT count(*)::int AS n FROM ca_membership')).rows[0].n;
      await admin.query("UPDATE ca_community_application SET decided_at=NOW()-INTERVAL '3 months' WHERE status<>'pending'");
      await admin.query("UPDATE ca_organizer_application SET decided_at=NOW()-INTERVAL '3 months' WHERE status<>'pending'");
      await state.directory.accessFlow.purge();await state.directory.accessFlow.purge();
      assert.equal((await admin.query("SELECT count(*)::int AS n FROM ca_community_application WHERE status<>'pending'")).rows[0].n,0);
      assert.equal((await admin.query('SELECT count(*)::int AS n FROM ca_membership')).rows[0].n,membershipsBefore);
      assert.equal((await call('access/organizer-applications',payload,'other.host')).status,409); // pending kept
      assert.equal((await call(`access/events/${event}/location`,undefined,'guest.a')).status,404);
      const dates=(await admin.query("SELECT ('2026-12-31'::timestamp + INTERVAL '2 months')::date::text AS feb, ('2026-07-31'::timestamp + INTERVAL '2 months')::date::text AS sep")).rows[0];
      assert.equal(dates.feb,'2027-02-28');assert.equal(dates.sep,'2026-09-30');
      for(const [decided,boundary] of [['2026-12-31T11:00:00Z','2027-02-28T11:00:00Z'],['2026-07-31T10:00:00Z','2026-09-30T10:00:00Z'],['2026-02-28T11:00:00Z','2026-04-28T10:00:00Z']]){
        const id=randomUUID();
        await admin.query("INSERT INTO ca_organizer_application(id,user_id,status,answers,decided_at) VALUES($1,$2,'withdrawn','{}',$3)",[id,users['guest.c'].id,decided]);
        await state.directory.accessFlow.purge(new Date(new Date(boundary).getTime()-1).toISOString());
        assert.equal((await admin.query('SELECT 1 FROM ca_organizer_application WHERE id=$1',[id])).rowCount,1);
        await state.directory.accessFlow.purge(boundary);
        assert.equal((await admin.query('SELECT 1 FROM ca_organizer_application WHERE id=$1',[id])).rowCount,0);
      }
    });
    await t.test('event retention is exactly 168 elapsed hours across both Berlin clock changes',async()=>{
      const db=await admin.connect();
      try {
        await db.query('BEGIN');
        await db.query("SET LOCAL TIME ZONE 'Europe/Berlin'");
        const policy=retainedEvent.replace('NOW()','$1::timestamptz');
        for(const end of ['2026-03-28T12:00:00+01:00','2026-10-24T12:00:00+02:00']){
          const boundary=Date.parse(end)+168*3600000;
          for(const [offset,expected] of [[-1,true],[0,false],[1,false]]){
            const at=new Date(boundary+offset).toISOString();
            const result=await db.query(`SELECT ${policy} AS retained
              FROM (SELECT jsonb_build_object('ends_at',$2::text) AS event_content) e`,[at,end]);
            assert.equal(result.rows[0].retained,expected,`${end} at ${offset}ms from expiry`);
          }
        }
      } finally {
        await db.query('ROLLBACK');
        db.release();
      }
    });
    await t.test('event begin and exact 168-hour expiry deny; team host revocation blocks all host/public paths',async()=>{
      await admin.query('UPDATE ca_event SET starts_at=NOW()-INTERVAL \'1 hour\' WHERE id=$1',[event]);
      const row=(await admin.query('SELECT version,status FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,users['guest.b'].id])).rows[0];
      const ownActive=['pending','approved'].includes(row.status);
      const eventVisible=(await call(`directory/events/${event}`,undefined,'guest.b')).status===200;
      const withdrawal=await call(`directory/events/${event}/withdraw`,{},'guest.b');
      assert.equal(withdrawal.status,ownActive&&eventVisible?409:404);
      assert.equal(withdrawal.data.code,ownActive&&eventVisible?'REQUEST_CLOSED':'NOT_FOUND');
      // Whether the previous last-place race rejected this request or revoked it,
      // no new confirmation after start may succeed.
      await admin.query("UPDATE ca_event_interest SET status='pending' WHERE event_id=$1 AND user_id=$2",[event,users['guest.b'].id]);
      assert.equal((await decide('guest.b')).status,409);
      await admin.query("UPDATE ca_event SET event_content=jsonb_set(event_content,'{ends_at}',to_jsonb((NOW()-INTERVAL '168 hours'+INTERVAL '5 seconds')::text)) WHERE id=$1",[event]);
      assert.equal((await call(`access/events/${event}/location`,undefined,'organizer')).status,200);
      await admin.query("UPDATE ca_event SET event_content=jsonb_set(event_content,'{ends_at}',to_jsonb((NOW()-INTERVAL '168 hours')::text)) WHERE id=$1",[event]);
      assert.equal((await call(`access/events/${event}/location`,undefined,'organizer')).status,404);
      await state.directory.discovery.purge();
      assert.equal((await admin.query('SELECT count(*)::int AS n FROM ca_event_interest WHERE event_id=$1',[event])).rows[0].n,0);
      assert.equal((await admin.query('SELECT count(*)::int AS n FROM ca_event_location WHERE event_id=$1',[event])).rows[0].n,0);
      const unrelated=(await admin.query("INSERT INTO ca_community(name) VALUES('Demo andere Gastgeberrolle') RETURNING id")).rows[0].id;
      await admin.query('INSERT INTO ca_host VALUES($1,$2)',[users.organizer.id,unrelated]);
      await admin.query('UPDATE ca_organizer SET is_public=true WHERE id=$1',[profile]);
      assert.equal((await call(`directory/organizers/${profile}`)).status,200);
      assert.equal((await call('access/team/revoke-host',{user_id:users.organizer.id,community_id:community},'team')).status,200);
      assert.equal((await call(`directory/manage?profile_id=${profile}`,undefined,'organizer')).status,404);
      assert.equal((await call('directory/bookmarks',undefined,'guest.b')).data.profiles.length,0);
      assert.equal((await call(`directory/organizers/${profile}`,undefined,'guest.b')).status,404);
      assert.equal((await call(`directory/organizers/${profile}`)).status,404);
      await admin.query('DELETE FROM ca_host WHERE user_id=$1 AND community_id=$2',[users.organizer.id,unrelated]);
      assert.equal((await call('directory/manage',undefined,'organizer')).status,403);
      assert.equal((await call(`directory/organizers/${profile}`,undefined,'guest.a')).status,404);
      assert.equal((await call(`access/communities/${community}/invite`,{email:users['guest.b'].email},'organizer')).status,403);
    });
  } finally {
    await new Promise(resolve=>server.close(resolve));await state.pool.end();await admin.end();
  }
});
