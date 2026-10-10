import {createServer} from 'node:http';
import {timingSafeEqual} from 'node:crypto';
import {DirectoryError} from './directory.mjs';

const fail=(status,code)=>{throw new DirectoryError(status,code);};
const uuid=v=>{if(typeof v!=='string'||!/^[a-f0-9-]{36}$/.test(v))fail(422,'INVALID_FIELDS');return v;};
const integer=(v,min,max)=>{if(!Number.isSafeInteger(v)||v<min||v>max)fail(422,'INVALID_FIELDS');return v;};
export const feeFor=(cents,basisPoints)=>Number((BigInt(cents)*BigInt(basisPoints)+5000n)/10000n);
export const proportionalFee=(fee,refunded,total)=>Number((BigInt(fee)*BigInt(refunded)+BigInt(Math.floor(total/2)))/BigInt(total));

// Independent PostgreSQL transactions are the ONLY source of ticket inventory.
// Restarting either HTTP process preserves reservations and refund idempotency.
export function createSyntheticPretix(pool){
  async function tx(fn){const db=await pool.connect();try{
    await db.query('BEGIN');await db.query('SELECT pg_advisory_xact_lock(73100527)');
    const r=await fn(db);await db.query('COMMIT');return r;
  }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}}
  async function expire(db){await db.query("UPDATE pt_order SET state='expired' WHERE state='pending' AND expires_at<=NOW()");}
  async function get(db,id){const o=(await db.query('SELECT * FROM pt_order WHERE id=$1',[uuid(id)])).rows[0];if(!o)fail(404,'NOT_FOUND');return {...o,currency:'EUR'};}
  async function configure(body){return tx(async db=>{
    uuid(body.id);integer(body.price_cents,1,100000000);integer(body.quota,1,1000000);integer(body.version,1,2147483647);
    if(typeof body.item_name!=='string'||!body.item_name.trim()||body.item_name.length>120)fail(422,'INVALID_FIELDS');
    await expire(db);
    const occupied=(await db.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1 AND state IN('pending','paid')",[body.id])).rows[0].n;
    if(occupied>body.quota)fail(409,'CAPACITY_BELOW_CONFIRMED');
    const old=(await db.query('SELECT * FROM pt_event WHERE id=$1',[body.id])).rows[0];
    if(old&&old.version>body.version)fail(409,'CATALOG_CHANGED');
    if(old?.version===body.version&&(old.price_cents!==body.price_cents||old.quota!==body.quota||old.item_name!==body.item_name))fail(409,'CATALOG_CHANGED');
    await db.query(`INSERT INTO pt_event VALUES($1,$2,$3,$4,$5) ON CONFLICT(id) DO UPDATE
      SET price_cents=$2,item_name=$3,quota=$4,version=$5`,[body.id,body.price_cents,body.item_name,body.quota,body.version]);
    return {configured:true};
  });}
  async function configureType(b){return tx(async db=>{
    uuid(b.id);uuid(b.event_id);integer(b.price_cents,1,100000000);integer(b.quota,1,1000000);integer(b.version,1,2147483647);await expire(db);
    const old=(await db.query('SELECT * FROM pt_type WHERE id=$1',[b.id])).rows[0];
    if(old&&(old.event_id!==b.event_id||old.version>b.version||old.version===b.version&&(old.price_cents!==b.price_cents||old.quota!==b.quota)))fail(409,'CATALOG_CHANGED');
    const n=(await db.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE type_id=$1 AND state IN('pending','paid')",[b.id])).rows[0].n;if(n>b.quota)fail(409,'CAPACITY_BELOW_CONFIRMED');
    await db.query('INSERT INTO pt_type VALUES($1,$2,$3,$4,$5) ON CONFLICT(id) DO UPDATE SET price_cents=$3,quota=$4,version=$5',[b.id,b.event_id,b.price_cents,b.quota,b.version]);return {configured:true};
  });}
  async function typeInventory(type){return tx(async db=>{await expire(db);const t=(await db.query('SELECT * FROM pt_type WHERE id=$1',[uuid(type)])).rows[0];if(!t)fail(404,'NOT_FOUND');const e=(await db.query('SELECT * FROM pt_event WHERE id=$1',[t.event_id])).rows[0];const n=(await db.query("SELECT COUNT(*)::int AS all_count,COUNT(*) FILTER(WHERE type_id=$2)::int AS type_count FROM pt_order WHERE event_id=$1 AND state IN('pending','paid')",[e.id,t.id])).rows[0];return {available:Math.max(0,Math.min(e.quota-n.all_count,t.quota-n.type_count))};});}
  async function reserve(body){return tx(async db=>{
    uuid(body.id);uuid(body.event_id);
    if(!/^[a-f0-9]{64}$/.test(body.subject??'')||!/^acct_demo_[a-f0-9]{32}$/.test(body.account_id??''))fail(422,'INVALID_FIELDS');
    await expire(db);
    const old=(await db.query('SELECT * FROM pt_order WHERE id=$1',[body.id])).rows[0];
    if(old){if(old.subject!==body.subject||old.event_id!==body.event_id||old.account_id!==body.account_id||(old.type_id??null)!==(body.type_id??null))fail(409,'ORDER_MISMATCH');return {...old,currency:'EUR'};}
    const e=(await db.query('SELECT * FROM pt_event WHERE id=$1',[body.event_id])).rows[0];if(!e)fail(404,'NOT_FOUND');
    const type=body.type_id?(await db.query('SELECT * FROM pt_type WHERE id=$1 AND event_id=$2',[uuid(body.type_id),e.id])).rows[0]:null;
    if(body.type_id&&!type)fail(404,'NOT_FOUND');
    if((type?.price_cents??e.price_cents)!==body.total_cents)fail(409,'CATALOG_CHANGED');
    integer(body.fee_cents,0,(type?.price_cents??e.price_cents)-1);
    if((await db.query("SELECT 1 FROM pt_order WHERE event_id=$1 AND subject=$2 AND state IN('pending','paid')",[e.id,body.subject])).rowCount)fail(409,'TICKET_EXISTS');
    const n=(await db.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1 AND state IN('pending','paid')",[e.id])).rows[0].n;
    if(n>=e.quota)fail(409,'EVENT_FULL');
    if(type&&(await db.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE type_id=$1 AND state IN('pending','paid')",[type.id])).rows[0].n>=type.quota)fail(409,'EVENT_FULL');
    return {...(await db.query(`INSERT INTO pt_order(id,event_id,subject,account_id,total_cents,fee_cents,type_id)
      VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[body.id,e.id,body.subject,body.account_id,body.total_cents,body.fee_cents,type?.id??null])).rows[0],currency:'EUR'};
  });}
  async function read(id){return tx(async db=>{await expire(db);return get(db,id);});}
  async function settle(id,body){return tx(async db=>{
    const o=await get(db,id);
    if(!['success','failed','late'].includes(body.outcome))fail(422,'INVALID_FIELDS');
    if(['paid','refunded'].includes(o.state))return o;
    if(body.outcome==='failed')await db.query("UPDATE pt_order SET state='failed' WHERE id=$1 AND state='pending'",[id]);
    else await db.query(`UPDATE pt_order SET state='paid',valid_payment=(state='pending' AND NOT blocked AND expires_at>NOW() AND $2<>'late') WHERE id=$1`,[id,body.outcome]);
    return get(db,id);
  });}
  async function block(id){return tx(async db=>{
    await get(db,id);await db.query("UPDATE pt_order SET blocked=true,state=CASE WHEN state='pending' THEN 'expired' ELSE state END WHERE id=$1",[id]);return get(db,id);
  });}
  async function refund(id,body){return tx(async db=>{
    uuid(body.id);const o=await get(db,id);integer(body.amount_cents,1,o.total_cents);
    const old=(await db.query('SELECT * FROM pt_refund WHERE id=$1',[body.id])).rows[0];
    if(old){if(old.order_id!==id||old.amount_cents!==body.amount_cents)fail(409,'REFUND_MISMATCH');return o;}
    if(o.state!=='paid'||body.amount_cents>o.total_cents-o.refunded_cents)fail(409,'INVALID_REFUND');
    const refunded=o.refunded_cents+body.amount_cents;
    await db.query('INSERT INTO pt_refund VALUES($1,$2,$3)',[body.id,id,body.amount_cents]);
    await db.query(`UPDATE pt_order SET refunded_cents=$2,fee_refunded_cents=$3,blocked=true,
      state=CASE WHEN total_cents=$2 THEN 'refunded' ELSE 'paid' END WHERE id=$1`,[id,refunded,proportionalFee(o.fee_cents,refunded,o.total_cents)]);
    return get(db,id);
  });}
  async function inventory(id){return tx(async db=>{
    await expire(db);const e=(await db.query('SELECT * FROM pt_event WHERE id=$1',[uuid(id)])).rows[0];if(!e)fail(404,'NOT_FOUND');
    const n=(await db.query("SELECT COUNT(*)::int AS n FROM pt_order WHERE event_id=$1 AND state IN('pending','paid')",[id])).rows[0].n;
    return {available:Math.max(0,e.quota-n),quota:e.quota};
  });}
  return {configure,configureType,typeInventory,reserve,read,settle,block,refund,inventory};
}

export function syntheticPretixServer(provider,token){
  if(!/^[a-f0-9]{64}$/.test(token??''))throw new Error('Synthetic server credential required.');
  return createServer({requestTimeout:10000,headersTimeout:5000},async(req,res)=>{
    const send=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
    try{
      const incoming=Buffer.from(req.headers.authorization??''),expected=Buffer.from('Bearer '+token);
      if(incoming.length!==expected.length||!timingSafeEqual(incoming,expected))return send(401,{code:'UNAUTHENTICATED'});
      if(!['127.0.0.1','::1'].includes(req.socket.remoteAddress))return send(403,{code:'LOCAL_ONLY'});
      if(typeof req.url!=='string'||req.url.includes('?')||req.url.length>160)return send(404,{code:'NOT_FOUND'});
      let body={};if(req.method==='POST'){
        let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>4096)return send(413,{code:'BODY_TOO_LARGE'});}
        try{body=JSON.parse(raw);}catch{return send(400,{code:'INVALID_JSON'});}
        if(!body||typeof body!=='object'||Array.isArray(body))return send(400,{code:'INVALID_JSON'});
      }
      const m=/^\/orders\/([a-f0-9-]{36})(?:\/(settle|block|refund))?$/.exec(req.url);
      let data;
      if(req.method==='POST'&&req.url==='/types')data=await provider.configureType(body);
      else if(req.method==='GET'&&/^\/types\/[a-f0-9-]{36}$/.test(req.url))data=await provider.typeInventory(req.url.slice(7));
      else if(req.method==='POST'&&req.url==='/events')data=await provider.configure(body);
      else if(req.method==='POST'&&req.url==='/orders')data=await provider.reserve(body);
      else if(req.method==='GET'&&/^\/events\/[a-f0-9-]{36}$/.test(req.url))data=await provider.inventory(req.url.slice(8));
      else if(m&&req.method==='GET'&&!m[2])data=await provider.read(m[1]);
      else if(m&&req.method==='POST'&&m[2])data=await provider[m[2]](m[1],body);
      else return send(404,{code:'NOT_FOUND'});
      send(200,data);
    }catch(e){send(e instanceof DirectoryError?e.status:503,{code:e instanceof DirectoryError?e.code:'TICKET_SERVICE_UNAVAILABLE'});}
  });
}
