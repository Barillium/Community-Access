import {declareTicketFixture} from './legal_fixtures.mjs';
import {Pool} from 'pg';
import {readFile} from 'node:fs/promises';
import {createAuth} from './auth.mjs';
import {seedDirectory,datedEventFixture} from './directory_fixtures.mjs';
import {createTicketing} from './ticketing.mjs';
import {createSyntheticPretix} from './synthetic_pretix.mjs';

const state=await createAuth();
const tickets=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'fixture_admin',database:'community_tickets'});
try{
  await tickets.query(await readFile(new URL('./synthetic_pretix.sql',import.meta.url),'utf8'));
  const fixtures=await seedDirectory(state);
  const team=await state.auth.api.signUpEmail({body:{name:'Demo Plattformteam',email:'team@example.invalid',password:fixtures.password}});
  await state.pool.query('UPDATE "user" SET "emailVerified"=true WHERE id=$1',[team.user.id]);
  await state.pool.query('INSERT INTO ca_team VALUES($1)',[team.user.id]);
  const provider={...createSyntheticPretix(tickets),synthetic:true};
  const ticketing=createTicketing(state.pool,provider);
  // An explicit fixture price and fixture fee, never a production default.
  await ticketing.fee({...team.user,emailVerified:true},{basis_points:500,version:0});
  const host=fixtures.users['host.a'],profile=fixtures.profiles['host.a'].id;
  await ticketing.connection(host,profile,{connected:true});
  const start=new Date(Date.now()+48*3600000).toISOString();
  const event=await state.directory.saveEvent(host,datedEventFixture({title:'Demo Ticketabend · pretix',community_id:fixtures.community,
    status:'published',is_public:true,starts_at:start,starts_public:true,public_location:'Demo Kulturhalle',location_public:true,
    exact_location:'Synthetischer Hintereingang · kein echter Ort',event_content:{description:'Synthetischer Ticketabend. Kein echter Verkauf.',minimum_age:18,ends_at:new Date(Date.parse(start)+4*3600000).toISOString()}}));
  await ticketing.configure(host,event.id,{mode:'public',price_cents:1250,quota:3,item_name:'Demo Eintritt',version:0});
  await declareTicketFixture(state.pool,host,event.id);
}finally{await state.pool.end();await tickets.end();}
