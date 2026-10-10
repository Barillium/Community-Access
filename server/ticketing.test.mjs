import {declareTicketFixture} from './legal_fixtures.mjs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {randomBytes} from 'node:crypto';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createTicketing} from './ticketing.mjs';
import {createApp} from './http.mjs';
import {createRequestLimits} from './request_security.mjs';
import {createSyntheticPretix,syntheticPretixServer,feeFor,proportionalFee} from './synthetic_pretix.mjs';

test('ticketing: signed sessions, independent persistent inventory and synthetic payments',async t=>{
  const admin=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_auth'});
  const providerDB=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'pretix_app',database:'community_tickets'});
  const providerAdmin=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_tickets'});
  let remote=syntheticPretixServer(createSyntheticPretix(providerDB),process.env.CA_PRETIX_TOKEN);
  await new Promise(r=>remote.listen(0,'127.0.0.1',r));const port=remote.address().port;
  let state=await createAuth({env:{...process.env,CA_PRETIX_ORIGIN:`http://127.0.0.1:${port}`}});
  let limiterTime=Date.now();t.beforeEach(()=>{limiterTime+=60000;});
  let server=createApp({...state,requestLimits:createRequestLimits({now:()=>limiterTime})});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));let base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,body,key,origin='http://127.0.0.1:8300')=>new Promise((resolve,reject)=>{
    const req=request(base+'/api/'+path,{method:body===undefined?'GET':'POST',headers:{Host:'127.0.0.1:8000',Origin:origin,
      'Content-Type':'application/json',Connection:'close',...(key?{Authorization:'Bearer '+tokens[key]}:{})}},res=>{
      let raw='';res.setEncoding('utf8');res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,data:JSON.parse(raw)}));res.on('error',reject);
    });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
  });
  const tokens={},users={};
  for(const key of ['team','host.a','host.b','guest.a','guest.b','guest.c','guest.d','unverified']){
    const r=await call('auth/sign-in/email',{email:key+'@example.invalid',password:'Synthetic-2026!'});
    assert.equal(r.status,200);tokens[key]=r.headers['set-auth-token'];
    users[key]=(await admin.query('SELECT * FROM "user" WHERE email=$1',[key+'@example.invalid'])).rows[0];
  }
  const profile=(await admin.query('SELECT id FROM ca_organizer WHERE owner_id=$1',[users['host.a'].id])).rows[0].id;
  const community=(await admin.query('SELECT community_id FROM ca_host WHERE user_id=$1',[users['host.a'].id])).rows[0].community_id;
  const api=path=>'ticketing/'+path;
  const event=async({mode='public',quota=3,price=1250,membership=false}={})=>{
    const start=new Date(Date.now()+86400000).toISOString();
    const e=await state.directory.saveEvent(users['host.a'],{title:'Synthetischer Testabend',community_id:community,
      status:'published',is_public:true,starts_at:start,starts_public:true,public_location:'Demo Halle',location_public:true,
      membership_required:membership,exact_location:'Verborgener synthetischer Hintereingang',event_content:{description:'Nur synthetisch.',minimum_age:18,ends_at:new Date(Date.parse(start)+3600000).toISOString()}});
    const r=await call(api(`events/${e.id}/config`),{mode,quota,price_cents:price,item_name:'Demo Eintritt',version:0},'host.a');assert.equal(r.status,200,JSON.stringify(r));await declareTicketFixture(state.pool,users['host.a'],e.id);return e.id;
  };
  const buy=(e,key='guest.a')=>call(api(`events/${e}/checkout`),{age_acknowledged:true},key);
  const pay=(o,key='guest.a',outcome='success')=>call(api(`orders/${o}/simulate`),{outcome},key);
  const location=(e,key='guest.a')=>call(`access/events/${e}/location`,undefined,key);
  try{
    await t.test('roles, verification, mode isolation and mandatory fee; no client price/account injection',async()=>{
      assert.equal((await call(api('mine'))).status,401);
      assert.equal((await call(api('mine'),undefined,'unverified')).status,403);
      assert.equal((await call(api('fee'),{basis_points:500,version:1},'host.a')).status,403);
      assert.equal((await call(api(`profiles/${profile}/connection`),{connected:true},'host.b')).status,404);
      assert.equal((await call(api(`profiles/${profile}/connection`),{connected:true,account_id:'fake'},'host.a')).status,422);
      await admin.query('DELETE FROM ca_ticket_fee');
      const e=(await admin.query('SELECT id FROM ca_event WHERE title=$1',['Demo Ticketabend · pretix'])).rows[0].id;
      assert.equal((await buy(e)).data.code,'FEE_REQUIRED');
      assert.equal((await call(api('fee'),{basis_points:500,version:0},'team')).status,200);
      assert.equal((await call(api('fee'),{basis_points:500,version:0},'team')).data.code,'FEE_CHANGED');
      assert.equal((await call(api(`events/${e}/checkout`),{age_acknowledged:true,total_cents:1},'guest.a')).status,422);
      assert.equal((await call(api('mine'),undefined,'guest.a','https://foreign.example.invalid')).status,403);
      assert.equal(feeFor(1250,500),63);assert.equal(proportionalFee(63,625,1250),32);
      await assert.rejects(createAuth({env:{...process.env,CA_AUTH_PROFILE:'private-mail',RESEND_API_KEY:'',CA_TICKETING_SYNTHETIC:'true'}}));
      await assert.rejects(createAuth({env:{...process.env,NODE_ENV:'production'}}));
    });
    await t.test('age requirement, paid participation and minimal ticket payload',async()=>{
      const e=await event();assert.equal((await location(e)).status,404);
      assert.equal((await call(api(`events/${e}/checkout`),{age_acknowledged:false},'guest.a')).status,422);
      const b=await buy(e);assert.equal(b.status,200);assert.equal(b.data.state,'pending');assert.equal(b.data.fee_cents,63);
      assert.equal((await location(e)).status,404);
      assert.equal((await call(api(`orders/${b.data.id}`),undefined,'guest.b')).status,404);
      assert.equal((await call(api(`orders/${b.data.id}/ticket`),undefined,'guest.a')).status,403);
      assert.equal((await pay(b.data.id)).data.state,'paid');assert.equal((await location(e)).status,200);
      const ticket=await call(api(`orders/${b.data.id}/ticket`),undefined,'guest.a');assert.equal(ticket.status,200);
      assert.equal(JSON.stringify(ticket.data).includes('Hintereingang'),false);assert.equal(ticket.data.ticket.admission,'Eine Person');
      assert.equal((await buy(e)).data.id,b.data.id);
    });
    await t.test('parallel duplicate checkout and final ticket quota are decided by separate database',async()=>{
      const e=await event({quota:1});
      const [a,b]=await Promise.all([buy(e,'guest.b'),buy(e,'guest.b')]);assert.equal(a.status,200);assert.equal(b.status,200);assert.equal(a.data.id,b.data.id);
      assert.equal((await buy(e,'guest.c')).data.code,'EVENT_FULL');
      assert.equal((await providerAdmin.query('SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1',[e])).rows[0].n,1);
      const other=await event({quota:1});const r=await Promise.all([buy(other,'guest.c'),buy(other,'guest.d')]);assert.deepEqual(r.map(v=>v.status).sort(),[200,409]);
      await assert.rejects(state.pool.query('CREATE TABLE ca_ticket_forbidden(id int)'));
      const forbidden=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'auth_app',database:'community_tickets'});
      try{await assert.rejects(forbidden.query('SELECT 1'));}finally{await forbidden.end();}
    });
    await t.test('approval grants purchase only, not location or a reserved place',async()=>{
      const e=await event({mode:'approval',quota:1});
      assert.equal((await buy(e)).data.code,'PURCHASE_APPROVAL_REQUIRED');
      const applied=await call(`directory/events/${e}/interest`,{answers:{},age_acknowledged:true},'guest.a');assert.equal(applied.status,200);
      const approved=await call('directory/manage/interest',{event_id:e,user_id:users['guest.a'].id,status:'approved',version:1},'host.a');assert.equal(approved.data.status,'purchase_eligible');
      assert.equal((await location(e)).status,404);
      assert.equal((await providerAdmin.query('SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1',[e])).rows[0].n,0);
      const o=await buy(e);assert.equal(o.status,200);await pay(o.data.id);assert.equal((await location(e)).status,200);
    });
    await t.test('handoff is bound to account/browser, one-use and expires; no forwarded links',async()=>{
      const e=await event();const o=(await buy(e,'guest.b')).data.id;
      const nonce=randomBytes(32).toString('hex'),wrong=randomBytes(32).toString('hex');
      const h=await call(api(`orders/${o}/handoff`),{browser_nonce:nonce},'guest.b');assert.equal(h.status,200);
      assert.equal((await call(api(`orders/${o}/redeem`),{browser_nonce:nonce,code:h.data.code},'guest.a')).status,404);
      assert.equal((await call(api(`orders/${o}/redeem`),{browser_nonce:wrong,code:h.data.code},'guest.b')).status,404);
      const r=await Promise.all([0,1].map(()=>call(api(`orders/${o}/redeem`),{browser_nonce:nonce,code:h.data.code},'guest.b')));assert.deepEqual(r.map(v=>v.status).sort(),[200,404]);
      const next=await call(api(`orders/${o}/handoff`),{browser_nonce:nonce},'guest.b');await admin.query("UPDATE ca_ticket_handoff SET expires_at=NOW()-INTERVAL '1 second' WHERE order_id=$1",[o]);
      assert.equal((await call(api(`orders/${o}/redeem`),{browser_nonce:nonce,code:next.data.code},'guest.b')).status,404);
    });
    await t.test('failed and expired reservations release quota; late payments cannot admit',async()=>{
      const e=await event({quota:1});let o=(await buy(e,'guest.c')).data.id;
      assert.equal((await pay(o,'guest.c','failed')).data.state,'failed');
      o=(await buy(e,'guest.c')).data.id;
      await providerAdmin.query("UPDATE pt_order SET expires_at=NOW()-INTERVAL '1 second' WHERE id=$1",[o]);
      const next=await buy(e,'guest.d');assert.equal(next.status,200);
      const late=await pay(o,'guest.c','late');assert.equal(late.data.blocked,true);assert.equal((await location(e,'guest.c')).status,404);
      const tasks=await call(api(`profiles/${profile}/refunds`),undefined,'host.a');assert.ok(tasks.data.items.some(r=>r.order_id===o));
    });
    await t.test('untrusted/duplicate notifications fetch source and do not fabricate paid state',async()=>{
      const e=await event();const o=(await buy(e,'guest.d')).data.id;
      assert.equal((await call(api('webhook'),{order_id:o,state:'paid'})).status,422);
      for(let n=0;n<2;n++)assert.equal((await call(api('webhook'),{order_id:o})).status,200);
      assert.equal((await call(api(`orders/${o}`),undefined,'guest.d')).data.state,'pending');
      const older=await createSyntheticPretix(providerDB).read(o);
      await pay(o,'guest.d');
      await createTicketing(state.pool,{...createSyntheticPretix(providerDB),synthetic:true,read:async()=>older}).webhook({order_id:o});
      await call(api('webhook'),{order_id:o});assert.equal((await call(api(`orders/${o}`),undefined,'guest.d')).data.state,'paid');
    });
    await t.test('revocation during payment blocks ticket and retains a manual refund task',async()=>{
      const e=await event({mode:'approval'});await call(`directory/events/${e}/interest`,{answers:{},age_acknowledged:true},'guest.c');
      await call('directory/manage/interest',{event_id:e,user_id:users['guest.c'].id,status:'approved',version:1},'host.a');const o=(await buy(e,'guest.c')).data.id;
      const v=(await admin.query('SELECT version FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[e,users['guest.c'].id])).rows[0].version;
      await call('directory/manage/interest',{event_id:e,user_id:users['guest.c'].id,status:'revoked',version:v},'host.a');
      await pay(o,'guest.c');assert.equal((await call(api(`orders/${o}/ticket`),undefined,'guest.c')).status,403);
      assert.equal((await location(e,'guest.c')).status,404);
    });
    await t.test('cancellation, partial/full refund, proportional fee and retry after provider response loss',async()=>{
      const e=await event();const o=(await buy(e,'guest.b')).data.id;await pay(o,'guest.b');
      await admin.query("UPDATE ca_event SET status='cancelled' WHERE id=$1",[e]);
      let tasks=(await call(api(`profiles/${profile}/refunds`),undefined,'host.a')).data.items;
      let job=tasks.find(r=>r.order_id===o&&r.state==='review');assert.ok(job);
      assert.equal((await call(api(`refunds/${job.id}/approve`),{amount_cents:625},'host.b')).status,404);
      const r=await Promise.all([0,1].map(()=>call(api(`refunds/${job.id}/approve`),{amount_cents:625},'host.a')));assert.ok(r.every(v=>v.status===200));
      let data=(await call(api(`orders/${o}`),undefined,'guest.b')).data;assert.equal(data.refunded_cents,625);assert.equal(data.fee_refunded_cents,32);assert.equal(data.blocked,true);
      tasks=(await call(api(`profiles/${profile}/refunds`),undefined,'host.a')).data.items;job=tasks.find(r=>r.order_id===o&&r.state==='review');assert.ok(job);
      // Emulate a crashed worker after remote refund committed but before local ack.
      await admin.query("UPDATE ca_ticket_refund SET state='processing',amount_cents=625 WHERE id=$1",[job.id]);
      await createSyntheticPretix(providerDB).refund(o,{id:job.id,amount_cents:625});
      await state.ticketing.reconcile();data=(await call(api(`orders/${o}`),undefined,'guest.b')).data;
      assert.equal(data.refunded_cents,1250);assert.equal(data.fee_refunded_cents,63);assert.equal(data.state,'refunded');
      assert.equal((await providerAdmin.query('SELECT COUNT(*)::int AS n FROM pt_refund WHERE order_id=$1',[o])).rows[0].n,2);
    });
    await t.test('lost reservation acknowledgment plus revocation recovers paid remote order for refund',async()=>{
      const e=await event();const o=(await buy(e,'guest.a')).data.id;
      await admin.query("UPDATE ca_ticket_order SET state='creating' WHERE id=$1",[o]);
      await createSyntheticPretix(providerDB).settle(o,{outcome:'success'});
      await admin.query("UPDATE ca_event SET status='cancelled' WHERE id=$1",[e]);await state.ticketing.reconcile();
      const row=(await admin.query('SELECT * FROM ca_ticket_order WHERE id=$1',[o])).rows[0];assert.equal(row.state,'paid');assert.equal(row.blocked,true);
      assert.equal((await admin.query('SELECT 1 FROM ca_ticket_refund WHERE order_id=$1',[o])).rowCount,1);
    });
    await t.test('withdrawal during an older reconciliation awaits a fresh provider block',{timeout:15000},async t=>{
      const e=await event();const o=(await buy(e,'guest.c')).data.id;await pay(o,'guest.c');
      // Stop the app timer so only the explicitly controlled passes can synchronize.
      await new Promise(r=>server.close(r));
      const barriers=Array.from({length:3},()=>{
        let release,entered;return {gate:new Promise(r=>{release=r;}),ready:new Promise(r=>{entered=r;}),release:()=>release(),entered:()=>entered()};
      });
      let passes=0;const db={connect:()=>state.pool.connect(),query:async(sql,params)=>{
        const result=await state.pool.query(sql,params);
        if(sql==="SELECT * FROM ca_ticket_refund WHERE state='processing'"){
          const barrier=barriers[passes++];if(barrier){barrier.entered();await barrier.gate;}
        }
        return result;
      }};
      const isolated=createTicketing(db,{...createSyntheticPretix(providerDB),synthetic:true});
      const aborted=new Promise((_,reject)=>t.signal.addEventListener('abort',()=>reject(t.signal.reason),{once:true}));
      const ready=barrier=>Promise.race([barrier.ready,aborted]);
      const inFlight=[];let older;
      try{
        let oldDone=false,withdrawalDone=false;
        older=isolated.reconcile().then(()=>{oldDone=true;});inFlight.push(older);await ready(barriers[0]);
        // All orders have already been refreshed using the pre-withdrawal rights.
        await state.directory.discovery.withdraw(users['guest.c'],e);
        const afterWithdrawal=Promise.all([isolated.reconcile(),isolated.reconcile()]).then(()=>{withdrawalDone=true;});
        inFlight.push(afterWithdrawal);barriers[0].release();await ready(barriers[1]);
        assert.equal(oldDone,true,'newer callers must not delay an already covered caller');
        assert.equal(withdrawalDone,false,'withdrawal must await its own fresh pass');
        const stillLater=isolated.reconcile();inFlight.push(stillLater);barriers[1].release();await ready(barriers[2]);
        assert.equal(withdrawalDone,true,'later callers must not starve an already synchronized withdrawal');
        barriers[2].release();await Promise.all([older,afterWithdrawal,stillLater]);
        assert.equal(passes,3,'simultaneous withdrawal callers share one follow-up pass');
        assert.equal((await createSyntheticPretix(providerDB).read(o)).blocked,true);
        assert.equal((await admin.query('SELECT blocked FROM ca_ticket_order WHERE id=$1',[o])).rows[0].blocked,true);
        assert.equal((await admin.query("SELECT 1 FROM ca_ticket_refund WHERE order_id=$1 AND state='review'",[o])).rowCount,1);
      }finally{
        for(const barrier of barriers)barrier.release();await Promise.allSettled(inFlight);
        server=createApp({...state,requestLimits:createRequestLimits({now:()=>limiterTime})});
        await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`;
      }
    });
    await t.test('public withdrawal and host rights loss block already paid tickets',async()=>{
      const e=await event();const o=(await buy(e,'guest.c')).data.id;await pay(o,'guest.c');
      assert.equal((await call(`directory/events/${e}/withdraw`,{},'guest.c')).status,200);
      assert.equal((await call(api(`orders/${o}/ticket`),undefined,'guest.c')).status,403);
      assert.equal((await buy(e,'guest.c')).data.code,'ACCESS_BLOCKED');
      const next=await event();const paid=(await buy(next,'guest.c')).data.id;await pay(paid,'guest.c');
      const rows=(await admin.query('DELETE FROM ca_host WHERE user_id=$1 RETURNING *',[users['host.a'].id])).rows;
      try{await state.ticketing.reconcile();assert.equal((await call(api(`orders/${paid}/ticket`),undefined,'guest.c')).status,403);}
      finally{for(const row of rows)await admin.query('INSERT INTO ca_host(community_id,user_id) VALUES($1,$2)',[row.community_id,row.user_id]);}
      assert.equal((await call(api(`orders/${paid}/ticket`),undefined,'guest.c')).status,403);
    });
    await t.test('native bridge stays closed without owner mapping; account deletion retains refund references',async()=>{
      const e=await event();const o=(await buy(e,'guest.d')).data.id;
      assert.equal(state.ticketing.authorizesService('Bearer wrong'),false);
      assert.equal(state.ticketing.authorizesService('Bearer '+process.env.CA_PRETIX_TOKEN),true);
      const nonce=randomBytes(32).toString('hex');const h=(await call(api(`orders/${o}/handoff`),{browser_nonce:nonce},'guest.d')).data;
      await assert.rejects(state.ticketing.nativeAuthorization({order_id:o,browser_nonce:nonce,code:h.code},true),e=>e.code==='NATIVE_PRETIX_MAPPING_REQUIRED');
      await pay(o,'guest.d');await admin.query('DELETE FROM "user" WHERE id=$1',[users['guest.d'].id]);await state.ticketing.reconcile();
      const row=(await admin.query('SELECT * FROM ca_ticket_order WHERE id=$1',[o])).rows[0];assert.equal(row.blocked,true);
      assert.equal((await admin.query('SELECT 1 FROM ca_ticket_refund WHERE order_id=$1',[o])).rowCount,1);
    });
    await t.test('event deletion and service restart preserve financial references and deny access',async()=>{
      const e=await event();const o=(await buy(e,'guest.a')).data.id;await pay(o);
      await admin.query("UPDATE ca_event SET starts_at=NOW()-INTERVAL '10 days',event_content=jsonb_set(event_content,'{ends_at}',to_jsonb((NOW()-INTERVAL '9 days')::text)) WHERE id=$1",[e]);
      await state.directory.discovery.purge();await state.ticketing.reconcile();
      assert.equal((await admin.query('SELECT 1 FROM ca_ticket_order WHERE id=$1',[o])).rowCount,1);
      assert.equal((await admin.query('SELECT 1 FROM ca_ticket_refund WHERE order_id=$1',[o])).rowCount,1);
      await new Promise(r=>server.close(r));await state.pool.end();await new Promise(r=>remote.close(r));
      remote=syntheticPretixServer(createSyntheticPretix(providerDB),process.env.CA_PRETIX_TOKEN);await new Promise(r=>remote.listen(port,'127.0.0.1',r));
      state=await createAuth({env:{...process.env,CA_PRETIX_ORIGIN:`http://127.0.0.1:${port}`}});
      server=createApp({...state,requestLimits:createRequestLimits({now:()=>limiterTime})});await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`;
      const mine=await call(api('mine'),undefined,'guest.a');assert.equal(mine.status,200);assert.ok(mine.data.items.some(i=>i.id===o&&i.blocked));
      assert.equal((await call(api(`orders/${o}/ticket`),undefined,'guest.a')).status,403);
    });
  }finally{await new Promise(r=>server.close(r));await new Promise(r=>remote.close(r));await state.pool.end();await admin.end();await providerDB.end();await providerAdmin.end();}
});
