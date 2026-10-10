import {Pool} from 'pg';
import {syntheticPretixServer,createSyntheticPretix} from './synthetic_pretix.mjs';

if(process.env.CA_TICKETING_SYNTHETIC!=='true'||process.env.NODE_ENV!=='development'||
  !/^\/(?:private\/)?tmp\/ca-auth-[^/]+$/.test(process.env.CA_DATABASE_SOCKET??''))throw new Error('Explicit local synthetic startup required.');
const pool=new Pool({host:process.env.CA_DATABASE_SOCKET,port:55440,user:'pretix_app',database:'community_tickets',max:4,
  statement_timeout:5000,connectionTimeoutMillis:3000,idle_in_transaction_session_timeout:10000});
const server=syntheticPretixServer(createSyntheticPretix(pool),process.env.CA_PRETIX_TOKEN);
let stop;
const close=()=>stop??=(async()=>{await new Promise(resolve=>server.close(resolve));await pool.end();})();
server.on('error',async()=>{await close();process.exitCode=1;});
server.listen(8400,'127.0.0.1',()=>console.log('Synthetischer Ticketdienst bereit: http://127.0.0.1:8400 (kein echtes pretix)'));
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,close);
