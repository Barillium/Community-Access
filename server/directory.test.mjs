import {eventPolicyTests} from './event_policy.test.mjs';
import {securityEventPolicyTests} from './security_event_policy.test.mjs';
import {discoveryTests} from './discovery.test.mjs';
import {communityCountTests} from './community_counts.test.mjs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {readFileSync} from 'node:fs';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {seedDirectory,datedEventFixture} from './directory_fixtures.mjs';
import {createDirectory} from './directory.mjs';
import {createRequestLimits} from './request_security.mjs';

test('directory: real PostgreSQL and signed Better Auth sessions',async t=>{
  // Independent behavior cases get independent limiter minutes. Keep the real
  // default limits and real DB/Auth; dedicated request-security tests cover 429.
  let limiterTime=Date.now();
  t.beforeEach(()=>{limiterTime+=60000;});
  const state=await createAuth();const f=await seedDirectory(state);
  const server=createApp({...state,requestLimits:createRequestLimits({now:()=>limiterTime})});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,input,token,origin='http://127.0.0.1:8300')=>{const body=path==='directory/manage/event'&&input?datedEventFixture(input):input;return new Promise((resolve,reject)=>{
    const req=request(base+'/api/'+path,{method:body===undefined?'GET':'POST',headers:{Host:'127.0.0.1:8000',Origin:origin,
      'Content-Type':'application/json',Connection:'close',...(token?{Authorization:'Bearer '+token}:{})}},res=>{
      let raw='';res.setEncoding('utf8');res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,
        headers:res.headers,data:JSON.parse(raw)}));res.on('error',reject);
    });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
  });};
  const tokens={};for(const key of Object.keys(f.users))tokens[key]=(await call('auth/sign-in/email',{email:f.users[key].email,password:f.password})).headers['set-auth-token'];
  const a=f.profiles['host.a'].id,b=f.profiles['host.b'].id;
  const apply=(key,method='form',answers={interest:'Synthetische Antwort'},version=1)=>call(`directory/organizers/${b}/apply`,{method,answers,version},tokens[key]);
  try {
    await communityCountTests(t,state,f,call,tokens);
    await t.test('public event search filters visibility before search and paging, and guards public fields',async()=>{
      const results=await call('directory/events');
      assert.equal(results.status,200);assert.equal(results.data.events.length,4);
      assert.equal(results.data.has_more,false);
      assert.equal(results.data.events.some(e=>e.id===f.hiddenEvent.id),false);
      assert.deepEqual((await call('directory/events',undefined,tokens['host.a'])).data,results.data);
      assert.equal((await call('directory/events?q=Clubnacht')).data.events.length,1);
      assert.equal((await call('directory/events?q=Musik')).data.events.length,4);
      assert.equal((await call('directory/events?q=Nebel')).data.events.length,0);
      assert.equal((await call('directory/events?q=%25')).data.events.length,0);
      assert.equal((await call('directory/events?page=0')).status,422);
      assert.equal((await call('directory/events?page=1.5')).status,422);
      assert.equal((await call('directory/events?q=a&q=b')).status,400);
      assert.equal((await call('directory/events?private=true')).status,400);
      assert.equal((await call('directory/events?q='+ 'x'.repeat(181))).status,422);
      const event=results.data.events.find(e=>e.title.includes('Clubnacht'));
      const stored=(await state.pool.query('SELECT * FROM ca_event WHERE id=$1',[event.id])).rows[0];
      try {
        await state.pool.query('UPDATE ca_event SET starts_public=false,location_public=false WHERE id=$1',[event.id]);
        const hiddenFields=(await call('directory/events?q=Clubnacht')).data.events[0];
        assert.equal(hiddenFields.starts_at,null);assert.equal(hiddenFields.location,'');
        assert.equal(hiddenFields.event_content,undefined);assert.equal(hiddenFields.access_details,undefined);
        for(const change of [
          {column:'is_public',value:false}, {column:'status',value:'draft'},
          {column:'community_id',value:f.privateCommunity}, {column:'series_id',value:f.series.id},
          {column:'profile_id',value:b},
        ]) {
          await state.pool.query(`UPDATE ca_event SET ${change.column}=$1 WHERE id=$2`,[change.value,event.id]);
          assert.equal((await call('directory/events?q=Clubnacht')).data.events.length,0,change.column);
          await state.pool.query(`UPDATE ca_event SET ${change.column}=$1 WHERE id=$2`,[stored[change.column],event.id]);
        }
        await state.pool.query('UPDATE ca_organizer SET is_public=false WHERE id=$1',[a]);
        assert.equal((await call('directory/events')).data.events.length,0);
      } finally {
        await state.pool.query('UPDATE ca_event SET starts_public=$1,location_public=$2 WHERE id=$3',[stored.starts_public,stored.location_public,event.id]);
        await state.pool.query('UPDATE ca_organizer SET is_public=true WHERE id=$1',[a]);
      }
      const inserted=[];
      try {
        for(let i=0;i<23;i++)inserted.push(await state.directory.saveEvent(f.users['host.a'],datedEventFixture({
          title:'Demo Suchseite '+i,community_id:f.community,status:'published',is_public:true,
          starts_at:null,starts_public:false,public_location:'',location_public:false,
        })));
        const page1=(await call('directory/events?q=Suchseite')).data;
        const page2=(await call('directory/events?q=Suchseite&page=2')).data;
        assert.equal(page1.events.length,20);assert.equal(page1.has_more,true);
        assert.equal(page2.events.length,3);assert.equal(page2.has_more,false);
        assert.equal(new Set([...page1.events,...page2.events].map(e=>e.id)).size,23);
      } finally {for(const event of inserted)await state.pool.query('DELETE FROM ca_event WHERE id=$1',[event.id]);}
    });
    await t.test('anonymous listings, literal name/Community filtering, pagination and no private enumeration',async()=>{
      const list=await call('directory/organizers');assert.equal(list.status,200);assert.deepEqual(list.data.items.map(p=>p.id),[a]);
      assert.equal((await call('directory/organizers?q=wolken')).data.items.length,1);
      assert.equal((await call('directory/organizers?q=%25')).data.items.length,0);
      assert.equal((await call(`directory/organizers?community=${f.privateCommunity}`)).data.items.length,0);
      assert.equal((await call('directory/organizers?page=0')).status,422);
      assert.equal((await call('directory/organizers?q=a&q=b')).status,400);
      assert.equal((await call(`directory/organizers/${b}`)).status,404);
      const access=await call(`directory/organizers/${b}/access`);assert.equal(access.status,404);assert.deepEqual(access.data,{code:'NOT_FOUND'});
      const publicAccess=await call(`directory/organizers/${a}/access`);assert.equal(publicAccess.status,200);assert.deepEqual(publicAccess.data.form,[]);assert.equal(publicAccess.data.allow_form,false);assert.equal(publicAccess.data.allow_link,false);
      const entry=await call(`directory/organizers/${b}/access`,undefined,tokens['guest.a']);assert.equal(entry.status,200);assert.equal(entry.data.name,'Profilzugang');assert.equal(entry.data.description,undefined);assert.equal(entry.data.communities,undefined);
      assert.equal((await call('directory/organizers',undefined,'forged')).status,401);
      assert.equal((await call('directory/organizers',undefined,null,'https://foreign.example.invalid')).status,403);
    });
    await t.test('authentication, verification and host roles are checked server side',async()=>{
      assert.equal((await apply('unverified')).status,403);
      assert.equal((await call(`directory/organizers/${b}/apply`,{method:'application',answers:{},version:1})).status,401);
      assert.equal((await call('directory/manage',undefined,tokens['guest.a'])).status,403);
      assert.equal((await call('account/me',undefined,tokens['host.a'])).data.is_host,true);
      assert.equal((await call('account/me',undefined,tokens['guest.a'])).data.is_host,false);
      assert.equal((await call('directory/manage/profile',{name:'attacker'},tokens['guest.a'])).status,403);
    });
    let requestId;
    await t.test('form version, required/unknown answers, concurrency and manual approval',async()=>{
      assert.equal((await apply('guest.a','form',{},1)).status,422);
      assert.equal((await apply('guest.a','form',{interest:'x',extra:'bad'},1)).status,422);
      assert.equal((await apply('guest.a','form',{interest:'x'},0)).status,409);
      const results=await Promise.all([apply('guest.a'),apply('guest.a')]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
      requestId=results.find(r=>r.status===200).data.id;
      assert.equal((await call(`directory/organizers/${b}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await call(`directory/requests/${requestId}/decide`,{status:'approved'},tokens['host.a'])).status,404);
      const manage=await call('directory/manage',undefined,tokens['host.b']);assert.equal(manage.data.requests[0].answers.interest,'Synthetische Antwort');
      const decisions=await Promise.all(['approved','rejected'].map(status=>call(`directory/requests/${requestId}/decide`,{status},tokens['host.b'])));
      assert.deepEqual(decisions.map(r=>r.status).sort(),[200,409]);
      // Whichever transaction won, normalize only in this isolated fixture for subsequent grant tests.
      await state.pool.query("UPDATE ca_profile_request SET status='approved' WHERE id=$1",[requestId]);
      const personal=await call(`directory/organizers/${b}`,undefined,tokens['guest.a']);assert.equal(personal.status,200);
      assert.deepEqual(personal.data.communities.map(c=>c.id),[f.community]);
      assert.equal((await call('directory/organizers',undefined,tokens['guest.a'])).data.items.length,2);
      assert.deepEqual((await call('directory/organizers')).data.items.map(p=>p.id),[a]);
      assert.equal((await call(`directory/organizers/${b}/access`)).status,404);
      assert.equal((await call(`directory/organizers/${b}`,undefined,tokens['guest.b'])).status,404);
      assert.equal((await call('account/me',undefined,tokens['guest.a'])).data.memberships.length,0);
      assert.equal((await call('events/1/location',undefined,tokens['guest.a'])).status,404);
    });
    await t.test('revocation removes visibility immediately, clears answers, blocks reapplication and link bypass',async()=>{
      assert.equal((await call(`directory/requests/${requestId}/decide`,{status:'revoked'},tokens['host.b'])).status,200);
      assert.equal((await call(`directory/organizers/${b}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await apply('guest.a')).status,409);
      assert.deepEqual((await state.pool.query('SELECT answers FROM ca_profile_request WHERE id=$1',[requestId])).rows[0].answers,{});
      const issued=await call('directory/manage/link',{email:f.users['guest.a'].email},tokens['host.b']);
      const token=new URLSearchParams(new URL(issued.data.url).hash.slice(1)).get('profile_link');
      assert.equal((await call(`directory/organizers/${b}/redeem`,{token},tokens['guest.a'])).status,403);
      assert.equal((await state.pool.query('SELECT used_at FROM ca_profile_link WHERE id=$1',[issued.data.id])).rows[0].used_at,null);
    });
    await t.test('personal links: target binding, expiry, revocation, one-time concurrency, disabled method',async()=>{
      const issued=await call('directory/manage/link',{email:f.users['guest.b'].email},tokens['host.b']);assert.equal(issued.status,200);
      const token=new URLSearchParams(new URL(issued.data.url).hash.slice(1)).get('profile_link');
      assert.equal((await call(`directory/organizers/${b}/redeem`,{token},tokens['guest.c'])).status,422);
      const results=await Promise.all([0,1].map(()=>call(`directory/organizers/${b}/redeem`,{token},tokens['guest.b'])));
      assert.deepEqual(results.map(r=>r.status).sort(),[200,422]);
      assert.equal((await call(`directory/organizers/${b}`,undefined,tokens['guest.b'])).status,200);
      for(const mode of ['expired','revoked','disabled']){
        const issued=await call('directory/manage/link',{email:f.users['guest.c'].email},tokens['host.b']);
        const token=new URLSearchParams(new URL(issued.data.url).hash.slice(1)).get('profile_link');
        if(mode==='expired')await state.pool.query("UPDATE ca_profile_link SET expires_at=NOW()-INTERVAL '1 minute' WHERE id=$1",[issued.data.id]);
        if(mode==='revoked')assert.equal((await call(`directory/links/${issued.data.id}/revoke`,{},tokens['host.b'])).status,200);
        if(mode==='disabled')await state.pool.query('UPDATE ca_organizer SET allow_link=false WHERE id=$1',[b]);
        assert.equal((await call(`directory/organizers/${b}/redeem`,{token},tokens['guest.c'])).status,422);
      }
    });
    await t.test('withdrawal races with approval safely; rejected/withdrawn applications stay blocked',async()=>{
      const r=await apply('guest.c','application',{});assert.equal(r.status,200);
      const outcomes=await Promise.all([call(`directory/requests/${r.data.id}/withdraw`,{},tokens['guest.c']),
        call(`directory/requests/${r.data.id}/decide`,{status:'approved'},tokens['host.b'])]);
      assert.deepEqual(outcomes.map(r=>r.status).sort(),[200,409]);assert.equal((await apply('guest.c')).status,409);
    });
    await t.test('venues derive only from public published history and location flags, including past and cancelled events',async()=>{
      const venues=await call('directory/venues');assert.equal(venues.data.items.length,1);assert.equal(venues.data.items[0].event_count,3);
      assert.equal((await call('directory/venues?q=verborgen')).data.items.length,0);
      const detail=await call('directory/venue?name=Demo%20Kulturhalle');assert.equal(detail.data.events.length,3);
      assert.ok(detail.data.events.some(e=>e.status==='cancelled'));assert.ok(detail.data.events.some(e=>e.title.includes('Vergangener')));
      assert.equal((await call('directory/venue?name=Verborgener%20Demo-Ort')).status,404);
      const event=(await state.pool.query('SELECT id FROM ca_event WHERE title=$1',['Demo: Nächste Clubnacht'])).rows[0];
      await state.pool.query('UPDATE ca_event SET starts_public=false WHERE id=$1',[event.id]);
      assert.equal((await call('directory/venue?name=Demo%20Kulturhalle')).data.events.find(e=>e.id===event.id).starts_at,null);
      await state.pool.query('UPDATE ca_community SET is_public=false WHERE id=$1',[f.community]);
      assert.equal((await call('directory/venues')).data.items.length,0);
      await state.pool.query('UPDATE ca_community SET is_public=true WHERE id=$1',[f.community]);
    });
    await t.test('host event summary counts pending and confirmed separately, isolates profiles and tracks revoked seats',async()=>{
      const created=await call('directory/manage/event',{profile_id:a,title:'Demo Gastgeberübersicht',community_id:f.community,status:'draft',is_public:false,starts_at:null,starts_public:false,public_location:'',location_public:false,capacity:3},tokens['host.a']);
      assert.equal(created.status,200);const eventId=created.data.id;
      try {
        for(const [key,status] of [['guest.a','pending'],['guest.b','approved'],['guest.c','rejected']]) {
          await state.pool.query('INSERT INTO ca_event_interest(event_id,user_id,status) VALUES($1,$2,$3)',[eventId,f.users[key].id,status]);
        }
        const summary=(await call('directory/manage',undefined,tokens['host.a'])).data.events.find(e=>e.id===eventId);
        assert.equal(summary.pending_count,1);assert.equal(summary.confirmed_count,1);assert.equal(summary.available_places,2);
        assert.equal((await call('directory/manage',undefined,tokens['host.b'])).data.events.some(e=>e.id===eventId),false);
        assert.equal((await call('directory/manage',undefined,tokens['guest.a'])).status,403);
        assert.equal((await call('directory/events')).data.events.some(e=>e.id===eventId),false);
        await state.pool.query("UPDATE ca_event_interest SET status='revoked' WHERE event_id=$1 AND status='approved'",[eventId]);
        const updated=(await call('directory/manage',undefined,tokens['host.a'])).data.events.find(e=>e.id===eventId);
        assert.equal(updated.pending_count,1);assert.equal(updated.confirmed_count,0);assert.equal(updated.available_places,3);
        await state.pool.query('UPDATE ca_event SET capacity=NULL WHERE id=$1',[eventId]);
        assert.equal((await call('directory/manage',undefined,tokens['host.a'])).data.events.find(e=>e.id===eventId).available_places,null);
      } finally { await state.pool.query('DELETE FROM ca_event WHERE id=$1',[eventId]); }
    });
    await t.test('event writes reject ordinary accounts, foreign Communities and malformed dates',async()=>{
      const body={title:'Demo event write',community_id:f.community,status:'published',is_public:true,starts_at:'invalid',starts_public:true,public_location:'Demo',location_public:true};
      assert.equal((await call('directory/manage/event',body,tokens['guest.a'])).status,403);
      assert.equal((await call('directory/manage/event',body,tokens['host.a'])).status,422);
      assert.equal((await call('directory/manage/event',{...body,community_id:f.privateCommunity},tokens['host.a'])).status,403);
      assert.equal((await call('directory/manage/event',{...body,starts_at:'2026-11-01T19:00:00Z',public_location:''},tokens['host.a'])).status,422);
    });
    await t.test('hidden series/events never leak from a public profile, direct URLs, venue counts or searches',async()=>{
      const program=await call(`directory/organizers/${a}/program`);assert.equal(program.status,200);assert.deepEqual(program.data.series,[]);
      assert.equal(program.data.events.some(e=>e.id===f.hiddenEvent.id),false);
      assert.equal((await call(`directory/series/${f.series.id}`)).status,404);
      const hidden=await call(`directory/events/${f.hiddenEvent.id}`),missing=await call('directory/events/00000000-0000-4000-8000-000000000099');assert.deepEqual(hidden.data,missing.data);assert.equal(hidden.status,404);
      assert.equal((await call('directory/venues?q=Nebel')).data.items.length,0);assert.equal((await call('directory/venues')).data.items[0].event_count,3);
      assert.equal((await call('directory/venue?name=Demo%20Nebelort')).status,404);
      await state.pool.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved')",[a,f.users['guest.c'].id]);
      assert.equal((await call(`directory/organizers/${a}/program`,undefined,tokens['guest.c'])).data.events.some(e=>e.id===f.hiddenEvent.id),false);
      assert.equal((await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email},tokens['host.b'])).status,404);
      assert.equal((await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users.unverified.email},tokens['host.a'])).status,422);
      assert.equal((await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email},tokens['guest.a'])).status,403);
    });
    let seriesGrant,future;
    await t.test('separate series grant opens all published future events only for its verified signed-in guest',async()=>{
      seriesGrant=await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email},tokens['host.a']);assert.equal(seriesGrant.status,200);
      const one=await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.a']);assert.equal(one.status,200);assert.equal(one.data.series,'Demo Nebelreihe');
      assert.equal((await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.b'])).status,404);
      const created=await call('directory/manage/event',{title:'Demo zukünftiger Nebelabend',community_id:f.community,series_id:f.series.id,status:'published',is_public:false,
        starts_at:'2027-03-14T20:00:00Z',starts_public:true,public_location:'Demo Nebelort',location_public:true},tokens['host.a']);assert.equal(created.status,200);future=created.data.id;
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.a'])).status,200);
      assert.equal((await call(`directory/series/${f.series.id}`,undefined,tokens['guest.a'])).data.events.length,2);
      const draft=await call('directory/manage/event',{title:'Demo Nebelentwurf',community_id:f.community,series_id:f.series.id,status:'draft',is_public:false,
        starts_at:null,starts_public:false,public_location:'',location_public:false},tokens['host.a']);assert.equal(draft.status,200);
      assert.equal((await call(`directory/events/${draft.data.id}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await call('directory/venues',undefined,tokens['guest.a'])).data.items.length,1);
      assert.equal((await call('directory/venues',undefined,tokens['guest.a'])).data.items[0].event_count,3);
      assert.equal((await call('account/me',undefined,tokens['guest.a'])).data.memberships.length,0);
      assert.equal((await call(`directory/events/${future}`)).status,404);
    });
    await t.test('individual event access does not reveal its hidden series or other dates',async()=>{
      const grant=await call('directory/manage/grant',{kind:'event',id:f.hiddenEvent.id,email:f.users['guest.b'].email},tokens['host.a']);assert.equal(grant.status,200);
      const detail=await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.b']);assert.equal(detail.status,200);assert.equal(detail.data.series,'');
      const program=await call(`directory/organizers/${a}/program`,undefined,tokens['guest.b']);assert.deepEqual(program.data.series,[]);assert.equal(program.data.events.find(e=>e.id===f.hiddenEvent.id).series_id,null);
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.b'])).status,404);
      assert.equal((await call(`directory/series/${f.series.id}`,undefined,tokens['guest.b'])).status,404);
      assert.equal((await call('directory/manage/revoke',{kind:'event',id:grant.data.id,version:grant.data.version},tokens['host.b'])).status,404);
      assert.equal((await call('directory/manage/revoke',{kind:'event',id:grant.data.id,version:grant.data.version},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.b'])).status,404);
    });
    await t.test('concurrent series grant/revocation has one winner; revocation applies to future events immediately',async()=>{
      const results=await Promise.all([
        call('directory/manage/revoke',{kind:'series',id:seriesGrant.data.id,version:seriesGrant.data.version},tokens['host.a']),
        call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email,version:seriesGrant.data.version},tokens['host.a'])]);
      assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
      const active=(await state.pool.query('SELECT active,version FROM ca_series_grant WHERE id=$1',[seriesGrant.data.id])).rows[0];
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.a'])).status,active.active?200:404);
      if(active.active)assert.equal((await call('directory/manage/revoke',{kind:'series',id:seriesGrant.data.id,version:active.version},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await call(`directory/series/${f.series.id}`,undefined,tokens['guest.a'])).status,404);
    });
    await t.test('series/event editing enforces ownership, versions and matching responsible Community',async()=>{
      const s=(await call('directory/manage',undefined,tokens['host.a'])).data.series[0];
      assert.equal((await call('directory/manage/series',{...s,community_id:f.privateCommunity},tokens['host.a'])).status,403);
      assert.equal((await call('directory/manage/series',{...s,title:'Foreign'},tokens['host.b'])).status,404);
      const results=await Promise.all(['First','Second'].map(title=>call('directory/manage/series',{...s,title},tokens['host.a'])));assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
      const e=(await call('directory/manage',undefined,tokens['host.a'])).data.events.find(e=>e.id===future);
      assert.equal((await call('directory/manage/event',{...e,title:'Foreign',series_id:null},tokens['host.b'])).status,404);
      assert.equal((await call('directory/manage/event',{...e,version:0},tokens['host.a'])).status,409);
      assert.equal((await call('directory/manage/event',{...e,series_id:'00000000-0000-4000-8000-000000000099'},tokens['host.a'])).status,403);
      assert.equal((await call('directory/manage',undefined,tokens['host.b'])).data.series.length,0);
      assert.equal((await call('directory/manage',undefined,tokens['host.b'])).data.grants.length,0);
    });
    await t.test('a remaining individual event grant survives series revocation; field flags never reveal hidden locations or dates',async()=>{
      const version=(await state.pool.query('SELECT version FROM ca_series_grant WHERE id=$1',[seriesGrant.data.id])).rows[0].version;
      const grant=await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email,version},tokens['host.a']);assert.equal(grant.status,200);
      const eventGrant=await call('directory/manage/grant',{kind:'event',id:f.hiddenEvent.id,email:f.users['guest.a'].email},tokens['host.a']);assert.equal(eventGrant.status,200);
      assert.equal((await call('directory/manage/revoke',{kind:'series',id:grant.data.id,version:grant.data.version},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.a'])).status,200);
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.a'])).status,404);
      const e=(await call('directory/manage',undefined,tokens['host.a'])).data.events.find(e=>e.id===f.hiddenEvent.id);
      assert.equal((await call('directory/manage/event',{...e,starts_public:false,location_public:false},tokens['host.a'])).status,200);
      const detail=await call(`directory/events/${e.id}`,undefined,tokens['guest.a']);assert.equal(detail.data.starts_at,null);assert.equal(detail.data.location,'');assert.equal(detail.data.series,'');
      assert.equal((await call('directory/manage/revoke',{kind:'event',id:eventGrant.data.id,version:eventGrant.data.version},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${e.id}`,undefined,tokens['guest.a'])).status,404);
    });
    await t.test('program pagination filters before its page boundary and future series dates remain reachable',async()=>{
      const version=(await state.pool.query('SELECT version FROM ca_series_grant WHERE id=$1',[seriesGrant.data.id])).rows[0].version;
      assert.equal((await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.a'].email,version},tokens['host.a'])).status,200);
      for(let i=0;i<23;i++)await state.pool.query("INSERT INTO ca_event(profile_id,series_id,community_id,title,status,is_public) VALUES($1,$2,$3,$4,'published',false)",[a,f.series.id,f.community,`Demo Reihenfolge ${i}`]);
      await state.pool.query("INSERT INTO ca_event_community_access SELECT id,community_id,true,false FROM ca_event WHERE series_id=$1 AND title LIKE 'Demo Reihenfolge %' ON CONFLICT DO NOTHING",[f.series.id]);
      const first=await call(`directory/series/${f.series.id}?page=1`,undefined,tokens['guest.a']),second=await call(`directory/series/${f.series.id}?page=2`,undefined,tokens['guest.a']);
      assert.equal(first.data.events.length,20);assert.equal(first.data.has_more,true);assert.equal(second.data.events.length,5);assert.equal(second.data.has_more,false);
      assert.equal(new Set([...first.data.events,...second.data.events].map(e=>e.id)).size,25);
      const anonymous=await call(`directory/organizers/${a}/program`);assert.equal(anonymous.data.has_more,false);assert.equal(anonymous.data.events.length,4);
      assert.equal((await call(`directory/series/${f.series.id}?page=1`)).status,404);
      assert.equal((await call(`directory/organizers/${a}/program?page=0`)).status,422);
      assert.equal((await call(`directory/organizers/${a}/program?page=1&page=2`)).status,400);
    });
    await t.test('link redemption against simultaneous withdrawal of that link has exactly one winner',async()=>{
      await state.pool.query('UPDATE ca_organizer SET allow_link=true WHERE id=$1',[b]);
      const issued=await call('directory/manage/link',{email:f.users['guest.d'].email},tokens['host.b']);
      const token=new URLSearchParams(new URL(issued.data.url).hash.slice(1)).get('profile_link');
      const results=await Promise.all([call(`directory/organizers/${b}/redeem`,{token},tokens['guest.d']),
        call(`directory/links/${issued.data.id}/revoke`,{},tokens['host.b'])]);
      assert.equal(results.filter(r=>r.status===200).length,1);
      const personal=await call(`directory/organizers/${b}`,undefined,tokens['guest.d']);
      assert.equal(personal.status,results[0].status===200?200:404);
    });
    await t.test('multiple host profiles have independent catalogs, links and public status',async()=>{
      const privateBody={title:'Demo Privatprofil Event',community_id:f.community,status:'published',is_public:true,starts_at:null,starts_public:false,public_location:'Demo Mehrprofilort',location_public:true,profile_id:b};
      assert.deepEqual((await call('directory/manage/event',privateBody,tokens['host.b'])).data,{code:'PUBLIC_PROFILE_REQUIRED'});
      assert.equal((await call('directory/manage/series',{profile_id:b,title:'Demo private Reihe',description:'',community_id:f.community,is_public:true},tokens['host.b'])).status,422);
      const create={awareness_concept:true,awareness_team:false,create:true,name:'Demo zweites öffentliches Profil',description:'Nur synthetisch',is_public:true,allow_application:false,allow_form:false,allow_link:true,form:[],community_ids:[f.community]};
      const second=await call('directory/manage/profile',create,tokens['host.b']);assert.equal(second.status,200);assert.notEqual(second.data.id,b);
      const selected=await call(`directory/manage?profile_id=${second.data.id}`,undefined,tokens['host.b']);assert.equal(selected.data.profiles.length,2);assert.equal(selected.data.profile.id,second.data.id);assert.deepEqual(selected.data.requests,[]);
      assert.equal((await call(`directory/manage?profile_id=${second.data.id}`,undefined,tokens['host.a'])).status,404);
      assert.equal((await call('directory/manage/event',{...privateBody,profile_id:second.data.id},tokens['host.b'])).status,200);
      assert.equal((await call('directory/manage/event',{...privateBody,profile_id:second.data.id},tokens['host.a'])).status,404);
      const selectedAfter=await call(`directory/manage?profile_id=${second.data.id}`,undefined,tokens['host.b']);assert.equal(selectedAfter.data.events.length,1);
      assert.equal((await call(`directory/manage?profile_id=${b}`,undefined,tokens['host.b'])).data.events.length,0);
      assert.equal((await call('directory/venues?q=Mehrprofilort')).data.items.length,1);
      const event=selectedAfter.data.events[0];assert.equal((await call(`directory/events/${event.id}`)).status,200);
      assert.equal((await call('directory/manage/event',{...privateBody,profile_id:null},tokens['host.b'])).status,409);
      const link=await call('directory/manage/link',{profile_id:second.data.id,email:f.users['guest.d'].email},tokens['host.b']);assert.equal(link.status,200);
      assert.equal((await call(`directory/manage?profile_id=${second.data.id}`,undefined,tokens['host.b'])).data.links.length,1);
      const original=await call(`directory/manage?profile_id=${b}`,undefined,tokens['host.b']);assert.equal(original.data.links.some(l=>l.id===link.data.id),false);
      const downgraded=await call('directory/manage/profile',{...selectedAfter.data.profile,is_public:false},tokens['host.b']);assert.equal(downgraded.status,200);
      assert.equal((await call('directory/venues?q=Mehrprofilort')).data.items.length,0);assert.equal((await call(`directory/events/${event.id}`)).status,404);
      assert.equal((await call('directory/manage/profile',{...selectedAfter.data.profile,is_public:true},tokens['host.b'])).status,409);
      assert.equal((await call('directory/manage',undefined,tokens['host.b'])).data.profiles.find(p=>p.id===b).is_public,false);
      await state.pool.query('DELETE FROM ca_organizer WHERE id=$1',[second.data.id]);
    });
    await t.test('preview shares field authorization, is owner-only and does not create grants or attendance',async()=>{
      const event=await call('directory/manage/event',{profile_id:a,title:'Demo Vorschau',community_id:f.community,status:'published',is_public:false,starts_at:'2027-01-01T20:00:00Z',starts_public:false,
        public_location:'Demo nicht freigegebener Ort',location_public:false,access_details:{step_free:'yes',seating:'no',awareness_notes:'Demo Awareness-Team',awareness_contact:'Demo Infopunkt'}},tokens['host.a']);assert.equal(event.status,200);
      const before=(await state.pool.query('SELECT count(*)::int AS n FROM ca_event_grant')).rows[0].n;
      for(const [audience,visible] of [['anonymous',false],['profile',false],['series',false],['event',true],['confirmed',true]]){
        const preview=await call('directory/manage/preview',{id:event.data.id,audience},tokens['host.a']);assert.equal(preview.status,200);assert.equal(preview.data.visible,visible);
        assert.equal(preview.data.location,'');assert.equal(preview.data.starts_at,null);assert.equal(preview.data.exact_location_available,false);assert.equal(preview.data.participation_available,true);
        if(visible){assert.equal(preview.data.access_details.step_free,'yes');assert.equal(preview.data.access_details.accessible_toilet,'unknown');}
        else {assert.equal(preview.data.title,null);assert.deepEqual(preview.data.access_details,{});}
      }
      assert.equal((await state.pool.query('SELECT count(*)::int AS n FROM ca_event_grant')).rows[0].n,before);
      assert.equal((await call('directory/manage/preview',{id:event.data.id,audience:'event'},tokens['host.b'])).status,404);
      assert.equal((await call('directory/manage/preview',{id:event.data.id,audience:'event'},tokens['guest.a'])).status,403);
      assert.equal((await call('directory/manage/preview',{id:event.data.id,audience:'owner'},tokens['host.a'])).status,422);
      const e=(await call(`directory/manage?profile_id=${a}`,undefined,tokens['host.a'])).data.events.find(e=>e.id===event.data.id);
      assert.equal((await call('directory/manage/event',{...e,access_details:{step_free:'maybe'}},tokens['host.a'])).status,422);
      assert.equal((await call('directory/manage/event',{...e,access_details:{private_location:'unexpected'}},tokens['host.a'])).status,422);
      const grant=await call('directory/manage/grant',{kind:'event',id:e.id,email:f.users['guest.c'].email},tokens['host.a']);assert.equal(grant.status,200);
      assert.equal((await call(`directory/events/${e.id}`,undefined,tokens['guest.c'])).data.access_details.awareness_notes,'Demo Awareness-Team');
      assert.equal((await call(`directory/events/${e.id}`,undefined,tokens['guest.d'])).status,404);
      assert.equal((await call('directory/manage/revoke',{kind:'event',id:grant.data.id,version:grant.data.version},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${e.id}`,undefined,tokens['guest.c'])).status,404);
      await state.pool.query('DELETE FROM ca_event WHERE id=$1',[e.id]);
    });
    await t.test('editorial content persists, validates and masks venue/end fields in detail and preview',async()=>{
      const content={description:'Demo Beschreibung\nZweiter Absatz',line_up:['Demo Act A','Demo Act B'],genres:['Techno','Ambient'],venue_name:'Demo Hallenraum',ends_at:'2027-01-02T04:00:00Z',minimum_age:18,admission:'Demo Einlass nur nach separater Bestätigung',flyer_alt:'Demo Nachtlinie',flyer_data:'data:image/jpeg;base64,'+readFileSync(new URL('../docs/demo-assets/event-flyer-normalized.jpg',import.meta.url)).toString('base64')};
      const body={profile_id:a,title:'Demo redaktionelle Eventseite',community_id:f.community,status:'published',is_public:true,starts_at:'2027-01-01T22:00:00Z',starts_public:false,public_location:'Demo öffentliche Ortsangabe',location_public:false,event_content:content};
      const created=await call('directory/manage/event',body,tokens['host.a']);assert.equal(created.status,200);
      let detail=await call(`directory/events/${created.data.id}`);assert.equal(detail.status,200);
      assert.deepEqual(detail.data.event_content.line_up,content.line_up);assert.equal(detail.data.organizer_id,a);assert.equal(detail.data.event_content.flyer_data,content.flyer_data);
      assert.equal(detail.data.event_content.venue_name,'');assert.equal(detail.data.event_content.ends_at,null);assert.equal(detail.data.location,'');
      let preview=await call('directory/manage/preview',{id:created.data.id,audience:'anonymous'},tokens['host.a']);
      assert.deepEqual(preview.data.event_content,detail.data.event_content);
      const manage=()=>call(`directory/manage?profile_id=${a}`,undefined,tokens['host.a']);
      const stored=(await manage()).data.events.find(e=>e.id===created.data.id);assert.equal(stored.event_content.venue_name,content.venue_name);
      for(const invalid of [{genres:Array(9).fill('Techno')},{line_up:['']},{minimum_age:-1},{ends_at:'2026-01-01T12:00:00Z'},{ends_at:'date'},{unexpected:'secret'},{flyer_data:'https://example.invalid/image.jpg'},{flyer_data:'data:image/svg+xml;base64,PHN2Zz4='},{description:'x'.repeat(6001)}]){
        assert.equal((await call('directory/manage/event',{...stored,event_content:{...content,...invalid}},tokens['host.a'])).status,422);
      }
      assert.equal((await manage()).data.events.find(e=>e.id===created.data.id).version,stored.version);
      assert.equal((await call('directory/manage/event',{...stored,starts_public:true,location_public:true},tokens['host.a'])).status,200);
      detail=await call(`directory/events/${created.data.id}`);assert.equal(detail.data.event_content.venue_name,content.venue_name);assert.equal(detail.data.event_content.ends_at,content.ends_at.replace('Z','.000Z'));
      // Older editor clients omit the new content: their writes preserve it.
      const saved=(await manage()).data.events.find(e=>e.id===created.data.id);delete saved.event_content;
      assert.equal((await call('directory/manage/event',{...saved,title:'Demo neuer Titel'},tokens['host.a'])).status,200);
      assert.equal((await call(`directory/events/${created.data.id}`)).data.event_content.description,content.description);
      assert.equal((await call('directory/manage/event',{...saved,event_content:content},tokens['host.b'])).status,404);
      const current=(await manage()).data.events.find(e=>e.id===created.data.id);
      await call('directory/manage/event',{...current,is_public:false},tokens['host.a']);
      assert.equal((await call(`directory/events/${created.data.id}`)).status,404);
      preview=await call('directory/manage/preview',{id:created.data.id,audience:'anonymous'},tokens['host.a']);assert.deepEqual(preview.data.event_content,{});assert.equal(preview.data.organizer,'');
      const owner=await state.auth.api.getSession({headers:new Headers({Authorization:'Bearer '+tokens['host.a']})});
      await createDirectory(state.pool);assert.equal((await state.directory.catalog.eventDetail(created.data.id,owner.user)).event_content.description,content.description);
      await state.pool.query('DELETE FROM ca_event WHERE id=$1',[created.data.id]);
    });
    await t.test('bookmarks persist per account, are idempotent and never bypass revoked visibility',async()=>{
      assert.equal((await call('directory/bookmarks')).status,401);
      const mark={kind:'profile',id:a,saved:true};
      assert.equal((await call('directory/bookmark',mark,tokens['guest.c'])).status,200);
      const writes=await Promise.all([0,1].map(()=>call('directory/bookmark',mark,tokens['guest.c'])));assert.ok(writes.every(r=>r.status===200));
      assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.profiles.length,1);
      assert.deepEqual((await call('directory/bookmarks',undefined,tokens['guest.d'])).data,{profiles:[],series:[],events:[]});
      assert.equal((await call('directory/bookmark',{kind:'profile',id:b,saved:true},tokens['guest.a'])).status,404);
      assert.equal((await call('directory/bookmark',{kind:'series',id:f.series.id,saved:true},tokens['guest.c'])).status,404);
      const grant=await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.c'].email},tokens['host.a']);assert.equal(grant.status,200);
      assert.equal((await call('directory/bookmark',{kind:'series',id:f.series.id,saved:true},tokens['guest.c'])).status,200);
      assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.series.length,1);
      await createDirectory(state.pool);assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.series.length,1);
      assert.equal((await call('directory/manage/revoke',{kind:'series',id:grant.data.id,version:grant.data.version},tokens['host.a'])).status,200);
      assert.deepEqual((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.series,[]);
      assert.equal((await call('directory/bookmark',{kind:'series',id:f.series.id,saved:false},tokens['guest.c'])).status,200);
      assert.equal((await call('directory/bookmark',{kind:'profile',id:a,saved:false},tokens['guest.c'])).status,200);
      assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.profiles.length,0);
      assert.equal((await call('account/me',undefined,tokens['guest.c'])).data.memberships.length,0);
    });
    await t.test('public interest counts use unique verified bookmarks, including events, and never expose private targets',async()=>{
      const profile=await call('directory/manage/profile',{awareness_concept:true,awareness_team:false,create:true,name:'Demo Interesse',description:'Synthetische Vorstellung',is_public:true,allow_application:false,allow_form:false,allow_link:false,form:[],community_ids:[f.community]},tokens['host.a']);assert.equal(profile.status,200);
      const pid=profile.data.id;
      const series=await call('directory/manage/series',{profile_id:pid,title:'Demo öffentliche Reihe',description:'',community_id:f.community,is_public:true},tokens['host.a']);assert.equal(series.status,200);
      const event=await call('directory/manage/event',{profile_id:pid,series_id:series.data.id,title:'Demo Interesse Event',community_id:f.community,status:'published',is_public:true,starts_at:null,starts_public:false,public_location:'Demo Interesse Halle',location_public:true},tokens['host.a']);assert.equal(event.status,200);
      const targets=[['profile',pid,`organizers/${pid}`],['series',series.data.id,`series/${series.data.id}`],['event',event.data.id,`events/${event.data.id}`]];
      try {
        for(const [kind,id,path] of targets){
          assert.equal((await call('directory/'+path)).data.interest_count,0);
          const mark={kind,id,saved:true};
          assert.equal((await call('directory/bookmark',mark)).status,401);
          assert.equal((await call('directory/bookmark',mark,tokens.unverified)).status,403);
          const repeated=await Promise.all([0,1,2].map(()=>call('directory/bookmark',mark,tokens['guest.c'])));assert.ok(repeated.every(r=>r.status===200));
          assert.equal((await call('directory/'+path)).data.interest_count,1);
          const second=await call('directory/bookmark',mark,tokens['guest.d']);assert.equal(second.data.interest_count,2);
          const detail=(await call('directory/'+path)).data;assert.equal(detail.interest_count,2);assert.equal(detail.user_id,undefined);assert.equal(detail.interested_users,undefined);
          assert.equal((await call('directory/bookmark',{...mark,saved:false},tokens['guest.d'])).data.interest_count,1);
          assert.equal((await call('directory/bookmark',{...mark,saved:false},tokens['guest.d'])).data.interest_count,1);
        }
        assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.events.filter(e=>e.id===event.data.id).length,1);
        await state.pool.query('UPDATE "user" SET "emailVerified"=false WHERE id=$1',[f.users['guest.c'].id]);
        try {for(const [, ,path] of targets)assert.equal((await call('directory/'+path)).data.interest_count,0);}
        finally {await state.pool.query('UPDATE "user" SET "emailVerified"=true WHERE id=$1',[f.users['guest.c'].id]);}
        const race=await Promise.all([true,false].map(saved=>call('directory/bookmark',{kind:'event',id:event.data.id,saved},tokens['guest.c'])));assert.ok(race.every(r=>r.status===200));
        const remains=(await call('directory/bookmarks',undefined,tokens['guest.c'])).data.events.some(e=>e.id===event.data.id);
        assert.equal((await call(`directory/events/${event.data.id}`)).data.interest_count,remains?1:0);
        await call('directory/bookmark',{kind:'event',id:event.data.id,saved:true},tokens['guest.c']);
        await createDirectory(state.pool);
        assert.equal((await call(`directory/events/${event.data.id}`)).data.interest_count,1);
        assert.equal((await call(`directory/organizers/${pid}/program`)).data.events[0].interest_count,1);
        assert.equal((await call('directory/venue?name=Demo%20Interesse%20Halle')).data.events[0].interest_count,1);
        assert.equal((await call('directory/organizers?q=Demo%20Interesse')).data.items[0].interest_count,1);
        const currentSeries=(await call(`directory/manage?profile_id=${pid}`,undefined,tokens['host.a'])).data.series[0];
        assert.equal((await call('directory/manage/series',{...currentSeries,is_public:false},tokens['host.a'])).status,200);
        assert.equal((await call(`directory/events/${event.data.id}`)).status,404);
        assert.equal((await call(`directory/events/${event.data.id}`,undefined,tokens['host.a'])).data.interest_count,null);
        assert.equal((await call(`directory/series/${series.data.id}`,undefined,tokens['host.a'])).data.interest_count,null);
        assert.equal((await call('directory/manage/preview',{id:event.data.id,audience:'anonymous'},tokens['host.a'])).data.interest_count,null);
        assert.equal((await call('directory/venue?name=Demo%20Interesse%20Halle')).status,404);
        assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.events.some(e=>e.id===event.data.id),false);
        assert.equal((await call('directory/bookmark',{kind:'event',id:event.data.id,saved:true},tokens['guest.c'])).status,404);
        const grant=await call('directory/manage/grant',{kind:'event',id:event.data.id,email:f.users['guest.c'].email},tokens['host.a']);assert.equal(grant.status,200);
        assert.equal((await call(`directory/events/${event.data.id}`,undefined,tokens['guest.c'])).data.interest_count,null);
        assert.equal((await call('directory/bookmark',{kind:'event',id:event.data.id,saved:true},tokens['guest.c'])).data.interest_count,null);
        assert.equal((await call('directory/manage/revoke',{kind:'event',id:grant.data.id,version:grant.data.version},tokens['host.a'])).status,200);
        assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.events.some(e=>e.id===event.data.id),false);
        const currentProfile=(await call(`directory/manage?profile_id=${pid}`,undefined,tokens['host.a'])).data.profile;
        assert.equal((await call('directory/manage/profile',{...currentProfile,is_public:false},tokens['host.a'])).status,200);
        assert.equal((await call(`directory/organizers/${pid}`)).status,404);
        assert.equal((await call(`directory/organizers/${pid}`,undefined,tokens['host.a'])).data.interest_count,null);
        assert.equal((await call('directory/bookmarks',undefined,tokens['guest.c'])).data.profiles.some(p=>p.id===pid),false);
        // An event grant does not create an independent private profile grant.
        assert.equal((await call(`directory/organizers/${pid}`,undefined,tokens['guest.c'])).status,404);
        assert.equal((await call('account/me',undefined,tokens['guest.c'])).data.memberships.length,0);
      } finally {await state.pool.query('DELETE FROM ca_organizer WHERE id=$1',[pid]);}
    });
    await t.test('concurrent host edits cannot silently overwrite a saved form version',async()=>{
      const p=(await call('directory/manage',undefined,tokens['host.a'])).data.profile;
      const results=await Promise.all(['First demo','Second demo'].map(name=>call('directory/manage/profile',{...p,name},tokens['host.a'])));
      assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
      const after=(await call('directory/manage',undefined,tokens['host.a'])).data.profile;
      assert.equal(after.version,p.version+1);
    });
    await t.test('twenty-item server pagination remains duplicate-free and carries the same public Community filter',async()=>{
      for(let index=0;index<22;index++) {
        const id='synthetic-pagination-'+index;
        await state.pool.query('INSERT INTO "user"(id,name,email,"emailVerified","createdAt","updatedAt") VALUES($1,$2,$3,true,NOW(),NOW())',[id,'Demo page '+index,id+'@example.invalid']);
        await state.pool.query('INSERT INTO ca_host VALUES($1,$2)',[id,f.community]);
        const p=(await state.pool.query('INSERT INTO ca_organizer(owner_id,display_name,is_public) VALUES($1,$2,true) RETURNING id',[id,'Demo page '+String(index).padStart(2,'0')])).rows[0];
        await state.pool.query('INSERT INTO ca_profile_community VALUES($1,$2)',[p.id,f.community]);
      }
      const first=(await call(`directory/organizers?q=Demo%20page&community=${f.community}`)).data;
      const second=(await call(`directory/organizers?q=Demo%20page&community=${f.community}&page=2`)).data;
      assert.equal(first.items.length,20);assert.equal(first.has_more,true);assert.equal(second.items.length,2);assert.equal(second.has_more,false);
      assert.equal(new Set([...first.items,...second.items].map(p=>p.id)).size,22);
      await state.pool.query("DELETE FROM \"user\" WHERE id LIKE 'synthetic-pagination-%'");
    });
    await discoveryTests(t,state,f,call,tokens);
    await eventPolicyTests(t,state,f,call,tokens);
    await securityEventPolicyTests(t,state,f,call,tokens);
    await t.test('profile ownership, Community constraints, role removal and transactional rollback',async()=>{
      const m=(await call('directory/manage',undefined,tokens['host.a'])).data.profile;
      const body={...m,community_ids:[f.privateCommunity]};
      assert.equal((await call('directory/manage/profile',body,tokens['host.a'])).status,403);
      assert.equal((await call('directory/manage/profile',{...m,version:0},tokens['host.a'])).status,409);
      assert.equal((await call('directory/manage/profile',{...m,form:[{key:'x',label:'X',required:true},{key:'x',label:'Y',required:false}]},tokens['host.a'])).status,422);
      assert.equal((await call('directory/manage',undefined,tokens['host.a'])).data.profile.version,m.version);
      await state.pool.query('DELETE FROM ca_host WHERE user_id=$1',[f.users['host.b'].id]);
      assert.equal((await call(`directory/organizers/${b}`,undefined,tokens['guest.b'])).status,404);
      assert.equal((await call('directory/manage',undefined,tokens['host.b'])).status,403);
      assert.equal((await call('directory/organizers',undefined,tokens['guest.b'])).data.items.length,1);
    });
    await t.test('signed session revocation also protects directory reads',async()=>{
      assert.equal((await call('auth/sign-out',{},tokens['guest.b'])).status,200);
      assert.equal((await call('directory/organizers',undefined,tokens['guest.b'])).status,401);
      assert.equal((await call(`directory/events/${f.hiddenEvent.id}`,undefined,tokens['guest.b'])).status,401);
    });
    await t.test('reapplying the additive local schema preserves grants and does not assign legacy event ownership',async()=>{
      const old=(await state.pool.query("INSERT INTO ca_event(community_id,title,status,is_public,public_location,location_public) VALUES($1,'Demo Altbestand','published',true,'Demo Altort',true) RETURNING id",[f.community])).rows[0];
      const grants=(await state.pool.query('SELECT id,user_id,active,version FROM ca_series_grant ORDER BY id')).rows;
      await createDirectory(state.pool);
      assert.deepEqual((await state.pool.query('SELECT id,user_id,active,version FROM ca_series_grant ORDER BY id')).rows,grants);
      const row=(await state.pool.query('SELECT profile_id,series_id,is_public FROM ca_event WHERE id=$1',[old.id])).rows[0];assert.deepEqual(row,{profile_id:null,series_id:null,is_public:true});
      assert.deepEqual((await call('directory/venues?q=Altort')).data.items,[{name:'Demo Altort',event_count:1}]);
      assert.equal((await call('directory/venue?name=Demo%20Altort')).data.events[0].id,old.id);
      assert.equal((await call('directory/events?q=Altbestand')).data.events[0].id,old.id);
      assert.equal((await call(`directory/events/${old.id}`)).status,200);
      assert.equal((await call(`directory/organizers/${a}/program`)).data.events.some(e=>e.id===old.id),false);
    });
    await t.test('legacy public venues still enforce event, Community, field, series and assigned-profile protection',async()=>{
      const old=(await state.pool.query("SELECT id FROM ca_event WHERE title='Demo Altbestand'")).rows[0];
      for(const change of [
        {column:'is_public',value:false,restore:true},
        {column:'location_public',value:false,restore:true},
        {column:'status',value:'draft',restore:'published'},
        {column:'community_id',value:f.privateCommunity,restore:f.community},
        {column:'series_id',value:f.series.id,restore:null},
        {column:'profile_id',value:b,restore:null},
      ]) {
        await state.pool.query(`UPDATE ca_event SET ${change.column}=$1 WHERE id=$2`,[change.value,old.id]);
        assert.deepEqual((await call('directory/venues?q=Altort')).data.items,[],change.column);
        assert.equal((await call('directory/venue?name=Demo%20Altort')).status,404,change.column);
        if(change.column!=='location_public') {
          assert.deepEqual((await call('directory/events?q=Altbestand')).data.events,[],change.column);
          assert.equal((await call(`directory/events/${old.id}`)).status,404,change.column);
        }
        await state.pool.query(`UPDATE ca_event SET ${change.column}=$1 WHERE id=$2`,[change.restore,old.id]);
      }
      assert.deepEqual((await call('directory/venues?q=Altort')).data.items,[{name:'Demo Altort',event_count:1}]);
    });
    await t.test('current host responsibility is required even for existing grants and public event fields',async()=>{
      await state.pool.query('DELETE FROM ca_host WHERE user_id=$1',[f.users['host.a'].id]);
      assert.equal((await call(`directory/series/${f.series.id}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await call(`directory/events/${future}`,undefined,tokens['guest.a'])).status,404);
      assert.equal((await call('directory/venues')).data.items.length,0);
      assert.equal((await call('directory/manage/grant',{kind:'series',id:f.series.id,email:f.users['guest.c'].email},tokens['host.a'])).status,403);
    });
  } finally {await new Promise(resolve=>server.close(resolve));await state.pool.end();}
});
