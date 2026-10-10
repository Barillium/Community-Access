import {extendedProduct,productEventScope} from './product_scope.mjs';
import {assertAccountAction} from './account_policy.mjs';
import {createLegal,legalSnapshot,legalReadySQL} from './legal.mjs';
import {createPrivateTicketing} from './private_ticketing.mjs';
import {createHash,randomBytes,timingSafeEqual} from 'node:crypto';
import {DirectoryError} from './directory.mjs';
import {accessWriteLock,activeProfileHost,profileNotRevoked,activeMembership} from './access_policy.mjs';
import {eventJoins,eventPolicy,retainedEvent,publicEventBase as publicEvent,ownerCurrent} from './event_policy.mjs';
import {feeFor} from './synthetic_pretix.mjs';
import {organizerManager} from './organizer_access.mjs';

// Financial reconciliation must not revoke existing orders just because V1 hides an event.
const rules=eventPolicy(null,{extended:true});
const fail=(status,code)=>{throw new DirectoryError(status,code);};
const id=v=>{if(typeof v!=='string'||!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(v))fail(404,'NOT_FOUND');return v;};
const hash=v=>createHash('sha256').update(v).digest('hex');
const verified=u=>{if(!u)fail(401,'UNAUTHENTICATED');if(!u.emailVerified)fail(403,'VERIFY_EMAIL');};
const number=(v,min,max)=>{if(!Number.isSafeInteger(v)||v<min||v>max)fail(422,'INVALID_FIELDS');return v;};
const fields=(body,keys)=>{if(Object.keys(body).some(k=>!keys.includes(k)))fail(422,'INVALID_FIELDS');};

