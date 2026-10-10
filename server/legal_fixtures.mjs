// Explicit synthetic setup only. Never imported by the HTTP application.
import {createLegal} from './legal.mjs';
export async function declareTicketFixture(pool,u,eventId){
 const e=(await pool.query('SELECT profile_id FROM ca_event WHERE id=$1',[eventId])).rows[0];
 const legal=createLegal(pool);
 if(!(await pool.query('SELECT 1 FROM ca_ticket_seller WHERE profile_id=$1',[e.profile_id])).rowCount)
  await legal.seller({...u,emailVerified:true},e.profile_id,{legal_name:'Synthetischer Ticketverkäufer',address:'Erfundene Testanschrift · kein echter Ort',contact:'seller@example.invalid',seller_status:'business',version:0});
 const r=await legal.declaration({...u,emailVerified:true},eventId);
 await legal.declaration({...u,emailVerified:true},eventId,{confirmed:true,version:r.declaration?.version??0,event_version:r.event_version,seller_version:r.seller_version,terms_version:r.terms_version});
}
