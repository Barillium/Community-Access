import {declareTicketFixture} from './legal_fixtures.mjs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {createRequestLimits} from './request_security.mjs';

test('native pretix 2026.8.0: platform sessions, actual cart/quota/order models, simulated Stripe',async t=>{
  const admin=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_auth'});
  const native=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_native'});
  const state=await createAuth();let tick=Date.now();
  const app=createApp({...state,requestLimits:createRequestLimits({now:()=>tick})});await new Promise(r=>app.listen(8000,'127.0.0.1',r));
  const tokens={},users={};
  const call=async(path,body,key)=>{tick+=1000;const r=await fetch('http://127.0.0.1:8000/api/'+path,{method:body===undefined?'GET':'POST',headers:{Origin:'http://127.0.0.1:8300','Content-Type':'application/json',...(key?{Authorization:'Bearer '+tokens[key]}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});return {status:r.status,data:await r.json(),headers:r.headers};};
  try{
    // Wait for the separately started native WSGI process, never replace it with a fake.
    let ready=false;for(let n=0;n<40;n++){try{const r=await fetch('http://127.0.0.1:8400/events',{method:'POST'});if(r.status===401){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,250));}assert.ok(ready,'native pretix did not start');
    for(const key of ['team','host.a','host.b','guest.a','guest.b','guest.c','guest.d']){const r=await call('auth/sign-in/email',{email:key+'@example.invalid',password:'Synthetic-2026!'});assert.equal(r.status,200);tokens[key]=r.headers.get('set-auth-token');users[key]=(await admin.query('SELECT id FROM "user" WHERE email=$1',[key+'@example.invalid'])).rows[0];}
    const profile=(await admin.query('SELECT id FROM ca_organizer WHERE owner_id=$1 ORDER BY id',[users['host.a'].id])).rows[0].id;
    const demo=(await admin.query("SELECT id,profile_id FROM ca_event WHERE title='Demo Ticketabend · pretix'")).rows[0];
    const buy=(key)=>call(`ticketing/events/${demo.id}/checkout`,{age_acknowledged:true},key);
    const pay=(id,key)=>call(`ticketing/orders/${id}/simulate`,{outcome:'success'},key);
    let order;
    await t.test('real plugin loaded and isolated database contains native quota/cart, not pt_order',async()=>{
      assert.equal((await native.query("SELECT to_regclass('pretixbase_order') IS NOT NULL AS ready,to_regclass('pt_order') IS NULL AS separate")).rows[0].ready,true);
      assert.equal((await native.query('SELECT COUNT(*)::int AS n FROM pretixbase_quota')).rows[0].n,1);
      const r=await buy('guest.a');assert.equal(r.status,200,JSON.stringify(r.data));order=r.data.id;
      assert.equal((await native.query('SELECT COUNT(*)::int AS n FROM pretixbase_cartposition')).rows[0].n,1);
      assert.equal((await call(`access/events/${demo.id}/location`,undefined,'guest.a')).status,404);
    });
    await t.test('native pipeline creates and confirms paid order, with exact Direct Charge fee',async()=>{
      const r=await pay(order,'guest.a');assert.equal(r.status,200,JSON.stringify(r.data));assert.equal(r.data.state,'paid');
      const row=(await native.query('SELECT o.status,p.info FROM pretixbase_order o JOIN pretixbase_orderpayment p ON p.order_id=o.id')).rows[0];
      assert.equal(row.status,'p');const info=JSON.parse(row.info);assert.equal(info.application_fee_amount,63);assert.match(info.stripe_account,/^acct_demo_/);
      assert.equal((await call(`access/events/${demo.id}/location`,undefined,'guest.a')).status,200);
      assert.equal((await call(`ticketing/orders/${order}/ticket`,undefined,'guest.b')).status,404);
    });
    await t.test('duplicate purchase and last native quota are transactionally protected',async()=>{
      const r=await Promise.all([buy('guest.b'),buy('guest.b')]);assert.ok(r.every(v=>v.status===200));assert.equal(r[0].data.id,r[1].data.id);
      const last=await Promise.all([buy('guest.c'),buy('guest.d')]);assert.deepEqual(last.map(v=>v.status).sort(),[200,409]);
      assert.equal((await native.query('SELECT COUNT(*)::int AS n FROM pretixbase_cartposition WHERE expires>NOW()')).rows[0].n,2);
    });
    await t.test('native ticket blocked on withdrawal; host approves explicit partial and full fee refund',async()=>{
      assert.equal((await call(`directory/events/${demo.id}/withdraw`,{},'guest.a')).status,200);
      const positions=(await native.query('SELECT p.canceled,p.blocked,s.id AS platform_order_id FROM pretixbase_orderposition p JOIN community_access_pretix_serviceorder s ON s.order_id=p.order_id')).rows;
      const target=positions.filter(p=>p.platform_order_id===order);assert.equal(target.length,1);
      assert.equal(target[0].canceled,true,JSON.stringify(positions));
      let tasks=(await call(`ticketing/profiles/${demo.profile_id}/refunds`,undefined,'host.a')).data.items;
      let job=tasks.find(v=>v.order_id===order&&v.state==='review');assert.ok(job);
      assert.equal((await call(`ticketing/refunds/${job.id}/approve`,{amount_cents:625},'host.b')).status,404);
      let r=await call(`ticketing/refunds/${job.id}/approve`,{amount_cents:625},'host.a');assert.equal(r.status,200,JSON.stringify(r.data));
      let p=(await call(`ticketing/orders/${order}`,undefined,'guest.a')).data;assert.equal(p.refunded_cents,625);assert.equal(p.fee_refunded_cents,32);
      tasks=(await call(`ticketing/profiles/${demo.profile_id}/refunds`,undefined,'host.a')).data.items;job=tasks.find(v=>v.order_id===order&&v.state==='review');assert.ok(job);
      r=await call(`ticketing/refunds/${job.id}/approve`,{amount_cents:625},'host.a');assert.equal(r.status,200,JSON.stringify(r.data));
      p=(await call(`ticketing/orders/${order}`,undefined,'guest.a')).data;assert.equal(p.state,'refunded');assert.equal(p.fee_refunded_cents,63);
      const rows=(await native.query('SELECT info FROM pretixbase_orderrefund ORDER BY id')).rows.map(v=>JSON.parse(v.info));assert.deepEqual(rows.map(v=>v.explicit_application_fee_refund_cents),[32,31]);
    });
    await t.test('native expirations release inventory, without restoring platform eligibility',async()=>{
      await native.query("UPDATE pretixbase_cartposition SET expires=NOW()-INTERVAL '1 second'");
      await native.query("UPDATE community_access_pretix_serviceorder SET expires_at=NOW()-INTERVAL '1 second' WHERE state='pending'");
      const offer=await call(`ticketing/events/${demo.id}/offer`,undefined,'guest.d');assert.equal(offer.status,200);assert.equal(offer.data.available,3);
      assert.equal((await buy('guest.a')).status,403);
    });
    await t.test('native categories use own articles/quotas and share the event quota',async()=>{
      const starts=new Date(Date.now()+86400000).toISOString();
      const e=await call('directory/manage/event',{profile_id:profile,community_id:(await admin.query('SELECT community_id FROM ca_host WHERE user_id=$1',[users['host.a'].id])).rows[0].community_id,title:'Synthetic category event',status:'published',is_public:true,starts_at:starts,starts_public:true,public_location:'Synthetic public place',location_public:true,membership_required:false,event_content:{description:'Synthetic only',ends_at:new Date(Date.now()+90000000).toISOString()}},'host.a');assert.equal(e.status,200,JSON.stringify(e.data));
      const config=await call(`ticketing/events/${e.data.id}/config`,{mode:'public',quota:2,price_cents:1200,item_name:'Synthetic native event',version:0},'host.a');assert.equal(config.status,200,JSON.stringify(config.data));await declareTicketFixture(state.pool,{...users['host.a'],emailVerified:true},e.data.id);
      const create=async(quota)=>{const r=await call(`ticketing/events/${e.data.id}/types`,{name:'SECRET category',price_cents:1000,currency:'EUR',quota,visibility_mode:'inherit_event',purchase_rule:'visible_authenticated',communities:[],enabled:true,version:0},'host.a');assert.equal(r.status,200,JSON.stringify(r.data));return r.data;};
      const a=await create(1),b=await create(2);
      const rows=(await native.query('SELECT t.id,t.item_id,t.quota_id FROM community_access_pretix_servicetype t WHERE catalog_id=$1',[e.data.id])).rows;assert.equal(rows.length,2);assert.notEqual(rows[0].item_id,rows[1].item_id);
      assert.equal((await native.query('SELECT COUNT(*)::int AS n FROM pretixbase_quota_items qi JOIN community_access_pretix_serviceevent c ON c.quota_id=qi.quota_id WHERE c.id=$1',[e.data.id])).rows[0].n,3);
      const purchase=(type,key)=>call(`ticketing/types/${type}/checkout`,{age_acknowledged:true},key);
      const first=await purchase(a.id,'guest.b');assert.equal(first.status,200,JSON.stringify(first.data));
      assert.equal((await purchase(a.id,'guest.c')).status,409);
      const last=await Promise.all(['guest.c','guest.d'].map(key=>purchase(b.id,key)));assert.deepEqual(last.map(r=>r.status).sort(),[200,409]);
      const paid=await pay(first.data.id,'guest.b');assert.equal(paid.status,200,JSON.stringify(paid.data));assert.equal(paid.data.total_cents,1000);
      const position=(await native.query('SELECT p.item_id,p.price FROM pretixbase_orderposition p JOIN community_access_pretix_serviceorder o ON o.order_id=p.order_id WHERE o.id=$1',[first.data.id])).rows[0];assert.equal(position.item_id,rows.find(r=>r.id===a.id).item_id);assert.equal(Number(position.price),10);
      assert.equal((await native.query('SELECT i.name::text AS name FROM pretixbase_item i JOIN community_access_pretix_servicetype t ON t.item_id=i.id WHERE t.catalog_id=$1',[e.data.id])).rows.some(r=>r.name.includes('SECRET')),false);
    });
    await t.test('legal pause invalidates consumed native checkout grant but preserves paid grant; block is permanent',async()=>{
      const e=(await admin.query("SELECT id FROM ca_event WHERE title='Synthetic category event'")).rows[0].id;
      const rows=(await admin.query("SELECT o.*,u.email FROM ca_ticket_order o JOIN \"user\" u ON u.id=o.user_id WHERE event_id=$1",[e])).rows;
      const paid=rows.find(o=>o.state==='paid'),pending=rows.find(o=>o.state==='pending');assert.ok(paid&&pending);
      const bind=async(o,nonce)=>{const key=o.email.split('@')[0];const h=await call(`ticketing/orders/${o.id}/handoff`,{browser_nonce:nonce},key);assert.equal(h.status,200,JSON.stringify(h.data));return state.ticketing.nativeAuthorization({order_id:o.id,browser_nonce:nonce,code:h.data.code},true);};
      await bind(pending,'a'.repeat(64));await bind(paid,'b'.repeat(64));
      assert.equal((await state.ticketing.nativeAuthorization({order_id:pending.id,browser_nonce:'a'.repeat(64)},false)).authorized,true);
      const report=await call('legal/reports',{event_id:e,reference:`events/${e}`,details:'Synthetic native checkout permit review',name:'Synthetic reporter',email:'reporter@example.invalid',good_faith:true});assert.equal(report.status,200);
      assert.equal((await call(`legal/reports/${report.data.reference}/assign`,{version:0},'team')).status,200);
      const decision={event_id:e,version:1,event_legal_version:0,action:'sales_paused',basis:'clarification',reason:'Synthetic native permit clarification'};
      assert.equal((await call(`legal/reports/${report.data.reference}/decision`,decision,'team')).status,200);
      await assert.rejects(state.ticketing.nativeAuthorization({order_id:pending.id,browser_nonce:'a'.repeat(64)},false),{code:'LEGAL_SALES_PAUSED'});
      assert.equal((await state.ticketing.nativeAuthorization({order_id:paid.id,browser_nonce:'b'.repeat(64)},false)).authorized,true);
      assert.equal((await call(`ticketing/orders/${paid.id}`,undefined,paid.email.split('@')[0])).data.blocked,false);
      assert.equal((await call(`legal/reports/${report.data.reference}/decision`,{...decision,version:2,event_legal_version:1,action:'active',basis:'resolved'},'team')).status,200);
      await assert.rejects(state.ticketing.nativeAuthorization({order_id:pending.id,browser_nonce:'a'.repeat(64)},false),{code:'TICKET_BLOCKED'});
      assert.equal((await call(`legal/reports/${report.data.reference}/decision`,{...decision,version:3,event_legal_version:2,action:'blocked',basis:'danger'},'team')).status,200);
      await assert.rejects(state.ticketing.nativeAuthorization({order_id:paid.id,browser_nonce:'b'.repeat(64)},false));
      const tasks=await call(`ticketing/profiles/${profile}/refunds`,undefined,'host.a');assert.ok(tasks.data.items.some(r=>r.order_id===paid.id&&r.state==='review'));
    });
  }finally{await new Promise(r=>app.close(r));await state.pool.end();await admin.end();await native.end();}
});