export function createTicketing(pool,provider,{salesEnabled=true,privateTicketsEnabled=true}={}){
  if(!provider?.synthetic)throw new Error('Only explicitly selected synthetic ticketing is implemented.');
  const categories=createPrivateTicketing(pool,provider);
  const legal=createLegal(pool);
  async function tx(work){const db=await pool.connect();try{
    await db.query('BEGIN');await db.query(accessWriteLock);await assertAccountAction(db);const r=await work(db);await db.query('COMMIT');return r;
  }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}}
  async function host(db,u,profile){
    verified(u);const p=(await db.query(`SELECT p.* FROM ca_organizer p WHERE p.id=$2 AND ${organizerManager()} AND ${activeProfileHost}`,[u.id,id(profile)])).rows[0];
    if(!p)fail(404,'NOT_FOUND');return p;
  }
  async function team(db,u){verified(u);if(!(await db.query('SELECT 1 FROM ca_team WHERE user_id=$1',[u.id])).rowCount)fail(403,'TEAM_REQUIRED');}
  async function event(db,u,event){
    return (await db.query(`SELECT e.*,${legalReadySQL} AS legal_ready,${rules.visible} AS visible,${publicEvent} AS publicly_visible,
      ${profileNotRevoked} AS profile_allowed,${activeMembership} AS member,${ownerCurrent} AS current_host,
      CASE WHEN ${rules.profile} THEN p.display_name ELSE '' END AS seller,
      EXISTS(SELECT 1 FROM "user" tu WHERE tu.id=$1 AND tu."emailVerified") AS user_active,
      i.status AS request_status, i.age_acknowledged AS requested_age
      ${eventJoins} LEFT JOIN ca_event_interest i ON i.event_id=e.id AND i.user_id=$1
      WHERE e.id=$2 AND ${retainedEvent}`,[u?.id??null,id(event)])).rows[0];
  }
  function eligibility(e,{payment=false,purchaseRule=null}={}){
    if(!e||!e.visible||!e.current_host||!e.profile_allowed||!e.user_active)fail(404,'NOT_FOUND');
    if(e.status!=='published')fail(409,'EVENT_UNAVAILABLE');
    if(e.ticket_mode==='none')fail(409,'TICKETING_DISABLED');
    if(e.legal_state==='blocked')fail(409,'LEGAL_EVENT_BLOCKED');
    if(!payment&&e.legal_state==='sales_paused')fail(409,'LEGAL_SALES_PAUSED');
    if(!payment&&!e.legal_ready)fail(409,'LEGAL_DECLARATION_REQUIRED');
    if(!payment&&(!e.starts_at||Date.parse(e.starts_at)<=Date.now()))fail(409,'EVENT_STARTED');
    // Event access can remain valid through an independent personal grant.
    if(['revoked','rejected','withdrawn'].includes(e.request_status))fail(403,'ACCESS_BLOCKED');
    if(e.ticket_mode==='public'&&(!e.publicly_visible||e.membership_required))fail(403,'ACCESS_DISABLED');
    if(!payment&&(purchaseRule==='event_approval_required'||purchaseRule===null&&e.ticket_mode==='approval')&&!['purchase_eligible','approved'].includes(e.request_status))fail(403,'PURCHASE_APPROVAL_REQUIRED');
  }
  function view(o){return {id:o.id,event_id:o.event_id,state:o.state,blocked:o.blocked,total_cents:o.total_cents,
    seller_snapshot:o.seller_snapshot,declaration_snapshot:o.declaration_snapshot,legal_stopped:o.legal_stopped,
    currency:'EUR',admission_state:o.admission_state,fee_cents:o.fee_cents,fee_version:o.fee_version,refunded_cents:o.refunded_cents,fee_refunded_cents:o.fee_refunded_cents,
    expires_at:o.expires_at,synthetic:true,...(provider.native?{native_pretix:true,native_checkout_entry:provider.checkoutEntry(o.event_id)}:{})};}
  async function own(u,order){verified(u);const o=(await pool.query('SELECT * FROM ca_ticket_order WHERE id=$1 AND user_id=$2',[id(order),u.id])).rows[0];if(!o)fail(404,'NOT_FOUND');return o;}
  async function fee(u,body){return tx(async db=>{
    await team(db,u);
    if(body!==undefined){fields(body,['basis_points','version']);number(body.basis_points,0,9999);
      const old=(await db.query('SELECT * FROM ca_ticket_fee WHERE singleton')).rows[0];
      if(body.version!==(old?.version??0))fail(409,'FEE_CHANGED');
      await db.query(`INSERT INTO ca_ticket_fee(singleton,basis_points) VALUES(true,$1)
        ON CONFLICT(singleton) DO UPDATE SET basis_points=$1,version=ca_ticket_fee.version+1`,[body.basis_points]);
    }
    return {fee:(await db.query('SELECT basis_points,version FROM ca_ticket_fee')).rows[0]??null,synthetic:true};
  });}
  async function connection(u,profile,body){return tx(async db=>{
    const p=await host(db,u,profile);
    if(body!==undefined&&p.owner_id!==u.id)fail(403,'OWNER_REQUIRED');
    if(body!==undefined){fields(body,['connected']);if(typeof body.connected!=='boolean')fail(422,'INVALID_FIELDS');
      // No account ID supplied by the browser. The synthetic account is derived
      // by the server; a real deployment must use verified Connect onboarding.
      await db.query(`INSERT INTO ca_ticket_connection VALUES($1,$2,$3,true)
        ON CONFLICT(profile_id) DO UPDATE SET ready=$3`,[profile,'acct_demo_'+hash(profile).slice(0,32),body.connected]);
    }
    const c=(await db.query('SELECT ready,synthetic FROM ca_ticket_connection WHERE profile_id=$1',[profile])).rows[0];
    return {connected:c?.ready??false,can_manage_connection:p.owner_id===u.id,synthetic:true};
  });}
  async function configure(u,eventId,body){
    const config=await tx(async db=>{
      const e=await event(db,u,eventId);if(!e)fail(404,'NOT_FOUND');await host(db,u,e.profile_id);
      if(body===undefined)return (await db.query('SELECT * FROM ca_ticket_config WHERE event_id=$1',[eventId])).rows[0]??{mode:'none',version:0};
      fields(body,['mode','price_cents','quota','item_name','version']);
      if(!['none','public','approval'].includes(body.mode))fail(422,'INVALID_FIELDS');
      const old=(await db.query('SELECT * FROM ca_ticket_config WHERE event_id=$1',[eventId])).rows[0];
      if(body.version!==(old?.version??0))fail(409,'CATALOG_CHANGED');
      if((await db.query("SELECT 1 FROM ca_ticket_order WHERE event_id=$1 AND state IN('creating','pending','paid')",[eventId])).rowCount)fail(409,'TICKET_CONFIG_LOCKED');
      if((await db.query("SELECT 1 FROM ca_event_interest WHERE event_id=$1 AND status IN('approved','purchase_eligible')",[eventId])).rowCount)fail(409,'TICKET_CONFIG_LOCKED');
      if(body.mode==='none'){
        await db.query("UPDATE ca_event SET ticket_mode='none' WHERE id=$1",[eventId]);
        await db.query('DELETE FROM ca_ticket_config WHERE event_id=$1',[eventId]);return {mode:'none',version:0};
      }
      if(body.mode==='public'&&(!e.publicly_visible||e.membership_required||e.access_mode==='semi_public'))fail(422,'PUBLIC_TICKETING_REQUIRED');
      number(body.price_cents,1,100000000);number(body.quota,1,1000000);
      if(typeof body.item_name!=='string'||!body.item_name.trim()||body.item_name.length>120)fail(422,'INVALID_FIELDS');
      if(!(await db.query('SELECT 1 FROM ca_ticket_fee')).rowCount)fail(409,'FEE_REQUIRED');
      if(!(await db.query('SELECT 1 FROM ca_ticket_connection WHERE profile_id=$1 AND ready AND synthetic',[e.profile_id])).rowCount)fail(409,'CONNECT_REQUIRED');
      const row=(await db.query(`INSERT INTO ca_ticket_config(event_id,profile_id,mode,item_name,price_cents,quota)
        VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(event_id) DO UPDATE SET mode=$3,item_name=$4,price_cents=$5,quota=$6,
        version=ca_ticket_config.version+1,provider_ready=false RETURNING *`,[eventId,e.profile_id,body.mode,body.item_name.trim(),body.price_cents,body.quota])).rows[0];
      await db.query('UPDATE ca_event SET ticket_mode=$2 WHERE id=$1',[eventId,body.mode]);return row;
    });
    if(config.mode==='none')return config;
    // Retrying configuration after a lost response reapplies the same version.
    const configuredEvent=await event(pool,u,eventId);
    const remoteConfig=await provider.configure({id:eventId,item_name:config.item_name,price_cents:config.price_cents,quota:config.quota,version:config.version,starts_at:configuredEvent?.starts_at});
    if(remoteConfig.item_id)await pool.query('INSERT INTO ca_ticket_native_binding VALUES($1,$2) ON CONFLICT(event_id) DO UPDATE SET item_id=$2',[eventId,remoteConfig.item_id]);
    await pool.query('UPDATE ca_ticket_config SET provider_ready=true WHERE event_id=$1 AND version=$2',[eventId,config.version]);
    return {...config,provider_ready:true,synthetic:true};
  }
  async function offer(u,eventId){
    const e=await event(pool,u,eventId);if(!e||!e.visible)fail(404,'NOT_FOUND');
    if(e.ticket_mode==='none')return {mode:'none'};
    const c=(await pool.query('SELECT * FROM ca_ticket_config WHERE event_id=$1',[eventId])).rows[0];
    let eligible=false;try{if(u?.emailVerified){eligibility(e);eligible=true;}}catch{/* Only publish eligibility, never private reasons. */}
    const connected=!!(await pool.query('SELECT 1 FROM ca_ticket_connection WHERE profile_id=$1 AND ready',[e.profile_id])).rowCount;
    const feeConfigured=!!(await pool.query('SELECT 1 FROM ca_ticket_fee')).rowCount;
    const inventory=c?.provider_ready?await provider.inventory(eventId):{available:0};
    return {mode:e.ticket_mode,item_name:c?.item_name,price_cents:c?.price_cents,currency:'EUR',available:inventory.available,
      can_buy:salesEnabled&&eligible&&connected&&feeConfigured&&c?.provider_ready&&inventory.available>0,signed_in:!!u,synthetic:true,categories_supported:extendedProduct&&privateTicketsEnabled,
      seller:e.seller,seller_information:(await legalSnapshot(pool,eventId)).seller,declaration:(await legalSnapshot(pool,eventId)).declaration,legal_state:e.legal_state,legal_ready:e.legal_ready,minimum_age:e.event_content.minimum_age??null};
  }
  async function checkout(u,eventId,body,typeId=null){
    if(!salesEnabled)fail(409,'SALES_PAUSED');
    if(typeId&&!extendedProduct)fail(404,'NOT_FOUND');
    if(typeId&&!privateTicketsEnabled)fail(409,'PRIVATE_TICKETS_PAUSED');
    verified(u);fields(body,['age_acknowledged']);if(typeof body.age_acknowledged!=='boolean')fail(422,'INVALID_FIELDS');
    await reconcile();
    let order=await tx(async db=>{
      const chosen=typeId?await categories.selected(db,u,typeId,{purchase:true}):null;
      if(chosen&&chosen.event_id!==eventId)fail(404,'NOT_FOUND');
      const e=await event(db,u,eventId);eligibility(e,{purchaseRule:chosen?.purchase_rule??null});
      if(e.event_content.minimum_age!=null&&body.age_acknowledged!==true&&e.requested_age!==true)fail(422,'AGE_ACKNOWLEDGEMENT_REQUIRED');
      const old=(await db.query("SELECT * FROM ca_ticket_order WHERE event_id=$1 AND user_id=$2 AND state IN('creating','pending','paid')",[eventId,u.id])).rows[0];
      if(old){if((old.type_id??null)!==typeId)fail(409,'TICKET_EXISTS');if(old.blocked)fail(403,'ACCESS_BLOCKED');return old;}
      const base=(await db.query('SELECT * FROM ca_ticket_config WHERE event_id=$1 AND provider_ready',[eventId])).rows[0];const c=base?{...base,...(chosen?{price_cents:chosen.price_cents}:{})}:null;if(!c)fail(409,'TICKET_SERVICE_UNAVAILABLE');
      const connected=(await db.query('SELECT * FROM ca_ticket_connection WHERE profile_id=$1 AND ready AND synthetic',[e.profile_id])).rows[0];if(!connected)fail(409,'CONNECT_REQUIRED');
      const f=(await db.query('SELECT * FROM ca_ticket_fee')).rows[0];if(!f)fail(409,'FEE_REQUIRED');
      const fee=feeFor(c.price_cents,f.basis_points);if(fee>=c.price_cents)fail(422,'INVALID_FEE');
      const snapshot=await legalSnapshot(db,eventId);
      return (await db.query(`INSERT INTO ca_ticket_order(event_id,profile_id,user_id,account_id,age_acknowledged,total_cents,fee_cents,fee_version,fee_basis_points,type_id,seller_snapshot,declaration_snapshot)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,[eventId,e.profile_id,u.id,connected.account_id,body.age_acknowledged||e.requested_age===true,c.price_cents,fee,f.version,f.basis_points,typeId,JSON.stringify(snapshot.seller),JSON.stringify(snapshot.declaration)])).rows[0];
    });
    if(order.state==='creating'){
      try{await provider.reserve({id:order.id,event_id:eventId,subject:hash(eventId+':'+u.id),account_id:order.account_id,
        total_cents:order.total_cents,fee_cents:order.fee_cents,fee_basis_points:order.fee_basis_points,type_id:order.type_id});}
      catch(e){if(e instanceof DirectoryError&&['EVENT_FULL','CATALOG_CHANGED','TICKET_EXISTS','INVALID_FEE'].includes(e.code))await pool.query("UPDATE ca_ticket_order SET state='failed' WHERE id=$1 AND state='creating'",[order.id]);throw e;}
    }
    await refreshOrder(order.id);order=await own(u,order.id);return view(order);
  }
  async function refundTask(db,order,reason){
    await db.query(`INSERT INTO ca_ticket_refund(order_id,reason) VALUES($1,$2)
      ON CONFLICT(order_id) WHERE state IN('review','processing') DO NOTHING`,[order.id,reason]);
  }
  async function invalidate(){return tx(async db=>{
    const rows=(await db.query("SELECT * FROM ca_ticket_order WHERE state IN('creating','pending','paid')")).rows;
    for(const o of rows){
      const e=await event(db,{id:o.user_id},o.event_id);
      let valid=true;try{const t=o.type_id&&o.state!=='paid'?await categories.selected(db,{id:o.user_id},o.type_id):null;eligibility(e,{payment:o.state==='paid',purchaseRule:t?.purchase_rule??null});}catch{valid=false;}
      if(!valid){
        await db.query("UPDATE ca_ticket_order SET blocked=true,legal_stopped=legal_stopped OR $2,admission_state='admission_hold' WHERE id=$1",[o.id,o.state!=='paid'&&!!e&&(e.legal_state!=='active'||!e.legal_ready)]);
        if(o.state==='paid'&&o.refunded_cents<o.total_cents)await refundTask(db,o,'access_removed');
      }
    }
  });}
  async function refreshOrder(orderId){
    const remote=await provider.read(orderId);
    await tx(async db=>{
      const o=(await db.query('SELECT * FROM ca_ticket_order WHERE id=$1 FOR UPDATE',[id(orderId)])).rows[0];if(!o)fail(404,'NOT_FOUND');
      // An older authenticated read can finish after a newer payment/refund read.
      // It must never roll back paid/refunded state or cumulative refund amounts.
      if((['paid','refunded'].includes(o.state)&&['pending','expired','failed'].includes(remote.state))||remote.refunded_cents<o.refunded_cents)return;
      if(provider.native&&o.state==='creating'&&Number.isSafeInteger(remote.total_cents)&&remote.total_cents>0&&remote.total_cents<=o.total_cents&&remote.fee_cents===feeFor(remote.total_cents,o.fee_basis_points)){
        // Only the authenticated pretix quote may finalize an intent's discount.
        // After leaving creating, the amount and fee snapshot are immutable.
        o.total_cents=remote.total_cents;o.fee_cents=remote.fee_cents;
        await db.query('UPDATE ca_ticket_order SET total_cents=$2,fee_cents=$3 WHERE id=$1',[o.id,o.total_cents,o.fee_cents]);
      }
      if(remote.currency!=='EUR'||remote.id!==o.id||remote.event_id!==o.event_id||(remote.type_id??null)!==o.type_id||remote.subject!==hash(o.event_id+':'+o.user_id)||remote.account_id!==o.account_id||
        remote.total_cents!==o.total_cents||remote.fee_cents!==o.fee_cents||!['pending','paid','expired','failed','refunded'].includes(remote.state)||
        !Number.isInteger(remote.refunded_cents)||remote.refunded_cents<o.refunded_cents||remote.refunded_cents>o.total_cents||
        !Number.isInteger(remote.fee_refunded_cents)||remote.fee_refunded_cents<o.fee_refunded_cents||remote.fee_refunded_cents>o.fee_cents)fail(503,'TICKET_RESPONSE_INVALID');
      const e=await event(db,{id:o.user_id},o.event_id);
      let eligible=true;try{const t=o.type_id&&o.state!=='paid'?await categories.selected(db,{id:o.user_id},o.type_id):null;eligibility(e,{payment:o.state==='paid',purchaseRule:t?.purchase_rule??null});}catch{eligible=false;}
      const blocked=o.blocked||remote.blocked||!eligible||(['paid','refunded'].includes(remote.state)&&!remote.valid_payment);
      const legallyStopped=o.legal_stopped||(o.state!=='paid'&&!!e&&(e.legal_state!=='active'||!e.legal_ready));
      await db.query(`UPDATE ca_ticket_order SET state=$2,blocked=$3,expires_at=$4,refunded_cents=$5,fee_refunded_cents=$6,legal_stopped=$7,updated_at=NOW(),admission_state=CASE WHEN $3 THEN 'admission_hold' WHEN $2='refunded' THEN 'cancelled' WHEN $2='paid' AND admission_state<>'used' THEN 'active' ELSE admission_state END WHERE id=$1`,
        [o.id,remote.state,blocked,remote.expires_at,remote.refunded_cents,remote.fee_refunded_cents,legallyStopped]);
      if(remote.state==='paid'&&!blocked){
        if(e.event_content.minimum_age!=null&&!o.age_acknowledged)fail(503,'TICKET_RESPONSE_INVALID');
        await db.query(`INSERT INTO ca_event_interest(event_id,user_id,status,age_acknowledged) VALUES($1,$2,'approved',$3)
          ON CONFLICT(event_id,user_id) DO UPDATE SET status='approved',version=ca_event_interest.version+1 WHERE ca_event_interest.status<>'approved'`,[o.event_id,o.user_id,o.age_acknowledged]);
      }
      if(blocked&&remote.state==='paid'&&remote.refunded_cents<o.total_cents)await refundTask(db,o,remote.valid_payment?'access_removed':'late_payment');
      if(e&&(blocked||remote.state==='refunded')&&(!legallyStopped||e.legal_state==='blocked'))await db.query("UPDATE ca_event_interest SET status='revoked',answers='{}',version=version+1 WHERE event_id=$1 AND user_id=$2 AND status IN('approved','purchase_eligible')",[o.event_id,o.user_id]);
    });
    const local=(await pool.query('SELECT * FROM ca_ticket_order WHERE id=$1',[orderId])).rows[0];
    if(local.blocked&&!remote.blocked)await provider.block(orderId);
    return local;
  }
  async function reconcilePass(){
    await invalidate();
    const rows=(await pool.query("SELECT * FROM ca_ticket_order WHERE state IN('creating','pending','paid')")).rows;
    for(const o of rows){
      if(o.state==='creating'){
        if(o.blocked){
          try{await refreshOrder(o.id);}catch(e){if(!(e instanceof DirectoryError&&e.status===404))throw e;await pool.query("UPDATE ca_ticket_order SET state='failed' WHERE id=$1 AND state='creating'",[o.id]);}
          continue;
        }
        try{await provider.reserve({id:o.id,event_id:o.event_id,subject:hash(o.event_id+':'+o.user_id),account_id:o.account_id,total_cents:o.total_cents,fee_cents:o.fee_cents,fee_basis_points:o.fee_basis_points,type_id:o.type_id});}
        catch(e){if(e instanceof DirectoryError&&['EVENT_FULL','CATALOG_CHANGED','TICKET_EXISTS','INVALID_FEE'].includes(e.code)){await pool.query("UPDATE ca_ticket_order SET state='failed' WHERE id=$1 AND state='creating'",[o.id]);continue;}throw e;}
      }
      await refreshOrder(o.id);
    }
    const jobs=(await pool.query("SELECT * FROM ca_ticket_refund WHERE state='processing'")).rows;
    for(const j of jobs){await provider.refund(j.order_id,{id:j.id,amount_cents:j.amount_cents});await refreshOrder(j.order_id);await pool.query("UPDATE ca_ticket_refund SET state='done' WHERE id=$1",[j.id]);}
  }
  let running=false,waiting=[];
  function reconcile(){
    const completion=new Promise((resolve,reject)=>waiting.push({resolve,reject}));
    if(!running){
      running=true;
      void (async()=>{try{
        while(waiting.length){
          // Only this batch is covered by a pass that starts after its calls.
          // Later callers get another pass, without delaying earlier callers.
          const covered=waiting;waiting=[];
          try{await reconcilePass();}
          catch(error){for(const waiter of [...covered,...waiting])waiter.reject(error);waiting=[];return;}
          for(const waiter of covered)waiter.resolve();
        }
      }finally{running=false;}})();
    }
    return completion;
  }
  async function refunds(u,profile){await host(pool,u,profile);await reconcile();return {items:(await pool.query(`SELECT r.*,o.event_id,o.total_cents,o.refunded_cents,o.fee_cents,o.fee_refunded_cents
    FROM ca_ticket_refund r JOIN ca_ticket_order o ON o.id=r.order_id WHERE o.profile_id=$1 ORDER BY r.created_at,r.id`,[profile])).rows};}
  async function approveRefund(u,refundId,body){
    fields(body,['amount_cents']);const job=await tx(async db=>{
      const j=(await db.query('SELECT * FROM ca_ticket_refund WHERE id=$1 FOR UPDATE',[id(refundId)])).rows[0];if(!j)fail(404,'NOT_FOUND');
      const o=(await db.query('SELECT * FROM ca_ticket_order WHERE id=$1',[j.order_id])).rows[0];await host(db,u,o.profile_id);
      number(body.amount_cents,1,o.total_cents);
      if(j.state!=='review'){if(j.amount_cents!==body.amount_cents)fail(409,'REFUND_MISMATCH');return j;}
      if(body.amount_cents>o.total_cents-o.refunded_cents)fail(422,'INVALID_REFUND');
      return (await db.query("UPDATE ca_ticket_refund SET state='processing',amount_cents=$2 WHERE id=$1 RETURNING *",[j.id,body.amount_cents])).rows[0];
    });
    await reconcile();return {id:job.id,state:'done'};
  }
  async function myTickets(u){verified(u);await reconcile();const items=[];
    for(const o of (await pool.query('SELECT * FROM ca_ticket_order WHERE user_id=$1 ORDER BY created_at DESC',[u.id])).rows){const e=await event(pool,u,o.event_id);items.push({...view(o),event_title:e?.visible?e.title:'Veranstaltung nicht mehr verfügbar'});}
    return {items,synthetic:true};}
  async function order(u,orderId,ticket=false){await own(u,orderId);await reconcile();const o=await own(u,orderId);
    if(ticket){if(o.state!=='paid'||o.blocked)fail(403,'TICKET_BLOCKED');return {ticket:{id:o.id,event_id:o.event_id,admission:'Eine Person',synthetic:true,...(provider.native?{native_pretix:true,native_checkout_entry:provider.checkoutEntry(o.event_id)}:{})}};}return view(o);
  }
  async function simulate(u,orderId,body){const o=await own(u,orderId);fields(body,['outcome']);if(o.state!=='paid'&&body.outcome!=='late')await tx(async db=>{const current=(await db.query('SELECT * FROM ca_ticket_order WHERE id=$1 FOR UPDATE',[o.id])).rows[0];const e=await event(db,u,o.event_id);if(current.legal_stopped||e?.legal_state!=='active')fail(409,'LEGAL_SALES_PAUSED');});await provider.settle(orderId,body);await refreshOrder(orderId);return order(u,orderId);}
  async function handoff(u,orderId,body,redeem=false){
    await own(u,orderId);fields(body,redeem?['browser_nonce','code']:['browser_nonce']);
    if(!/^[a-f0-9]{64}$/.test(body.browser_nonce??''))fail(422,'INVALID_FIELDS');
    return tx(async db=>{
      const o=(await db.query('SELECT * FROM ca_ticket_order WHERE id=$1 AND user_id=$2 FOR UPDATE',[id(orderId),u.id])).rows[0];if(!o)fail(404,'NOT_FOUND');
      const category=o.type_id&&o.state!=='paid'?await categories.selected(db,u,o.type_id):null;
      eligibility(await event(db,u,o.event_id),{payment:o.state==='paid',purchaseRule:category?.purchase_rule??null});
      if(o.blocked||!['pending','creating','paid'].includes(o.state))fail(403,'TICKET_BLOCKED');
      if(redeem){
        if(!/^[a-f0-9]{64}$/.test(body.code??''))fail(404,'INVALID_HANDOFF');
        const r=await db.query(`UPDATE ca_ticket_handoff SET consumed=true WHERE digest=$1 AND order_id=$2
          AND user_id=$3 AND browser_digest=$4 AND NOT consumed AND expires_at>NOW() RETURNING order_id`,[hash(body.code),o.id,u.id,hash(body.browser_nonce)]);
        if(!r.rowCount)fail(404,'INVALID_HANDOFF');return {order_id:o.id,authorized:true};
      }
      await db.query('DELETE FROM ca_ticket_handoff WHERE order_id=$1',[o.id]);
      const code=randomBytes(32).toString('hex');
      await db.query("INSERT INTO ca_ticket_handoff VALUES($1,$2,$3,$4,NOW()+INTERVAL '60 seconds',false)",[hash(code),o.id,u.id,hash(body.browser_nonce)]);
      return {code,order_id:o.id,expires_in:60};
    });
  }
  async function webhook(body){fields(body,['order_id']);id(body.order_id);
    // Untrusted notification: only known local IDs can trigger authenticated reads.
    if((await pool.query('SELECT 1 FROM ca_ticket_order WHERE id=$1',[body.order_id])).rowCount)await refreshOrder(body.order_id);
    return {accepted:true};
  }
  function authorizesService(header){
    if(!provider.serviceCredential)return false;
    const a=Buffer.from(header??''),b=Buffer.from('Bearer '+provider.serviceCredential);
    return a.length===b.length&&timingSafeEqual(a,b);
  }
  async function nativeAuthorization(body,consume){
    fields(body,consume?['order_id','browser_nonce','code']:['order_id','browser_nonce']);id(body.order_id);
    if(!/^[a-f0-9]{64}$/.test(body.browser_nonce??'')||(consume&&!/^[a-f0-9]{64}$/.test(body.code??'')))fail(404,'INVALID_HANDOFF');
    return tx(async db=>{
      const o=(await db.query('SELECT * FROM ca_ticket_order WHERE id=$1 FOR UPDATE',[body.order_id])).rows[0];if(!o)fail(404,'NOT_FOUND');
      const category=o.type_id&&o.state!=='paid'?await categories.selected(db,{id:o.user_id},o.type_id):null;
      const e=await event(db,{id:o.user_id},o.event_id);eligibility(e,{payment:o.state==='paid',purchaseRule:category?.purchase_rule??null});
      if(o.blocked||!['pending','paid'].includes(o.state)||!o.expires_at||(o.state==='pending'&&o.expires_at<=new Date()))fail(403,'TICKET_BLOCKED');
      const binding=o.type_id?(await db.query('SELECT item_id FROM ca_ticket_native_type_binding WHERE type_id=$1',[o.type_id])).rows[0]:(await db.query('SELECT item_id FROM ca_ticket_native_binding WHERE event_id=$1',[o.event_id])).rows[0];
      if(!binding)fail(409,'NATIVE_PRETIX_MAPPING_REQUIRED');
      let h;
      if(consume)h=await db.query(`UPDATE ca_ticket_handoff SET consumed=true,expires_at=$5 WHERE order_id=$1 AND user_id=$2
        AND browser_digest=$3 AND digest=$4 AND NOT consumed AND expires_at>NOW() RETURNING order_id`,[o.id,o.user_id,hash(body.browser_nonce),hash(body.code),o.expires_at]);
      else h=await db.query('SELECT order_id FROM ca_ticket_handoff WHERE order_id=$1 AND user_id=$2 AND browser_digest=$3 AND consumed AND (expires_at>NOW() OR $4)',[o.id,o.user_id,hash(body.browser_nonce),o.state==='paid']);
      if(!h.rowCount)fail(404,'INVALID_HANDOFF');
      return {authorized:true,quantity:1,event_id:o.event_id,order_id:o.id,item_id:binding.item_id,account_id:o.account_id,
        total_cents:o.total_cents,fee_cents:o.fee_cents,expires_at:Math.floor((o.state==='paid'?Date.now()+60000:o.expires_at.getTime())/1000)};
    });
  }
  async function route(u,path,method,body){
    const sale=/^events\/([a-f0-9-]{36})\/(offer|checkout|config)$/.exec(path);
    if(!extendedProduct&&sale&&!(await pool.query(`SELECT 1 FROM ca_event e WHERE e.id=$1 AND ${productEventScope}`,[sale[1]])).rowCount)fail(404,'NOT_FOUND');
    const ls=/^(profiles|events)\/([a-f0-9-]{36})\/(seller|declaration)$/.exec(path);
    if(ls&&['GET','POST'].includes(method)){if(ls[1]==='profiles'&&ls[3]==='seller')return legal.seller(u,ls[2],method==='POST'?body:undefined);if(ls[1]==='events'&&ls[3]==='declaration')return legal.declaration(u,ls[2],method==='POST'?body:undefined);}
    const manage=/^events\/([a-f0-9-]{36})\/types\/manage$/.exec(path);
    if(manage&&method==='GET')return categories.management(u,manage[1]);
    const cat=/^(events|types)\/([a-f0-9-]{36})\/(types|checkout|grant)$/.exec(path);
    if(cat?.[1]==='events'&&cat[3]==='types'&&method==='GET'){if(!privateTicketsEnabled)return {items:[],synthetic:true};const result=await categories.list(u,cat[2]);const ev=await event(pool,u,cat[2]);const snap=ev?.visible?await legalSnapshot(pool,cat[2]):{};Object.assign(result,snap,{legal_state:ev?.visible?ev.legal_state:undefined,legal_ready:ev?.visible?ev.legal_ready:false});if(!salesEnabled||!ev?.legal_ready||ev.legal_state!=='active')result.items=result.items.map(item=>({...item,can_buy:false}));return result;}
    if(cat&&(cat[1]==='types'||cat[3]==='types')&&method==='POST'&&!privateTicketsEnabled)fail(409,'PRIVATE_TICKETS_PAUSED');
    if(method==='POST'&&path==='webhook')return webhook(body);
    verified(u);
    if(cat?.[1]==='events'&&cat[3]==='types'&&method==='POST')return categories.configure(u,cat[2],body);
    if(cat?.[1]==='types'&&cat[3]==='grant'&&method==='POST')return categories.grant(u,cat[2],body);
    if(cat?.[1]==='types'&&cat[3]==='checkout'&&method==='POST'){const t=await categories.selected(pool,u,cat[2],{purchase:true});return checkout(u,t.event_id,body,t.id);}
    if(path==='fee'&&['GET','POST'].includes(method))return fee(u,method==='POST'?body:undefined);
    if(path==='mine'&&method==='GET')return myTickets(u);
    const m=/^(profiles|events|orders|refunds)\/([a-f0-9-]{36})(?:\/(connection|refunds|config|offer|checkout|ticket|simulate|approve|handoff|redeem))?$/.exec(path);
    if(m?.[1]==='profiles'&&m[3]==='connection'&&['GET','POST'].includes(method))return connection(u,m[2],method==='POST'?body:undefined);
    if(m?.[1]==='profiles'&&m[3]==='refunds'&&method==='GET')return refunds(u,m[2]);
    if(m?.[1]==='events'&&m[3]==='config'&&['GET','POST'].includes(method))return configure(u,m[2],method==='POST'?body:undefined);
    if(m?.[1]==='events'&&m[3]==='offer'&&method==='GET')return offer(u,m[2]);
    if(m?.[1]==='events'&&m[3]==='checkout'&&method==='POST')return checkout(u,m[2],body);
    if(m?.[1]==='orders'&&method==='GET'&&[undefined,'ticket'].includes(m[3]))return order(u,m[2],m[3]==='ticket');
    if(m?.[1]==='orders'&&m[3]==='simulate'&&method==='POST')return simulate(u,m[2],body);
    if(m?.[1]==='orders'&&['handoff','redeem'].includes(m[3])&&method==='POST')return handoff(u,m[2],body,m[3]==='redeem');
    if(m?.[1]==='refunds'&&m[3]==='approve'&&method==='POST')return approveRefund(u,m[2],body);
    fail(404,'NOT_FOUND');
  }
  return {route,reconcile,offer,connection,configure,checkout,fee,myTickets,refunds,approveRefund,order,simulate,webhook,authorizesService,nativeAuthorization};
}
