import {extendedProduct} from './product_scope.mjs';
import {DirectoryError} from './directory.mjs';
import {createPrivateAccess,ticketTypeVisible} from './private_access.mjs';
import {eventJoins} from './event_policy.mjs';
const fail=(s,c)=>{throw new DirectoryError(s,c);};
const uid=v=>{if(typeof v!=='string'||!/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(v))fail(404,'NOT_FOUND');return v;};
const integer=(n,min,max)=>{if(!Number.isSafeInteger(n)||n<min||n>max)fail(422,'INVALID_FIELDS');return n;};
export function createPrivateTicketing(pool,provider){
 const access=createPrivateAccess(pool);
 async function selected(db,u,type,{purchase=false}={}){
  if(!extendedProduct&&purchase)fail(404,'NOT_FOUND');
  const row=(await db.query(`SELECT tt.* ${eventJoins} JOIN ca_ticket_type tt ON tt.event_id=e.id WHERE tt.id=$2 AND ${ticketTypeVisible}`,[u?.id??null,uid(type)])).rows[0];
  if(!row)fail(404,'NOT_FOUND');
  if(purchase&&(!row.enabled||!row.provider_ready||row.sales_start&&row.sales_start>new Date()||row.sales_end&&row.sales_end<=new Date()))fail(409,'SALES_CLOSED');
  return row;
 }
 async function list(u,event){if(!extendedProduct)fail(404,'NOT_FOUND');uid(event);const rows=(await pool.query(`SELECT tt.*,e.status AS event_status,e.starts_at AS event_starts,EXISTS(SELECT 1 FROM ca_event_interest i WHERE i.event_id=e.id AND i.user_id=$1 AND i.status IN('approved','purchase_eligible')) AS approved ${eventJoins} JOIN ca_ticket_type tt ON tt.event_id=e.id WHERE e.id=$2 AND ${ticketTypeVisible} ORDER BY tt.name,tt.id`,[u?.id??null,event])).rows;const items=[];
  for(const r of rows){const available=r.provider_ready?await provider.typeInventory(r.id):{available:0};items.push({can_buy:!!u?.emailVerified&&r.enabled&&r.event_status==='published'&&r.event_starts>new Date()&&(!r.sales_start||r.sales_start<=new Date())&&(!r.sales_end||r.sales_end>new Date())&&available.available>0&&(r.purchase_rule==='visible_authenticated'||r.approved),id:r.id,event_id:r.event_id,name:r.name,price_cents:r.price_cents,currency:r.currency,available:available.available,purchase_rule:r.purchase_rule,visibility_mode:r.visibility_mode,enabled:r.enabled,sales_start:r.sales_start,sales_end:r.sales_end});}return {items,synthetic:true};
 }
 async function configure(u,event,b){
  if(!extendedProduct)fail(404,'NOT_FOUND');
  if(!provider.configureType)fail(409,'CATEGORY_ADAPTER_REQUIRED');
  const row=await access.tx(u,async db=>{const e=await access.owner(db,u,event);
   const allowed=['id','name','price_cents','currency','quota','visibility_mode','purchase_rule','communities','sales_start','sales_end','enabled','version'];if(Object.keys(b).some(k=>!allowed.includes(k)))fail(422,'INVALID_FIELDS');
   if(typeof b.name!=='string'||!b.name.trim()||b.name.length>120||!['inherit_event','community_subset','explicit_grant'].includes(b.visibility_mode)||!['visible_authenticated','event_approval_required'].includes(b.purchase_rule)||b.currency!=='EUR'||typeof b.enabled!=='boolean')fail(422,'INVALID_FIELDS');
   integer(b.price_cents,1,100000000);integer(b.quota,1,1000000);
   const communities=b.communities??[];if(!Array.isArray(communities)||communities.length>50)fail(422,'INVALID_FIELDS');communities.forEach(uid);
   if(b.visibility_mode==='community_subset'&&!communities.length)fail(422,'INVALID_FIELDS');
   for(const c of communities)if(!(await db.query('SELECT 1 FROM ca_profile_community WHERE profile_id=$1 AND community_id=$2',[e.profile_id,c])).rowCount)fail(404,'NOT_FOUND');
   const dates=[b.sales_start,b.sales_end].map(d=>{if(d==null)return null;if(typeof d!=='string'||!Number.isFinite(Date.parse(d)))fail(422,'INVALID_FIELDS');return new Date(d);});if(dates[0]&&dates[1]&&dates[0]>=dates[1])fail(422,'INVALID_FIELDS');
   if(!(await db.query('SELECT 1 FROM ca_ticket_config WHERE event_id=$1 AND provider_ready',[event])).rowCount)fail(409,'TICKETING_DISABLED');
   const old=b.id?(await db.query('SELECT * FROM ca_ticket_type WHERE id=$1 AND event_id=$2',[uid(b.id),event])).rows[0]:null;
   if(b.id&&!old)fail(404,'NOT_FOUND');if(b.version!==(old?.version??0))fail(409,'CATALOG_CHANGED');
   const args=[event,b.name.trim(),b.price_cents,b.quota,b.visibility_mode,b.purchase_rule,...dates,b.enabled];
   const r=(old?await db.query('UPDATE ca_ticket_type SET name=$2,price_cents=$3,quota=$4,visibility_mode=$5,purchase_rule=$6,sales_start=$7,sales_end=$8,enabled=$9,version=version+1,provider_ready=false WHERE id=$10 AND event_id=$1 RETURNING *',[...args,old.id]):await db.query('INSERT INTO ca_ticket_type(event_id,name,price_cents,quota,visibility_mode,purchase_rule,sales_start,sales_end,enabled) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *',args)).rows[0];
   await db.query('DELETE FROM ca_ticket_type_community WHERE type_id=$1',[r.id]);for(const c of new Set(communities))await db.query('INSERT INTO ca_ticket_type_community VALUES($1,$2)',[r.id,c]);await access.audit(db,u,'ticket_policy_changed',r.id);return r;
  });
  const mapped=await provider.configureType({id:row.id,event_id:row.event_id,price_cents:row.price_cents,quota:row.quota,version:row.version});if(provider.native){if(!Number.isSafeInteger(mapped.item_id)||mapped.item_id<=0)fail(503,'TICKET_RESPONSE_INVALID');await pool.query('INSERT INTO ca_ticket_native_type_binding VALUES($1,$2) ON CONFLICT(type_id) DO UPDATE SET item_id=$2',[row.id,mapped.item_id]);}await pool.query('UPDATE ca_ticket_type SET provider_ready=true WHERE id=$1 AND version=$2',[row.id,row.version]);return {...row,provider_ready:true,synthetic:true};
 }
 async function grant(u,type,b){if(!extendedProduct)fail(404,'NOT_FOUND');return access.tx(u,async db=>{
  if(Object.keys(b).some(k=>!['email','expires_at','revoked'].includes(k))||typeof b.revoked!=='boolean')fail(422,'INVALID_FIELDS');
  const t=(await db.query('SELECT * FROM ca_ticket_type WHERE id=$1',[uid(type)])).rows[0];if(!t)fail(404,'NOT_FOUND');await access.owner(db,u,t.event_id);
  const expires=new Date(b.expires_at);if(typeof b.expires_at!=='string'||!Number.isFinite(expires.getTime())||expires<=new Date())fail(422,'INVALID_FIELDS');
  await db.query('INSERT INTO ca_ticket_type_grant(type_id,user_id,expires_at,revoked_at) VALUES($1,$2,$3,CASE WHEN $4 THEN NOW() END) ON CONFLICT(type_id,user_id) DO UPDATE SET expires_at=$3,revoked_at=CASE WHEN $4 THEN NOW() END',[type,await access.recipient(db,b.email),expires,b.revoked]);await access.audit(db,u,'ticket_category_grant_changed',type);return {granted:!b.revoked};
 });}
 async function management(u,event){await access.owner(pool,u,event);if(!extendedProduct)return {items:[],synthetic:true};return {items:(await pool.query('SELECT tt.*,ARRAY(SELECT community_id FROM ca_ticket_type_community tc WHERE tc.type_id=tt.id) AS communities FROM ca_ticket_type tt WHERE event_id=$1 ORDER BY name,id',[event])).rows,synthetic:true};}
 return {selected,list,configure,grant,management};
}
