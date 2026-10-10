import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {createRequestLimits} from './request_security.mjs';
import {createSyntheticPretix,syntheticPretixServer} from './synthetic_pretix.mjs';
import {extendedProduct} from './product_scope.mjs';

test('V1: real HTTP, PostgreSQL, standard tickets and deferred feature boundaries',async t=>{
 assert.equal(extendedProduct,false);
 const admin=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_auth'});
 const providerDB=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'pretix_app',database:'community_tickets'});
 const remote=syntheticPretixServer(createSyntheticPretix(providerDB),process.env.CA_PRETIX_TOKEN);
 let state,server;
 const tokens={};let now=Date.now();t.beforeEach(()=>now+=60000);
 const call=(path,body,key)=>new Promise((resolve,reject)=>{
  const req=request(`http://127.0.0.1:${server.address().port}/api/${path}`,{method:body===undefined?'GET':'POST',headers:{Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300','Content-Type':'application/json',Connection:'close',...(key?{Authorization:'Bearer '+tokens[key]}:{})}},res=>{
   let raw='';res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,data:JSON.parse(raw)}));res.on('error',reject);
  });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
 });
 const ok=async(...args)=>{const r=await call(...args);assert.equal(r.status,200,r.data.code);return r.data;};
 try{
  await new Promise(r=>remote.listen(0,'127.0.0.1',r));
  state=await createAuth({env:{...process.env,CA_PRETIX_ORIGIN:`http://127.0.0.1:${remote.address().port}`}});
  server=createApp({...state,requestLimits:createRequestLimits({now:()=>now})});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  for(const key of ['host.a','guest.a','guest.b']){const r=await call('auth/sign-in/email',{email:`${key}@example.invalid`,password:'Synthetic-2026!'});assert.equal(r.status,200);tokens[key]=r.headers['set-auth-token'];assert.ok(tokens[key]);}
  const event=(await admin.query("SELECT id,profile_id,community_id FROM ca_event WHERE title='Demo Ticketabend · pretix'")).rows[0];assert.ok(event);
  const guest=(await admin.query('SELECT id FROM "user" WHERE email=$1',['guest.a@example.invalid'])).rows[0];
  let order;
  await t.test('deferred API routes reject direct GET and POST requests',async()=>{
   for(const [path,body] of [[`directory/events/${event.id}/visit`,{}],['directory/venues',undefined],['directory/preferences',undefined],['directory/preferences',{}],['directory/bookmarks',undefined],['directory/bookmark',{}],['directory/follow',{}],['directory/manage/series',{}],['directory/manage/link',{}],['directory/manage/grant',{kind:'series'}],[`directory/organizers/${event.profile_id}/apply`,{}],['account/social/providers',undefined],['auth/sign-in/social',{provider:'google'}]]){
    const r=await call(path,body,'guest.a');assert.equal(r.status,404,path);
   }
  });
  await t.test('public profile remains readable without granting profile-application access',async()=>{
   assert.equal((await call(`directory/organizers/${event.profile_id}`)).status,200);
   const access=await ok(`directory/organizers/${event.profile_id}/access`,undefined,'guest.a');assert.equal(access.allow_application,false);assert.equal(access.allow_form,false);assert.equal(access.allow_link,false);
   assert.deepEqual((await ok(`directory/organizers/${event.profile_id}/program`)).series,[]);
  });
  await t.test('legacy private profile approval cannot reopen deferred profile access',async()=>{
   const profile=(await admin.query('SELECT id FROM ca_organizer WHERE NOT is_public LIMIT 1')).rows[0];assert.ok(profile);
   await admin.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved')",[profile.id,guest.id]);
   for(const suffix of ['', '/access','/program'])assert.equal((await call(`directory/organizers/${profile.id}${suffix}`,undefined,'guest.a')).status,404);
  });
  await t.test('series-bound events stay hidden even with old public and personal grants',async()=>{
   const series=(await admin.query("INSERT INTO ca_series(profile_id,community_id,title,is_public) VALUES($1,$2,'Synthetic preserved series',true) RETURNING id",[event.profile_id,event.community_id])).rows[0];
   await admin.query('UPDATE ca_event SET series_id=$1 WHERE id=$2',[series.id,event.id]);
   await admin.query('INSERT INTO ca_series_grant(series_id,user_id) VALUES($1,$2)',[series.id,guest.id]);
   try{
    for(const key of ['guest.a','host.a'])assert.equal((await call(`directory/events/${event.id}`,undefined,key)).status,404);
    assert.equal((await call(`directory/series/${series.id}`,undefined,'guest.a')).status,404);
    assert.equal((await call(`ticketing/events/${event.id}/offer`,undefined,'guest.a')).status,404);
    const management=await ok('directory/manage',undefined,'host.a');assert.deepEqual(management.series,[]);assert.deepEqual(management.requests,[]);assert.deepEqual(management.links,[]);assert.ok(!management.events.some(e=>e.id===event.id));
   }finally{await admin.query('UPDATE ca_event SET series_id=NULL WHERE id=$1',[event.id]);}
  });
  await t.test('home is chronological, ignores stored preferences and omits interest counts',async()=>{
   const before=await ok('directory/home',undefined,'guest.a');
   await admin.query('INSERT INTO ca_guest_preferences VALUES($1,$2)',[guest.id,JSON.stringify({music:['pretix']})]);
   await admin.query('INSERT INTO ca_bookmark(user_id,event_id) VALUES($1,$2)',[guest.id,event.id]);
   const after=await ok('directory/home',undefined,'guest.a');
   assert.deepEqual(after.events.map(e=>e.id),before.events.map(e=>e.id));assert.deepEqual(after.events.map(e=>e.starts_at),after.events.map(e=>e.starts_at).sort());
   assert.ok(after.events.every(e=>e.interest_count===null&&!(e.reasons?.length)));assert.deepEqual(after.preferences,{event_types:[],music:[],favorites:[],leisure:[]});
  });
  await t.test('standard checkout requires payment and permits exactly one active personal order',async()=>{
   assert.equal((await ok(`ticketing/events/${event.id}/offer`,undefined,'guest.a')).categories_supported,false);
   order=await ok(`ticketing/events/${event.id}/checkout`,{age_acknowledged:true},'guest.a');assert.ok(order.id);
   assert.equal((await call(`access/events/${event.id}/location`,undefined,'guest.a')).status,404);
   const repeated=await ok(`ticketing/events/${event.id}/checkout`,{age_acknowledged:true},'guest.a');assert.equal(repeated.id,order.id);
   assert.equal((await admin.query("SELECT count(*)::int AS n FROM ca_ticket_order WHERE event_id=$1 AND user_id=$2 AND state='pending'",[event.id,guest.id])).rows[0].n,1);
   await ok(`ticketing/orders/${order.id}/simulate`,{outcome:'success'},'guest.a');
   assert.equal((await call(`access/events/${event.id}/location`,undefined,'guest.a')).status,200);
   assert.equal((await call(`ticketing/orders/${order.id}`,undefined,'guest.b')).status,404);
  });
  await t.test('deferring an existing event hides every catalog path without cancelling its paid order',async()=>{
   await admin.query("UPDATE ca_event SET access_mode='semi_public' WHERE id=$1",[event.id]);
   try{
    assert.equal((await call(`directory/events/${event.id}`,undefined,'guest.a')).status,404);
    assert.equal((await call(`ticketing/events/${event.id}/checkout`,{age_acknowledged:true},'guest.b')).status,404);
    assert.ok(!(await ok('directory/home',undefined,'guest.a')).events.some(e=>e.id===event.id));
    assert.equal((await call(`ticketing/orders/${order.id}`,undefined,'guest.a')).status,200);
    await state.ticketing.reconcile();
    const row=(await admin.query('SELECT state,blocked FROM ca_ticket_order WHERE id=$1',[order.id])).rows[0];assert.equal(row.state,'paid');assert.equal(row.blocked,false);
   }finally{await admin.query("UPDATE ca_event SET access_mode='legacy' WHERE id=$1",[event.id]);}
  });
  await t.test('categories cannot be created or purchased; scanner role still has an owned management path',async()=>{
   assert.equal((await call(`ticketing/events/${event.id}/types`,{},'host.a')).status,404);
   assert.deepEqual((await ok(`ticketing/events/${event.id}/types/manage`,undefined,'host.a')).items,[]);
   assert.equal((await call(`ticketing/events/${event.id}/types/manage`,undefined,'guest.a')).status,404);
   assert.equal((await call(`access/policy/events/${event.id}/scanner`,{email:'guest.b@example.invalid',expires_at:new Date(Date.now()+3600000).toISOString()},'host.a')).status,200);
  });
  await t.test('ticket token and check-in remain account-bound and one-use',async()=>{
   const token=await ok(`access/policy/orders/${order.id}/token`,{},'guest.a');assert.ok(token.token);
   const body={token:token.token,holder_email:'guest.a@example.invalid'};
   const first=await call(`access/policy/events/${event.id}/checkin`,body,'guest.b');assert.equal(first.status,200,first.data.code);
   assert.notEqual((await call(`access/policy/events/${event.id}/checkin`,body,'guest.b')).status,200);
  });
 }finally{
  if(server)await new Promise(r=>server.close(r));
  if(state)await state.pool.end();
  if(remote.listening)await new Promise(r=>remote.close(r));
  await providerDB.end();await admin.end();
 }
});
