import {declareTicketFixture} from './legal_fixtures.mjs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {createRequestLimits} from './request_security.mjs';
import {createSyntheticPretix,syntheticPretixServer} from './synthetic_pretix.mjs';
import {migrateAccess} from './access_migrations.mjs';
import {createTicketing} from './ticketing.mjs';
import {syntheticPretixClient} from './pretix_client.mjs';
import {ticketTypeVisible} from './private_access.mjs';
import {eventJoins} from './event_policy.mjs';
test('roadmap: restricted HTTP, PostgreSQL and independent inventory',async t=>{
 const db=(database,user)=>new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,database,user});
 const admin=db('community_auth','fixture_admin'),padmin=db('community_tickets','fixture_admin'),pdb=db('community_tickets','pretix_app');
 const remote=syntheticPretixServer(createSyntheticPretix(pdb),process.env.CA_PRETIX_TOKEN);await new Promise(r=>remote.listen(0,'127.0.0.1',r));
 const state=await createAuth({env:{...process.env,CA_PRETIX_ORIGIN:`http://127.0.0.1:${remote.address().port}`}});
 let time=Date.now();t.beforeEach(()=>{time+=60000;});let server=createApp({...state,requestLimits:createRequestLimits({now:()=>time})});await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const tokens={},users={};
 const call=(path,body,key)=>new Promise((resolve,reject)=>{const req=request(`http://127.0.0.1:${server.address().port}/api/${path}`,{method:body===undefined?'GET':'POST',headers:{Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300','Content-Type':'application/json',Connection:'close',...(key?{Authorization:'Bearer '+tokens[key]}:{})}},res=>{let raw='';res.setEncoding('utf8');res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(raw),headers:res.headers}));res.on('error',reject);});req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));});
 const ok=async(path,b,key)=>{const r=await call(path,b,key);assert.equal(r.status,200,JSON.stringify(r));if(b&&/^ticketing\/events\/[a-f0-9-]{36}\/config$/.test(path)&&b.mode!=='none')await declareTicketFixture(state.pool,users['host.a'],path.split('/')[2]);return r.data;};const when=h=>new Date(Date.now()+h*3600000).toISOString();
 try{
  for(const key of ['team','host.a','host.b','guest.a','guest.b','guest.c','guest.d']){const r=await call('auth/sign-in/email',{email:key+'@example.invalid',password:'Synthetic-2026!'});assert.equal(r.status,200);tokens[key]=r.headers['set-auth-token'];users[key]=(await admin.query('SELECT * FROM "user" WHERE email=$1',[key+'@example.invalid'])).rows[0];}
  const host=users['host.a'];const profile=(await admin.query('SELECT id FROM ca_organizer WHERE owner_id=$1',[host.id])).rows[0].id;const community=(await admin.query('SELECT community_id FROM ca_host WHERE user_id=$1',[host.id])).rows[0].community_id;
  const other=(await admin.query("INSERT INTO ca_community(name,is_public) VALUES('Synthetic second community',true) RETURNING id")).rows[0].id;await admin.query('INSERT INTO ca_host VALUES($1,$2)',[users['host.b'].id,other]);await ok('access/policy/staff',{community_id:other,email:users['host.b'].email,expires_at:when(24)},'team');await admin.query('INSERT INTO ca_profile_community VALUES($1,$2)',[profile,other]);
  const event=async({privateEvent=false,quota=4,membership=false}={})=>{const e=await ok('directory/manage/event',{profile_id:profile,title:privateEvent?'Synthetic private event':'Synthetic public event',community_id:community,status:'published',is_public:!privateEvent,starts_at:when(24),starts_public:true,public_location:'Synthetic public place',location_public:true,membership_required:membership,exact_location:'SECRET synthetic entrance',event_content:{description:'Synthetic only',ends_at:when(28)}},'host.a');await ok(`ticketing/events/${e.id}/config`,{mode:privateEvent?'approval':'public',quota,price_cents:1200,item_name:'Synthetic ticket',version:0},'host.a');return e.id;};
  const category=async(e,visibility='explicit_grant',rule='visible_authenticated',quota=4)=>ok(`ticketing/events/${e}/types`,{name:'Synthetic category',price_cents:1000,currency:'EUR',quota,visibility_mode:visibility,purchase_rule:rule,communities:visibility==='community_subset'?[community]:[],enabled:true,version:0},'host.a');
  const grant=(type,key)=>ok(`ticketing/types/${type}/grant`,{email:users[key].email,expires_at:when(24),revoked:false},'host.a');const buy=(type,key)=>call(`ticketing/types/${type}/checkout`,{age_acknowledged:true},key);const pay=(oid,key,outcome='success')=>ok(`ticketing/orders/${oid}/simulate`,{outcome},key);const eg=(e,key)=>ok('directory/manage/grant',{kind:'event',id:e,email:users[key].email},'host.a');const member=(c,key)=>admin.query('INSERT INTO ca_membership(community_id,user_id) VALUES($1,$2) ON CONFLICT(community_id,user_id) DO UPDATE SET active=true',[c,users[key].id]);
  await t.test('legal declarations: missing sellers, both purchase paths, immutable snapshots and stale versions',async()=>{
    const e=await event(),c=await category(e,'inherit_event');
    const previousSeller=(await ok(`ticketing/profiles/${profile}/seller`,undefined,'host.a')).seller;
    await admin.query('DELETE FROM ca_ticket_seller WHERE profile_id=$1',[profile]);
    assert.equal((await call(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    assert.equal((await buy(c.id,'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    const missing=await ok(`ticketing/events/${e}/declaration`,undefined,'host.a');
    assert.equal((await call(`ticketing/events/${e}/declaration`,{confirmed:true,version:missing.declaration.version,event_version:missing.event_version,seller_version:0,terms_version:missing.terms_version},'host.a')).data.code,'SELLER_REQUIRED');
    await ok(`ticketing/profiles/${profile}/seller`,{...previousSeller,version:0},'host.a');
    await admin.query('DELETE FROM ca_event_declaration WHERE event_id=$1',[e]);
    assert.equal((await call(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    assert.equal((await buy(c.id,'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    assert.equal((await ok(`ticketing/events/${e}/types`,undefined,'guest.a')).items[0].can_buy,false);
    const d=await ok(`ticketing/events/${e}/declaration`,undefined,'host.a');
    assert.equal((await call(`ticketing/events/${e}/declaration`,{confirmed:true,version:0,event_version:d.event_version,seller_version:d.seller_version,terms_version:d.terms_version},'guest.a')).status,404);
    await ok(`ticketing/events/${e}/declaration`,{confirmed:false,version:0,event_version:d.event_version,seller_version:d.seller_version,terms_version:d.terms_version},'host.a');
    assert.equal((await buy(c.id,'guest.a')).status,409);
    await declareTicketFixture(state.pool,host,e);
    // A previous permission declaration is retained but cannot stand in for the new responsibility acknowledgement.
    await admin.query("UPDATE ca_event_declaration SET terms_version='local-draft-20261009' WHERE event_id=$1 AND version=(SELECT MAX(version) FROM ca_event_declaration WHERE event_id=$1)",[e]);
    const oldTerms=await ok(`ticketing/events/${e}/declaration`,undefined,'host.a');assert.equal(oldTerms.ready,false);
    const staleBody={confirmed:true,version:oldTerms.declaration.version,event_version:oldTerms.event_version,seller_version:oldTerms.seller_version,terms_version:'local-draft-20261009'};
    assert.equal((await call(`ticketing/events/${e}/declaration`,staleBody,'host.a')).data.code,'DECLARATION_CHANGED');
    assert.equal((await call(`ticketing/events/${e}/declaration`,{...staleBody,terms_version:undefined},'host.a')).data.code,'DECLARATION_CHANGED');
    assert.equal((await call(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    assert.equal((await buy(c.id,'guest.a')).data.code,'LEGAL_DECLARATION_REQUIRED');
    await declareTicketFixture(state.pool,host,e);
    assert.equal((await ok(`ticketing/events/${e}/declaration`,undefined,'host.a')).ready,true);
    assert.equal((await admin.query("SELECT COUNT(*)::int AS n FROM ca_event_declaration WHERE event_id=$1 AND terms_version='local-draft-20261009'",[e])).rows[0].n,1);
    const seller=(await ok(`ticketing/profiles/${profile}/seller`,undefined,'host.a')).seller;
    assert.equal((await call(`ticketing/profiles/${profile}/seller`,{...seller,contact:'real@external.test'},'host.a')).data.code,'SYNTHETIC_EMAIL_REQUIRED');
    const o=(await buy(c.id,'guest.a')).data;assert.equal(o.seller_snapshot.contact,seller.contact);assert.equal(o.declaration_snapshot.confirmed,true);assert.equal(o.declaration_snapshot.terms_version,oldTerms.terms_version);
    await pay(o.id,'guest.a');
    await admin.query("UPDATE ca_event_declaration SET terms_version='local-draft-20261009' WHERE event_id=$1 AND version=(SELECT MAX(version) FROM ca_event_declaration WHERE event_id=$1)",[e]);
    const paidAfterTextChange=await ok(`ticketing/orders/${o.id}`,undefined,'guest.a');assert.equal(paidAfterTextChange.blocked,false);assert.equal(paidAfterTextChange.state,'paid');assert.equal(paidAfterTextChange.declaration_snapshot.terms_version,oldTerms.terms_version);
    await declareTicketFixture(state.pool,host,e);
    await ok(`ticketing/profiles/${profile}/seller`,{...seller,contact:'updated@example.invalid'},'host.a');
    assert.equal((await buy(c.id,'guest.b')).data.code,'LEGAL_DECLARATION_REQUIRED');
    const receipt=await ok(`ticketing/orders/${o.id}`,undefined,'guest.a');assert.equal(receipt.blocked,false);assert.equal(receipt.seller_snapshot.contact,seller.contact);
    await assert.rejects(admin.query('UPDATE ca_ticket_order SET seller_snapshot=$2 WHERE id=$1',[o.id,{legal_name:'Forged'}]),{code:'P0001'});
    const source=syntheticPretixClient(`http://127.0.0.1:${remote.address().port}`,process.env.CA_PRETIX_TOKEN);
    await source.refund(o.id,{id:'00000000-0000-4000-8000-000000000987',amount_cents:o.total_cents});
    assert.equal((await ok(`ticketing/orders/${o.id}`,undefined,'guest.a')).state,'refunded');
    assert.equal((await admin.query('SELECT status FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[e,users['guest.a'].id])).rows[0].status,'revoked');
    const current=await ok(`ticketing/events/${e}/declaration`,undefined,'host.a');
    const body={confirmed:true,version:current.declaration.version,event_version:current.event_version,seller_version:current.seller_version,terms_version:current.terms_version};
    const results=await Promise.all([call(`ticketing/events/${e}/declaration`,body,'host.a'),call(`ticketing/events/${e}/declaration`,body,'host.a')]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
    await admin.query('UPDATE ca_event SET version=version+1 WHERE id=$1',[e]);assert.equal((await buy(c.id,'guest.b')).status,409);await declareTicketFixture(state.pool,host,e);
  });
  await t.test('legal reports: anonymous receipts, contact exception, independent roles and no private event oracle',async()=>{
    const e=await event({privateEvent:true});
    const reportBody={event_id:e,reference:`events/${e}`,details:'Synthetic permit uncertainty',name:'Synthetic reporter',email:'reporter@example.invalid',good_faith:true};
    const a=await ok('legal/reports',reportBody);
    const b=await ok('legal/reports',{...reportBody,event_id:'00000000-0000-4000-8000-000000000123',reference:'events/00000000-0000-4000-8000-000000000123'});
    assert.deepEqual(Object.keys(a),Object.keys(b));assert.equal(a.received,true);assert.equal(JSON.stringify(a).includes('Synthetic private'),false);
    assert.equal((await call('legal/reports')).status,401);assert.equal((await call('legal/reports',undefined,'host.a')).status,403);assert.equal((await call(`legal/reports/${a.reference}`,undefined,'guest.a')).status,403);
    assert.equal((await call('legal/reports',{...reportBody,good_faith:false})).status,422);
    assert.equal((await call('legal/reports',{...reportBody,details:'x'.repeat(4001)})).status,422);
    assert.equal((await call('legal/reports',{...reportBody,reference:'https://example.invalid/#token=secret'})).data.code,'PRIVATE_LINK_DENIED');
    await ok(`legal/reports/${b.reference}/assign`,{version:0},'team');
    await ok(`legal/reports/${b.reference}/decision`,{action:'no_action',basis:'unsubstantiated',reason:'Synthetic unavailable content reference; no restriction justified',version:1},'team');
    const reviewed=await ok(`legal/reports/${b.reference}`,undefined,'team');assert.equal(reviewed.status,'decided');assert.equal(reviewed.actions[0].action,'no_action');
    const exception=await ok('legal/reports',{reference:'events/synthetic-reference',details:'Synthetic child-safety report',contact_exception:true,name:'',email:'',good_faith:true});assert.equal(exception.received,true);
    assert.equal((await admin.query('SELECT legal_state FROM ca_event WHERE id=$1',[e])).rows[0].legal_state,'active');
    const inbox=await ok('legal/mailbox',undefined,'team');assert.ok(inbox.items.some(n=>n.report_id===a.reference&&n.kind==='received'&&n.synthetic));
    await admin.query('INSERT INTO ca_team VALUES($1) ON CONFLICT DO NOTHING',[host.id]);
    await ok(`legal/reports/${a.reference}/assign`,{version:0},'host.a');
    assert.equal((await call(`legal/reports/${a.reference}/decision`,{event_id:e,version:1,event_legal_version:0,action:'sales_paused',basis:'clarification',reason:'Synthetic clarification'},'host.a')).data.code,'INDEPENDENT_REVIEW_REQUIRED');
    assert.equal((await call(`legal/reports/${a.reference}/decision`,{event_id:e,version:1,action:'no_action',basis:'unsubstantiated',reason:'Synthetic self review'},'host.a')).data.code,'INDEPENDENT_REVIEW_REQUIRED');
    await admin.query('DELETE FROM ca_team WHERE user_id=$1',[host.id]);
  });
  await t.test('legal sales pause stops pending handoffs; paid tickets survive, delayed payments refund, reopening is explicit',async()=>{
    const e=await event(),c=await category(e,'inherit_event');const paid=(await buy(c.id,'guest.a')).data;await pay(paid.id,'guest.a');const pending=(await buy(c.id,'guest.b')).data;
    await admin.query("INSERT INTO ca_event_interest(event_id,user_id,status) VALUES($1,$2,'purchase_eligible')",[e,users['guest.b'].id]);
    const nonce='b'.repeat(64);const handoff=await ok(`ticketing/orders/${pending.id}/handoff`,{browser_nonce:nonce},'guest.b');
    const report=await ok('legal/reports',{event_id:e,reference:`events/${e}`,details:'Synthetic unclear permission',name:'Synthetic reporter',email:'reporter@example.invalid',good_faith:true});
    await ok(`legal/reports/${report.reference}/assign`,{version:0},'team');
    const decision={event_id:e,version:1,event_legal_version:0,action:'sales_paused',basis:'clarification',reason:'Synthetic permit clarification'};
    const simultaneous=await Promise.all([call(`legal/reports/${report.reference}/decision`,decision,'team'),call(`legal/reports/${report.reference}/decision`,decision,'team')]);assert.deepEqual(simultaneous.map(r=>r.status).sort(),[200,409]);
    assert.equal((await buy(c.id,'guest.c')).data.code,'LEGAL_SALES_PAUSED');assert.equal((await call(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.c')).status,409);
    assert.equal((await call(`ticketing/orders/${pending.id}/redeem`,{browser_nonce:nonce,code:handoff.code},'guest.b')).status,409);
    assert.equal((await call(`ticketing/orders/${pending.id}/simulate`,{outcome:'success'},'guest.b')).status,409);
    assert.equal((await ok(`ticketing/orders/${paid.id}`,undefined,'guest.a')).blocked,false);
    await ok(`access/policy/events/${e}/scanner`,{email:users['guest.c'].email,expires_at:when(1)},'host.a');const token=await ok(`access/policy/orders/${paid.id}/token`,{},'guest.a');await ok(`access/policy/events/${e}/checkin`,{token:token.token,holder_email:users['guest.a'].email},'guest.c');
    const late=await pay(pending.id,'guest.b','late');assert.equal(late.blocked,true);assert.ok((await ok(`ticketing/profiles/${profile}/refunds`,undefined,'host.a')).items.some(r=>r.order_id===pending.id));
    assert.equal((await admin.query('SELECT status FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[e,users['guest.b'].id])).rows[0].status,'purchase_eligible');
    const paused=await ok(`legal/reports/${report.reference}`,undefined,'team');assert.equal(paused.event.legal_version,1);
    const action=paused.actions[0];assert.equal((await ok('legal/mine',undefined,'host.a')).items.some(a=>a.id===action.id),true);
    await ok(`legal/actions/${action.id}/statement`,{details:'Synthetic request for reconsideration'},'host.a');
    const open=await ok(`legal/reports/${report.reference}`,undefined,'team');assert.equal(open.status,'open');assert.equal(open.statements.length,1);
    await ok(`legal/reports/${report.reference}/decision`,{...decision,version:open.version,event_legal_version:1,action:'active',basis:'resolved',reason:'Synthetic clarification completed'},'team');
    assert.equal((await ok(`ticketing/orders/${pending.id}`,undefined,'guest.b')).blocked,true);
    assert.equal((await buy(c.id,'guest.c')).status,200);
    const current=await ok(`legal/reports/${report.reference}`,undefined,'team');
    await ok(`legal/reports/${report.reference}/decision`,{...decision,version:current.version,event_legal_version:2,action:'blocked',basis:'prohibition',reason:'Synthetic confirmed prohibition'},'team');
    assert.equal((await call(`directory/events/${e}`,undefined,'guest.a')).status,404);
    assert.equal((await ok(`ticketing/orders/${paid.id}`,undefined,'guest.a')).blocked,true);
    assert.equal((await call(`access/policy/orders/${paid.id}/token`,{},'guest.a')).status,404);
    const jobs=(await ok(`ticketing/profiles/${profile}/refunds`,undefined,'host.a')).items.filter(r=>r.order_id===paid.id&&r.state==='review');assert.equal(jobs.length,1);
    await ok(`ticketing/refunds/${jobs[0].id}/approve`,{amount_cents:paid.total_cents},'host.a');await ok(`ticketing/refunds/${jobs[0].id}/approve`,{amount_cents:paid.total_cents},'host.a');
    assert.equal((await ok(`ticketing/orders/${paid.id}`,undefined,'guest.a')).refunded_cents,paid.total_cents);
  });
  await t.test('legal pause and in-flight payment serialize rights and preserve personal grants',async()=>{
    const e=await event();const o=await ok(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.d');
    const provider=syntheticPretixClient(`http://127.0.0.1:${remote.address().port}`,process.env.CA_PRETIX_TOKEN);
    let started,release;const start=new Promise(r=>started=r),gate=new Promise(r=>release=r);
    const racing=createTicketing(state.pool,{...provider,settle:async(...args)=>{started();await gate;return provider.settle(...args);}});
    const paying=racing.simulate(users['guest.d'],o.id,{outcome:'success'});await start;
    try {
      const r=await ok('legal/reports',{event_id:e,reference:`events/${e}`,details:'Synthetic pending payment clarification',name:'Synthetic reporter',email:'reporter@example.invalid',good_faith:true});
      await ok(`legal/reports/${r.reference}/assign`,{version:0},'team');
      await ok(`legal/reports/${r.reference}/decision`,{event_id:e,version:1,event_legal_version:0,action:'sales_paused',basis:'clarification',reason:'Synthetic review'},'team');
    } finally {release();}
    const paid=await paying;assert.equal(paid.state,'paid');assert.equal(paid.blocked,true);assert.equal(paid.admission_state,'admission_hold');
    assert.equal((await admin.query("SELECT COUNT(*)::int AS n FROM ca_ticket_refund WHERE order_id=$1 AND state='review'",[o.id])).rows[0].n,1);
  });
  await t.test('legal proof survives event deletion and report-state replay cannot erase review history',async()=>{
    const e=await event();const o=await ok(`ticketing/events/${e}/checkout`,{age_acknowledged:true},'guest.d');await pay(o.id,'guest.d');
    const r=await ok('legal/reports',{event_id:e,reference:`events/${e}`,details:'Synthetic cancellation report',name:'Synthetic reporter',email:'reporter@example.invalid',good_faith:true});await ok(`legal/reports/${r.reference}/assign`,{version:0},'team');
    await ok(`legal/reports/${r.reference}/decision`,{event_id:e,version:1,event_legal_version:0,action:'blocked',basis:'cancellation',reason:'Synthetic cancellation'},'team');
    await admin.query('DELETE FROM ca_event WHERE id=$1',[e]);
    const receipt=await ok(`ticketing/orders/${o.id}`,undefined,'guest.d');assert.ok(receipt.seller_snapshot.legal_name);assert.equal(receipt.declaration_snapshot.confirmed,true);
    assert.ok((await ok(`ticketing/profiles/${profile}/refunds`,undefined,'host.a')).items.some(r=>r.order_id===o.id));
    assert.equal((await ok(`legal/reports/${r.reference}`,undefined,'team')).actions.length,1);
  });
  await t.test('A01–A05: follower/category grant cannot reveal event; event grant cannot reveal private organizer',async()=>{
   const hidden=(await admin.query("INSERT INTO ca_organizer(owner_id,display_name,is_public) VALUES($1,'SECRET profile',false) RETURNING id",[host.id])).rows[0].id;await admin.query('INSERT INTO ca_profile_community VALUES($1,$2)',[hidden,community]);await admin.query('INSERT INTO ca_community_publisher VALUES($1,$2,true)',[hidden,community]);
   const e=await event({privateEvent:true});await admin.query('UPDATE ca_event SET profile_id=$2 WHERE id=$1',[e,hidden]);const c=await category(e);assert.equal((await call(`directory/events/${e}`)).status,404);
   await admin.query('INSERT INTO ca_community_follow VALUES($1,$2)',[users['guest.a'].id,community]);assert.equal((await call(`directory/events/${e}`,undefined,'guest.a')).status,404);await grant(c.id,'guest.a');assert.equal((await call(`ticketing/events/${e}/types`,undefined,'guest.a')).data.items.length,0);assert.equal((await buy(c.id,'guest.a')).status,404);
   await eg(e,'guest.a');assert.equal((await call(`directory/events/${e}`,undefined,'guest.a')).status,200);assert.equal((await call(`directory/organizers/${hidden}`,undefined,'guest.a')).status,404);assert.equal((await admin.query('SELECT 1 FROM ca_membership WHERE user_id=$1',[users['guest.a'].id])).rowCount,0);assert.equal((await admin.query('SELECT 1 FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[hidden,users['guest.a'].id])).rowCount,0);assert.equal((await call(`ticketing/events/${e}/types`,undefined,'guest.a')).data.items[0].id,c.id);
  });
  await t.test('A06–A07: approval and one active private ticket across categories',async()=>{const e=await event({privateEvent:true});const a=await category(e,'inherit_event','event_approval_required'),b=await category(e,'inherit_event','event_approval_required');await eg(e,'guest.b');await admin.query("INSERT INTO ca_event_interest(event_id,user_id,status) VALUES($1,$2,'pending')",[e,users['guest.b'].id]);assert.equal((await buy(a.id,'guest.b')).data.code,'PURCHASE_APPROVAL_REQUIRED');await admin.query("UPDATE ca_event_interest SET status='purchase_eligible' WHERE event_id=$1 AND user_id=$2",[e,users['guest.b'].id]);const results=await Promise.all([buy(a.id,'guest.b'),buy(b.id,'guest.b')]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);await pay(results.find(r=>r.status===200).data.id,'guest.b');});
  await t.test('A08: blocking A preserves approved B or a personal event grant',async()=>{const e=await event({privateEvent:true,membership:true});await member(community,'guest.c');await member(other,'guest.c');await ok(`access/policy/events/${e}/share`,{community_id:other,grants_visibility:true},'host.a');assert.equal((await call(`access/policy/events/${e}/approve-share`,{community_id:other,approved:true},'host.a')).status,404);await ok(`access/policy/events/${e}/approve-share`,{community_id:other,approved:true},'host.b');await admin.query("INSERT INTO ca_community_block VALUES($1,$2,'revoked')",[community,users['guest.c'].id]);assert.equal((await call(`directory/events/${e}`,undefined,'guest.c')).status,200);await admin.query('UPDATE ca_membership SET active=false WHERE community_id=$1 AND user_id=$2',[other,users['guest.c'].id]);assert.equal((await call(`directory/events/${e}`,undefined,'guest.c')).status,404);await eg(e,'guest.c');assert.equal((await call(`directory/events/${e}`,undefined,'guest.c')).status,200);});
  await t.test('A09–A11: scoped case access, independent permanent review and appeal',async()=>{for(const key of ['guest.a','guest.b'])await ok('access/policy/staff',{community_id:other,email:users[key].email,expires_at:when(24)},'team');assert.equal((await call('access/policy/staff',{community_id:community,email:users['guest.a'].email,expires_at:when(24)},'host.a')).status,403);assert.equal((await call('access/policy/restrictions',{community_id:community,email:users['guest.d'].email,expires_at:when(1)},'guest.a')).status,404);const r=await ok('access/policy/restrictions',{community_id:other,email:users['guest.d'].email,expires_at:when(1)},'guest.a');const c=await ok('access/policy/cases',{community_id:other,email:users['guest.d'].email,details:'SECRET synthetic case',restriction_id:r.id},'guest.a');assert.equal((await call(`access/policy/cases/${c.id}`,undefined,'host.a')).status,404);assert.equal((await call(`access/policy/cases/${c.id}/review`,{},'guest.a')).status,403);await ok(`access/policy/cases/${c.id}/review`,{},'guest.b');assert.equal((await admin.query('SELECT expires_at FROM ca_restriction WHERE id=$1',[r.id])).rows[0].expires_at,null);await ok(`access/policy/cases/${c.id}/appeal`,{details:'Synthetic appeal'},'guest.d');assert.equal((await call('access/policy/cases',{community_id:other,email:users['guest.d'].email,details:'x',assigned_to:'fake'},'guest.a')).status,422);});
  await t.test('A12–A13, A15: concurrent categories share capacity; client prices and quantities rejected',async()=>{const e=await event({quota:1});const a=await category(e,'inherit_event'),b=await category(e,'inherit_event');assert.equal((await call(`ticketing/types/${a.id}/checkout`,{age_acknowledged:true,quantity:2},'guest.a')).status,422);assert.equal((await call(`ticketing/types/${a.id}/checkout`,{age_acknowledged:true,total_cents:1,currency:'USD'},'guest.a')).status,422);const results=await Promise.all([buy(a.id,'guest.a'),buy(b.id,'guest.b')]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);assert.equal((await padmin.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1 AND state='pending'",[e])).rows[0].n,1);await assert.rejects(admin.query('UPDATE ca_ticket_order SET event_id=$2 WHERE event_id=$1',[e,'00000000-0000-4000-8000-000000000001']),{code:'23503'});});
  await t.test('A14, A16: expired reservation, late payment and repeated refund',async()=>{const e=await event({quota:1});const c=await category(e,'inherit_event');const o=(await buy(c.id,'guest.c')).data;await padmin.query("UPDATE pt_order SET expires_at=NOW()-INTERVAL '1 second' WHERE id=$1",[o.id]);await state.ticketing.reconcile();assert.equal((await buy(c.id,'guest.d')).status,200);const late=await pay(o.id,'guest.c','late');assert.equal(late.state,'paid');assert.equal(late.blocked,true);const task=(await admin.query('SELECT * FROM ca_ticket_refund WHERE order_id=$1',[o.id])).rows[0];const underlying=createSyntheticPretix(pdb);await underlying.refund(o.id,{id:task.id,amount_cents:1000});await underlying.refund(o.id,{id:task.id,amount_cents:1000});assert.equal((await padmin.query('SELECT COUNT(*)::int AS n FROM pt_refund WHERE order_id=$1',[o.id])).rows[0].n,1);});
  await t.test('A17, A21: simultaneous payment and block retain receipt with admission hold',async()=>{const e=await event();const c=await category(e,'inherit_event');const o=(await buy(c.id,'guest.a')).data;await Promise.all([pay(o.id,'guest.a'),ok('access/policy/restrictions',{event_id:e,email:users['guest.a'].email,expires_at:when(1)},'host.a')]);await state.ticketing.reconcile();const receipt=await ok(`ticketing/orders/${o.id}`,undefined,'guest.a');assert.equal(receipt.blocked,true);assert.equal(receipt.admission_state,'admission_hold');assert.equal(receipt.total_cents,1000);assert.equal(JSON.stringify(receipt).includes('SECRET'),false);assert.equal((await call(`directory/events/${e}`,undefined,'guest.a')).status,404);assert.equal((await call(`ticketing/orders/${o.id}`,undefined,'guest.b')).status,404);});
  await t.test('A18–A19, A25: paid private category survives community departure and sales closure; exactly one scan',async()=>{await admin.query('DELETE FROM ca_community_block WHERE community_id=$1 AND user_id=$2',[community,users['guest.c'].id]);await member(community,'guest.c');const e=await event();const c=await category(e,'community_subset');const o=(await buy(c.id,'guest.c')).data;await pay(o.id,'guest.c');await admin.query('UPDATE ca_membership SET active=false WHERE community_id=$1 AND user_id=$2',[community,users['guest.c'].id]);await admin.query("UPDATE ca_ticket_type SET enabled=false,sales_end=NOW()-INTERVAL '1 second' WHERE id=$1",[c.id]);await state.ticketing.reconcile();assert.equal((await ok(`ticketing/orders/${o.id}`,undefined,'guest.c')).blocked,false);for(const key of ['guest.a','guest.b'])await ok(`access/policy/events/${e}/scanner`,{email:users[key].email,expires_at:when(1)},'host.a');const token=await ok(`access/policy/orders/${o.id}/token`,{},'guest.c');assert.match(token.token,/^[a-f0-9]{64}$/);assert.equal((await admin.query('SELECT 1 FROM ca_ticket_token WHERE digest=$1',[token.token])).rowCount,0);assert.equal((await call(`access/policy/events/${e}/checkin`,{token:token.token,holder_email:users['guest.b'].email},'guest.a')).status,404);const body={token:token.token,holder_email:users['guest.c'].email};const results=await Promise.all(['guest.a','guest.b'].map(k=>call(`access/policy/events/${e}/checkin`,body,k)));assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);assert.equal((await call(`access/policy/events/${e}/checkin`,body,'guest.d')).status,404);});
  await t.test('A20, A24: SQL browser role denied; service cannot grant its own team rights',async()=>{await admin.query('CREATE ROLE ca_browser_test NOLOGIN');await admin.query('GRANT USAGE ON SCHEMA public TO ca_browser_test');const client=await admin.connect();try{await client.query('SET ROLE ca_browser_test');for(const sql of ['SELECT * FROM ca_ticket_type','SELECT * FROM ca_organizer_member','UPDATE ca_membership SET active=true','DELETE FROM ca_restriction','INSERT INTO ca_team VALUES(\'fake\')'])await assert.rejects(client.query(sql),{code:'42501'});}finally{await client.query('RESET ROLE');client.release();}await assert.rejects(state.pool.query('CREATE TABLE ca_forbidden(id int)'),{code:'42501'});await assert.rejects(state.pool.query('INSERT INTO ca_team VALUES($1)',[users['guest.a'].id]),{code:'42501'});const before=(await admin.query('SELECT * FROM ca_access_migration ORDER BY version')).rows;await migrateAccess(admin);assert.deepEqual((await admin.query('SELECT * FROM ca_access_migration ORDER BY version')).rows,before);});
  await t.test('scanner expiration and foreign event deny entry; used admission survives reconciliation',async()=>{
    const e=await event(),f=await event();const c=await category(e,'inherit_event');const o=(await buy(c.id,'guest.b')).data;await pay(o.id,'guest.b');await ok(`access/policy/events/${e}/scanner`,{email:users['guest.c'].email,expires_at:when(1)},'host.a');await ok(`access/policy/events/${f}/scanner`,{email:users['guest.c'].email,expires_at:when(1)},'host.a');
    const token=await ok(`access/policy/orders/${o.id}/token`,{},'guest.b');const b={token:token.token,holder_email:users['guest.b'].email};assert.equal((await call(`access/policy/events/${f}/checkin`,b,'guest.c')).status,404);await admin.query("UPDATE ca_scanner SET expires_at=NOW()-INTERVAL '1 second' WHERE event_id=$1",[e]);assert.equal((await call(`access/policy/events/${e}/checkin`,b,'guest.c')).status,404);await ok(`access/policy/events/${e}/scanner`,{email:users['guest.c'].email,expires_at:when(1)},'host.a');await ok(`access/policy/events/${e}/checkin`,b,'guest.c');await state.ticketing.reconcile();assert.equal((await ok(`ticketing/orders/${o.id}`,undefined,'guest.b')).admission_state,'used');
  });
  await t.test('online admission reconciles a remote refund before token use',async()=>{
    const e=await event(),c=await category(e,'inherit_event');const o=(await buy(c.id,'guest.b')).data;await pay(o.id,'guest.b');
    await ok(`access/policy/events/${e}/scanner`,{email:users['guest.c'].email,expires_at:when(1)},'host.a');
    const token=await ok(`access/policy/orders/${o.id}/token`,{},'guest.b');
    await padmin.query("UPDATE pt_order SET state='refunded',blocked=true,refunded_cents=total_cents,fee_refunded_cents=fee_cents WHERE id=$1",[o.id]);
    assert.equal((await admin.query('SELECT state FROM ca_ticket_order WHERE id=$1',[o.id])).rows[0].state,'paid');
    assert.equal((await call(`access/policy/events/${e}/checkin`,{token:token.token,holder_email:users['guest.b'].email},'guest.c')).status,404);
    assert.equal((await admin.query('SELECT 1 FROM ca_checkin WHERE order_id=$1',[o.id])).rowCount,0);
    assert.equal((await admin.query('SELECT state FROM ca_ticket_order WHERE id=$1',[o.id])).rows[0].state,'refunded');
  });
  await t.test('retention is an authorized aggregate preview without mutation',async()=>{
    const counts=async()=>(await admin.query('SELECT (SELECT COUNT(*) FROM ca_membership) AS memberships,(SELECT COUNT(*) FROM ca_restriction) AS restrictions,(SELECT COUNT(*) FROM ca_ticket_order) AS orders,(SELECT COUNT(*) FROM ca_event_location) AS addresses')).rows[0];const before=await counts();assert.equal((await call('access/policy/retention-preview',{before:when(72)},'host.a')).status,403);const r=await ok('access/policy/retention-preview',{before:when(72)},'team');assert.equal(r.dry_run,true);assert.equal(r.execution_enabled,false);assert.equal(r.external_copies_verified,false);assert.ok(r.counts.private_addresses>0);assert.ok(r.counts.financial_records>0);assert.deepEqual(await counts(),before);assert.equal((await call('access/policy/retention-preview',{before:when(72),execute:true},'team')).status,422);
  });
  await t.test('community administration and publication belong to assigned moderators, never publisher role alone',async()=>{
    await admin.query('DELETE FROM ca_community_staff WHERE community_id=$1 AND user_id=$2',[community,host.id]);
    assert.equal((await call(`access/communities/${community}`,undefined,'host.a')).status,403);assert.equal((await call(`access/communities/${community}/invite`,{email:users['guest.d'].email},'host.a')).status,403);
    const e=await ok('directory/manage/event',{profile_id:profile,title:'Synthetic publication awaiting moderation',community_id:community,status:'published',is_public:true,starts_at:when(24),starts_public:true,public_location:'Synthetic venue',location_public:true,membership_required:false,event_content:{description:'Synthetic event',ends_at:when(28)}},'host.a');assert.equal((await call(`directory/events/${e.id}`)).status,404);assert.equal((await call(`access/policy/events/${e.id}/approve-share`,{community_id:community,approved:true},'host.a')).status,404);
    await ok('access/policy/staff',{community_id:community,email:users['guest.c'].email,expires_at:when(24)},'team');await ok(`access/policy/events/${e.id}/approve-share`,{community_id:community,approved:true},'guest.c');assert.equal((await call(`directory/events/${e.id}`)).status,200);
    const rules=await ok(`access/policy/communities/${community}/rules`,{rules:'Synthetic community rules version one',version:0},'guest.c');await ok(`access/communities/${community}/form`,{fields:[{key:'interest',label:'Was interessiert dich an unserem Programm?',required:true}],version:0,host_contact:'Synthetic moderation contact'},'guest.c');
    const link=await ok(`access/communities/${community}/invite`,{email:users['guest.d'].email},'guest.c');const preview=await ok('access/invitations/preview',{token:link.token},'guest.d');assert.equal(preview.rule.id,rules.id);assert.equal((await call('access/applications',{token:link.token,version:1,answers:{interest:'Synthetic answer'}},'guest.d')).data.code,'RULES_CHANGED');const application=await ok('access/applications',{token:link.token,version:1,rule_version_id:rules.id,answers:{interest:'Synthetic answer'}},'guest.d');assert.equal((await call(`access/applications/${application.id}/decide`,{status:'approved'},'host.a')).status,403);await ok(`access/applications/${application.id}/decide`,{status:'approved'},'guest.c');assert.equal((await admin.query('SELECT approved_by FROM ca_membership WHERE community_id=$1 AND user_id=$2',[community,users['guest.d'].id])).rows[0].approved_by,users['guest.c'].id);
    await ok(`access/policy/communities/${community}/rules`,{rules:'Synthetic rules version two',version:1},'guest.c');assert.equal((await admin.query('SELECT rules FROM ca_community_rule_version WHERE id=$1',[rules.id])).rows[0].rules,'Synthetic community rules version one');await admin.query("UPDATE ca_community_staff SET expires_at=NOW()-INTERVAL '1 second' WHERE community_id=$1 AND user_id=$2",[community,users['guest.c'].id]);assert.equal((await call(`access/communities/${community}`,undefined,'guest.c')).status,403);assert.equal((await call('access/invitations/preview',{token:link.token},'guest.d')).status,404);
    assert.equal((await call(`access/policy/communities/${community}/publishers`,{profile_id:profile,enabled:true},'host.a')).status,404);
    await ok('access/policy/staff',{community_id:community,email:users['guest.c'].email,expires_at:when(24)},'team');await ok(`access/policy/communities/${community}/publishers`,{profile_id:profile,enabled:false},'guest.c');await admin.query('INSERT INTO ca_profile_community VALUES($1,$2) ON CONFLICT DO NOTHING',[profile,community]);assert.equal((await call(`directory/events/${e.id}`)).status,404);await ok(`access/policy/communities/${community}/publishers`,{profile_id:profile,enabled:true},'guest.c');assert.equal((await call(`access/communities/${community}`,undefined,'host.a')).status,403);
    await ok('access/policy/staff',{community_id:community,email:host.email,expires_at:when(24)},'team');
  });
  await t.test('phase 10: access query plan runs as the restricted backend role',async()=>{
    const e=await event(),c=await category(e,'explicit_grant');await grant(c.id,'guest.d');const result=await state.pool.query(`EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT tt.id ${eventJoins} JOIN ca_ticket_type tt ON tt.event_id=e.id WHERE tt.id=$2 AND ${ticketTypeVisible}`,[users['guest.d'].id,c.id]);const plan=result.rows[0]['QUERY PLAN'][0];assert.equal(plan.Plan['Actual Rows'],1);assert.ok(plan['Execution Time']<1000);console.log(JSON.stringify({query:'private-category-current-access',planning_ms:plan['Planning Time'],execution_ms:plan['Execution Time'],rows:plan.Plan['Actual Rows'],fixture_only:true}));
  });
  await t.test('phase 2: upgrade old synthetic rows then reapply migration without changes',async()=>{await admin.query('CREATE SCHEMA ca_upgrade_test');const upgrade=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,database:'community_auth',user:'fixture_admin',options:'-c search_path=ca_upgrade_test'});try{await upgrade.query('CREATE TABLE "user"(id text PRIMARY KEY)');for(const name of ['directory.sql','discovery.sql'])await upgrade.query(await readFile(new URL('./'+name,import.meta.url),'utf8'));await upgrade.query('CREATE TABLE ca_access_migration(version text PRIMARY KEY,digest text NOT NULL)');for(const version of ['0001-access-flow','0002-ticketing']){const sql=await readFile(new URL(`./migrations/${version}.sql`,import.meta.url),'utf8');await upgrade.query(sql);await upgrade.query('INSERT INTO ca_access_migration VALUES($1,$2)',[version,createHash('sha256').update(sql).digest('hex')]);}await upgrade.query("INSERT INTO \"user\" VALUES('synthetic-upgrade')");const c=(await upgrade.query("INSERT INTO ca_community(name) VALUES('Synthetic upgrade') RETURNING id")).rows[0].id;await upgrade.query('INSERT INTO ca_membership(community_id,user_id) VALUES($1,$2)',[c,'synthetic-upgrade']);const priorProfile=(await upgrade.query("INSERT INTO ca_organizer(owner_id,display_name) VALUES('synthetic-upgrade','Synthetic old profile') RETURNING id")).rows[0].id;await upgrade.query("INSERT INTO ca_profile_link(profile_id,user_id,digest,expires_at) VALUES($1,'synthetic-upgrade','synthetic-upgrade-digest',NOW()+INTERVAL '1 day')",[priorProfile]);await migrateAccess(upgrade);assert.equal((await upgrade.query('SELECT issuer_id FROM ca_profile_link')).rows[0].issuer_id,'synthetic-upgrade');await migrateAccess(upgrade);assert.equal((await upgrade.query('SELECT active,accepted_at IS NOT NULL AS accepted FROM ca_membership')).rows[0].accepted,true);}finally{await upgrade.end();}});
  await t.test('provider currency and category mismatch cannot change a confirmed payment',async()=>{
    const o=(await admin.query("SELECT id FROM ca_ticket_order WHERE state='paid' LIMIT 1")).rows[0];const original=createSyntheticPretix(pdb);const before=await original.read(o.id);
    for(const invalid of [{currency:'USD'},{type_id:'00000000-0000-4000-8000-000000000001'}]){const forged=createTicketing(state.pool,{...original,synthetic:true,read:async()=>({...before,...invalid})});await assert.rejects(forged.webhook({order_id:o.id}),{code:'TICKET_RESPONSE_INVALID'});}
    assert.equal((await admin.query('SELECT state FROM ca_ticket_order WHERE id=$1',[o.id])).rows[0].state,'paid');
  });
  await t.test('shared organizer invitation: acceptance, exact profile scope, concurrent edits and revocation',async()=>{
    await admin.query('DELETE FROM ca_community_staff WHERE user_id=$1',[users['guest.c'].id]);
    const memberPath=`access/policy/organizers/${profile}/members`;
    const invite=await ok(memberPath,{email:users['guest.c'].email,version:0},'host.a');
    assert.equal((await call(memberPath,undefined,'guest.c')).status,404);
    assert.equal((await call(`access/policy/organizer-members/${invite.id}/accept`,{version:invite.version},'guest.d')).status,404);
    const accepts=await Promise.all([call(`access/policy/organizer-members/${invite.id}/accept`,{version:invite.version},'guest.c'),call(`access/policy/organizer-members/${invite.id}/accept`,{version:invite.version},'guest.c')]);
    assert.equal(accepts.filter(r=>r.status===200).length,1);const active=accepts.find(r=>r.status===200).data;
    const managed=await ok('directory/manage',undefined,'guest.c');assert.equal(managed.profile.id,profile);assert.equal(managed.profile.is_owner,false);
    assert.equal((await ok('account/me',undefined,'guest.c')).is_host,true);
    assert.equal((await call(memberPath,{email:users['guest.d'].email,version:0},'guest.c')).status,404);
    assert.equal((await call(`ticketing/profiles/${profile}/connection`,{connected:false},'guest.c')).data.code,'OWNER_REQUIRED');
    assert.equal((await call(`access/communities/${community}`,undefined,'guest.c')).status,403);
    assert.equal((await call('access/policy/staff',{community_id:community,email:users['guest.d'].email,expires_at:when(1)},'guest.c')).status,403);
    assert.equal((await call(memberPath,{email:users['host.a'].email,version:0},'host.a')).data.code,'OWNER_PROTECTED');
    const another=(await admin.query("INSERT INTO ca_organizer(owner_id,display_name) VALUES($1,'Synthetic unrelated organizer') RETURNING id",[host.id])).rows[0].id;
    await admin.query('INSERT INTO ca_profile_community VALUES($1,$2)',[another,community]);assert.equal((await call(`access/policy/organizers/${another}/members`,undefined,'guest.c')).status,404);
    const body={...managed.profile,id:profile,name:'Synthetic joint edit',community_ids:[community],version:managed.profile.version,owner_id:users['guest.c'].id};
    await admin.query('INSERT INTO ca_host VALUES($1,$2)',[users['guest.c'].id,other]);
    assert.equal((await call('directory/manage/profile',{...body,community_ids:[other]},'guest.c')).status,403);
    await admin.query('DELETE FROM ca_host WHERE user_id=$1 AND community_id=$2',[users['guest.c'].id,other]);
    const edits=await Promise.all([call('directory/manage/profile',body,'guest.c'),call('directory/manage/profile',{...body,name:'Synthetic owner edit'},'host.a')]);assert.deepEqual(edits.map(r=>r.status).sort(),[200,409]);
    assert.equal((await admin.query('SELECT owner_id FROM ca_organizer WHERE id=$1',[profile])).rows[0].owner_id,host.id);
    const created=await ok('directory/manage/event',{profile_id:profile,title:'Synthetic collaboratively created event',community_id:community,status:'published',is_public:false,starts_at:when(24),starts_public:true,public_location:'Synthetic public place',location_public:true,membership_required:false,event_content:{description:'Synthetic shared event',ends_at:when(28)}},'guest.c');const e=created.id;await ok(`access/policy/events/${e}/approve-share`,{community_id:community,approved:true},'host.a');await ok(`ticketing/events/${e}/config`,{mode:'approval',quota:4,price_cents:1200,item_name:'Synthetic shared ticket',version:0},'guest.c');const categoryBody={name:'Synthetic joint category',price_cents:1000,currency:'EUR',quota:2,visibility_mode:'inherit_event',purchase_rule:'visible_authenticated',enabled:true,version:0};
    const delegatedLink=await ok('directory/manage/link',{profile_id:profile,email:users['guest.d'].email},'guest.c');const delegatedToken=new URLSearchParams(new URL(delegatedLink.url).hash.slice(1)).get('profile_link');
    const sharedCategory=await ok(`ticketing/events/${e}/types`,categoryBody,'guest.c');await ok(`access/policy/events/${e}/scanner`,{email:users['guest.d'].email,expires_at:when(1)},'guest.c');
    const sharedSeries={profile_id:profile,title:'Synthetic collaborative series',description:'Synthetic only',community_id:community,is_public:false};
    const sharedForm={profile_id:profile,title:'Synthetic collaborative questions',fields:[{key:'music',label:'Welche Musik möchtest du hören?',required:true}]};
    await ok('directory/manage/series',sharedSeries,'guest.c');await ok('directory/manage/form',sharedForm,'guest.c');
    assert.equal((await call('directory/manage/series',{...sharedSeries,profile_id:another},'guest.c')).status,404);
    await ok('directory/manage/grant',{kind:'event',id:e,email:users['guest.d'].email},'guest.c');const sharedOrder=(await buy(sharedCategory.id,'guest.d')).data;await pay(sharedOrder.id,'guest.d');
    await ok('access/policy/restrictions',{event_id:e,email:users['guest.d'].email,expires_at:when(1)},'guest.c');const sharedRefund=(await ok(`ticketing/profiles/${profile}/refunds`,undefined,'guest.c')).items.find(r=>r.order_id===sharedOrder.id);assert.ok(sharedRefund);
    await ok(`ticketing/refunds/${sharedRefund.id}/approve`,{amount_cents:1000},'guest.c');assert.equal((await admin.query('SELECT refunded_cents FROM ca_ticket_order WHERE id=$1',[sharedOrder.id])).rows[0].refunded_cents,1000);
    assert.equal((await call(`directory/events/${e}`,undefined,'guest.c')).status,200);
    await ok(`access/policy/organizer-members/${invite.id}/revoke`,{version:active.version},'host.a');
    assert.equal((await call('directory/manage',undefined,'guest.c')).status,403);
    assert.equal((await call(`directory/organizers/${profile}/redeem`,{token:delegatedToken},'guest.d')).status,422);
    assert.equal((await call(`directory/events/${e}`,undefined,'guest.c')).status,404);
    assert.equal((await call(`ticketing/events/${e}/types`,categoryBody,'guest.c')).status,404);
    assert.equal((await call('directory/manage/form',sharedForm,'guest.c')).status,404);
    assert.equal((await call(`ticketing/profiles/${profile}/refunds`,undefined,'guest.c')).status,404);
    assert.equal((await call(`access/policy/organizer-members/${invite.id}/accept`,{version:invite.version},'guest.c')).status,409);
    assert.equal((await call(memberPath,undefined,'host.a')).status,200);
    assert.equal((await admin.query('SELECT COUNT(*)::int AS n FROM ca_organizer_member WHERE profile_id=$1 AND user_id=$2',[profile,users['guest.c'].id])).rows[0].n,1);
  });
  await t.test('expired organizer invitation cannot be accepted and stale versions cannot undo owner decisions',async()=>{
    const path=`access/policy/organizers/${profile}/members`,m=await ok(path,{email:users['guest.d'].email,version:0},'host.a');
    await admin.query("UPDATE ca_organizer_member SET expires_at=NOW()-INTERVAL '1 second' WHERE id=$1",[m.id]);
    assert.equal((await call(`access/policy/organizer-members/${m.id}/accept`,{version:m.version},'guest.d')).data.code,'INVITATION_UNAVAILABLE');
    const renewed=await ok(path,{email:users['guest.d'].email,version:m.version},'host.a');
    assert.equal((await call(`access/policy/organizer-members/${m.id}/revoke`,{version:m.version},'host.a')).status,409);
    const revoked=await ok(`access/policy/organizer-members/${m.id}/revoke`,{version:renewed.version},'host.a');
    const racing=await ok(path,{email:users['guest.d'].email,version:revoked.version},'host.a');const race=await Promise.all([call(`access/policy/organizer-members/${m.id}/accept`,{version:racing.version},'guest.d'),call(`access/policy/organizer-members/${m.id}/revoke`,{version:racing.version},'host.a')]);assert.deepEqual(race.map(r=>r.status).sort(),[200,409]);const after=(await admin.query('SELECT status,version FROM ca_organizer_member WHERE id=$1',[m.id])).rows[0];if(after.status==='active')await ok(`access/policy/organizer-members/${m.id}/revoke`,{version:after.version},'host.a');
    assert.equal((await call(`access/policy/organizer-members/${m.id}/accept`,{version:renewed.version},'guest.d')).status,409);
  });
  await t.test('platform restrictions stop every active role but preserve scoped receipts and complaints',async()=>{
    const expires=when(24);
    await admin.query('INSERT INTO ca_team(user_id) VALUES($1) ON CONFLICT DO NOTHING',[users['host.b'].id]);
    const owned=(await admin.query("SELECT id FROM ca_ticket_order WHERE user_id=$1 ORDER BY id LIMIT 1",[users['guest.b'].id])).rows[0];
    await admin.query("UPDATE ca_organizer_member SET status='active',accepted_at=NOW() WHERE profile_id=$1 AND user_id=$2",[profile,users['guest.d'].id]);
    await admin.query('INSERT INTO ca_community_staff VALUES($1,$2,$3) ON CONFLICT(community_id,user_id) DO UPDATE SET expires_at=$3',[community,users['host.a'].id,expires]);
    await admin.query('INSERT INTO ca_scanner(event_id,user_id,expires_at) SELECT event_id,$2,$3 FROM ca_ticket_order WHERE id=$1 ON CONFLICT(event_id,user_id) DO UPDATE SET expires_at=$3',[owned.id,users['guest.b'].id,expires]);
    const ownCase=(await admin.query("INSERT INTO ca_moderation_case(community_id,subject_id,assigned_to,created_by,details) VALUES($1,$2,$3,$3,'Synthetic own case') RETURNING id",[community,users['guest.b'].id,users['host.a'].id])).rows[0];
    const foreignCase=(await admin.query("INSERT INTO ca_moderation_case(community_id,subject_id,assigned_to,created_by,details) VALUES($1,$2,$3,$3,'Synthetic other case') RETURNING id",[community,users['guest.c'].id,users['host.a'].id])).rows[0];
    for(const key of ['guest.b','host.a','guest.d','team']){
      const ban=await ok('access/policy/restrictions',{email:users[key].email,platform:true,expires_at:expires},'host.b');
      try{
        const snapshot=await ok('account/me',undefined,key);
        assert.equal(snapshot.platform_blocked,true);assert.equal(snapshot.is_team,false);assert.equal(snapshot.is_host,false);assert.deepEqual(snapshot.events,[]);
        for(const [path,body] of [
          ['directory/preferences',{music:['Synthetic blocked write']}],
          ['directory/manage',{profile_id:profile}],
          ['access/team',undefined],['access/policy/workspace',undefined],
          ['access/policy/scanner-events',undefined],
          ['access/policy/staff',{community_id:community,email:users['guest.c'].email,expires_at:expires}],
          ['access/policy/restrictions/'+ban.id+'/revoke',{}],
          ['ticketing/fee',{basis_points:0}],['ticketing/profiles/'+profile+'/refunds',undefined],
          ['legal/reports',undefined],
        ]){
          const r=await call(path,body,key);assert.equal(r.status,403,path);assert.equal(r.data.code,'PLATFORM_BLOCKED');
        }
        assert.equal((await call('ticketing/mine',undefined,key)).status,200);
        assert.equal((await call('legal/mine',undefined,key)).status,200);
        const complaints=await ok('access/policy/complaints',undefined,key);
        assert.ok(complaints.cases.every(c=>key==='guest.b'?c.id===ownCase.id:c.id!==ownCase.id));
        if(key==='guest.b'){
          assert.equal((await call('ticketing/orders/'+owned.id,undefined,key)).status,200);
          assert.equal((await call('ticketing/orders/'+owned.id+'/ticket',undefined,key)).status,403);
          const ownSummary=complaints.cases.find(c=>c.id===ownCase.id);
          assert.equal(ownSummary.appeal_submitted,false);assert.ok(ownSummary.created_at);assert.equal(ownSummary.appeal_submitted_at,null);
          assert.deepEqual(Object.keys(ownSummary).sort(),['affected','appeal_submitted','appeal_submitted_at','community_id','created_at','id']);
          const submitted=await ok('access/policy/cases/'+ownCase.id+'/appeal',{details:'Synthetic complaint'},key);
          assert.deepEqual(submitted,{submitted:true,already_submitted:false});
          const repeated=await ok('access/policy/cases/'+ownCase.id+'/appeal',{details:'Replacement must not overwrite'},key);
          assert.deepEqual(repeated,{submitted:true,already_submitted:true});
          const refreshed=(await ok('access/policy/complaints',undefined,key)).cases.find(c=>c.id===ownCase.id);
          assert.equal(refreshed.appeal_submitted,true);assert.ok(refreshed.appeal_submitted_at);
          const preserved=await admin.query('SELECT details FROM ca_moderation_appeal WHERE case_id=$1 AND user_id=$2',[ownCase.id,users[key].id]);
          assert.equal(preserved.rowCount,1);assert.equal(preserved.rows[0].details,'Synthetic complaint');
          assert.equal((await call('access/policy/cases/'+foreignCase.id+'/appeal',{details:'Foreign case'},key)).status,404);
          assert.equal((await call('access/policy/cases/'+foreignCase.id,undefined,key)).status,403);
        }else assert.equal((await call('ticketing/orders/'+owned.id,undefined,key)).status,404);
      }finally{await ok('access/policy/restrictions/'+ban.id+'/revoke',{},'host.b');}
    }
    // Ban commits while an older request waits for the shared write lock.
    const gate=await admin.connect();await gate.query('BEGIN');await gate.query('SELECT pg_advisory_xact_lock(73100526)');
    try{
      const pending=call('directory/preferences',{music:['Must not be committed']},'guest.c');
      await new Promise(r=>setTimeout(r,100));
      await gate.query('INSERT INTO ca_restriction(user_id,platform,created_by,expires_at) VALUES($1,true,$2,$3)',[users['guest.c'].id,users['host.b'].id,expires]);
      await gate.query('COMMIT');
      const denied=await pending;assert.equal(denied.status,403);assert.equal(denied.data.code,'PLATFORM_BLOCKED');
      assert.equal((await admin.query("SELECT 1 FROM ca_guest_preferences WHERE user_id=$1 AND preferences->'music' ? 'Must not be committed'",[users['guest.c'].id])).rowCount,0);
    }finally{await gate.query('ROLLBACK');gate.release();await admin.query('UPDATE ca_restriction SET revoked_at=NOW() WHERE user_id=$1 AND platform',[users['guest.c'].id]);}
  });
  await t.test('pilot flags stop new work and preserve reconciliation, receipts and refunds',async()=>{
    const provider=syntheticPretixClient(`http://127.0.0.1:${remote.address().port}`,process.env.CA_PRETIX_TOKEN);const paused=createTicketing(state.pool,provider,{salesEnabled:false,privateTicketsEnabled:false});
    await new Promise(r=>server.close(r));server=createApp({...state,ticketing:paused,privateCommunitiesEnabled:false,requestLimits:createRequestLimits({now:()=>time})});await new Promise(r=>server.listen(0,'127.0.0.1',r));
    const o=(await admin.query("SELECT id,event_id FROM ca_ticket_order WHERE user_id=$1 AND state='paid' ORDER BY id LIMIT 1",[users['guest.b'].id])).rows[0];await paused.reconcile();assert.equal((await ok(`ticketing/orders/${o.id}`,undefined,'guest.b')).state,'paid');assert.equal((await call(`ticketing/events/${o.event_id}/checkout`,{age_acknowledged:true},'guest.d')).data.code,'SALES_PAUSED');assert.equal((await ok(`ticketing/events/${o.event_id}/types`,undefined,'guest.b')).items.length,0);assert.equal((await call(`access/communities/${other}/invite`,{email:users['guest.d'].email},'host.b')).data.code,'PRIVATE_COMMUNITIES_PAUSED');assert.equal((await call(`ticketing/profiles/${profile}/refunds`,undefined,'host.a')).status,200);
  });
 }finally{await new Promise(r=>server.close(r));await new Promise(r=>remote.close(r));await state.pool.end();await admin.end();await padmin.end();await pdb.end();}
});
