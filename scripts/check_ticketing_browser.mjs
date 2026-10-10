// Run only against the fresh synthetic --ticketing-demo and a finished local Flutter build.
// Tokens remain in memory and are never persisted or logged.
import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
if(!process.env.CA_PLAYWRIGHT_MODULE)throw new Error('CA_PLAYWRIGHT_MODULE must point to an existing Playwright module; no installation is performed.');
const {chromium}=require(process.env.CA_PLAYWRIGHT_MODULE);
const uiPort=Number(process.env.CA_BROWSER_UI_PORT??8300);assert.ok(Number.isInteger(uiPort)&&uiPort>0&&uiPort<65536);
const root=path.resolve(process.argv[2]??'client/build/web');
const evidence=path.resolve(process.argv[3]??'/private/tmp/community-access-ticketing-evidence');mkdirSync(evidence,{recursive:true});
const server=createServer((req,res)=>{try{const file=path.join(root,new URL(req.url,'http://127.0.0.1').pathname.replace(/^\/$/,'/index.html'));if(!file.startsWith(root+'/'))throw Error();res.setHeader('content-type',({'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.png':'image/png','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.setHeader('cache-control','no-store');res.end(readFileSync(file));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(uiPort,'127.0.0.1',r));
const browser=await chromium.launch({headless:true});const errors=[];const checks=[];
const backendPort=Number(process.env.CA_BROWSER_BACKEND_PORT??8000);assert.ok(Number.isInteger(backendPort)&&backendPort>0&&backendPort<65536);
let phase='start';
const stage=s=>{phase=s;console.log(s);};
// Flutter's built-in back tooltip follows the selected app locale.
const btn=(p,name)=>name==='Schließen'
 ?p.getByRole('dialog').or(p.getByRole('alertdialog')).getByRole('button',{name,exact:true})
 :p.getByRole('button',{name:name==='Back'?/^(Back|Zurück)$/:name==='Aktualisieren'?/^Aktualisieren(?:\s+Aktualisieren)?$/:name,exact:true});
// Retry only preparation while Flutter replaces semantic nodes. A dispatched
// click is never repeated: it can already have caused a successful write.
const click=async(p,name)=>{
 await p.bringToFront();await p.waitForTimeout(350);const target=btn(p,name);
 await target.waitFor({state:'visible'});
 for(let attempt=0;attempt<3;attempt++){
  try{await target.scrollIntoViewIfNeeded();break;}catch(error){if(attempt===2)throw error;await p.waitForTimeout(150);}
 }
 await p.waitForTimeout(150);await target.click();await p.waitForTimeout(350);
};
async function enter(p,label,value){
 console.log('Field:',label);
 const field=p.getByRole('textbox',{name:label}).or(p.getByRole('spinbutton',{name:label})).first();
 await field.scrollIntoViewIfNeeded();
 await p.waitForTimeout(300);
 await field.focus();
 await p.waitForTimeout(150);
 // Flutter replaces the named semantics input while its editing control is focused.
 const focused=p.locator('input:focus,textarea:focus');
 await focused.waitFor({state:'attached'});
 await p.keyboard.press(process.platform==='darwin'?'Meta+A':'Control+A');
 await p.keyboard.press('Backspace');
 await p.keyboard.insertText(value);
 await p.waitForTimeout(150);
 assert.ok(await focused.inputValue()===value,'Field input differs: '+label);
 await p.keyboard.press('Tab');
 await p.waitForTimeout(100);
}
async function postClick(p,name,suffix){const r=p.waitForResponse(r=>r.url().endsWith(suffix)&&r.request().method()==='POST');const action=async()=>{await click(p,name);if(suffix==='/api/directory/manage/event')await click(p,'Veröffentlichen');};const [res]=await Promise.all([r,action()]);assert.equal(res.status(),200,phase);return res.json();}
async function fresh(key){
 const p=await browser.newPage({viewport:{width:1440,height:1000},timezoneId:'Europe/Berlin'});
 p.setDefaultTimeout(15000);p.on('pageerror',()=>errors.push(phase));
 await p.goto(`http://127.0.0.1:${uiPort}/`);
 // The responsive account menu is a presentation step; neither it nor language
 // selection starts a session. Desktop can expose the same sign-in directly.
 await btn(p,'Konto').or(btn(p,'Anmelden')).first().waitFor({state:'visible'});
 if(await btn(p,'Konto').count())await click(p,'Konto');
 const email=p.getByRole('textbox',{name:'E-Mail',exact:true});
 if(!await email.count())await btn(p,'Anmelden').first().click();
 await email.waitFor({state:'visible'});
 await enter(p,'E-Mail',key+'@example.invalid');await enter(p,'Passwort','Synthetic-2026!');
 const response=p.waitForResponse(r=>r.url().endsWith('/api/auth/sign-in/email'));await click(p,'Anmelden');
 const r=await response;assert.equal(r.status(),200);const token=r.headers()['set-auth-token'];assert.ok(token,'Successful sign-in must provide an in-memory session');
 // Optional preferences never interrupt the authenticated account route.
 await btn(p,'Zugang verwalten').waitFor({state:'visible'});return {p,token};
}
try{
 stage('guest public purchase');const {p:g,token}=await fresh('guest.a');
 await click(g,'Zur Hauptseite');
 if(process.env.CA_EXPECT_PRODUCT_EDITION==='v1'){
  for(const [width,height] of [[1440,1000],[390,844]]){
   await g.setViewportSize({width,height});await g.waitForTimeout(400);
   for(const name of ['Veranstaltungsorte','Merkliste','Meine Präferenzen','Semi-öffentlich'])assert.equal(await g.getByText(name,{exact:true}).count(),0,'Deferred V1 control: '+name);
   await g.screenshot({path:path.join(evidence,`v1-home-${width}.png`)});
   checks.push(`V1 scope visible at ${width} pixels`);
  }
  await g.setViewportSize({width:1440,height:1000});await g.waitForTimeout(400);
 }
 await click(g,'Event ansehen: Demo Ticketabend · pretix');
 const age=g.getByRole('checkbox',{name:'Ich erfülle das Mindestalter von 18 Jahren.',exact:true});await age.scrollIntoViewIfNeeded();await age.click();
 const purchased=await postClick(g,'Eigenes Ticket kaufen','/checkout');assert.equal(purchased.state,'pending');
 checks.push('confirmed account starts personal public checkout through UI');
 await g.getByText('Synthetische Zahlung · es wird kein Geld bewegt',{exact:true}).waitFor();
 const paid=await postClick(g,'Erfolgreiche Testzahlung','/simulate');assert.equal(paid.state,'paid');
 checks.push('simulated payment confirmed by server through UI');await g.screenshot({path:path.join(evidence,'payment-confirmed.png')});
 await click(g,'Zurück zum Event');await click(g,'Geschützte Location abrufen');
 await g.getByText('Synthetischer Hintereingang · kein echter Ort',{exact:true}).waitFor();await click(g,'Schließen');
 checks.push('protected location retrieved only after payment');await click(g,'Back');await click(g,'Dein Konto');await click(g,'Meine Tickets');
 await click(g,'Ticket anzeigen');await g.getByText('Testbeleg · kein gültiges Eintrittsticket',{exact:true}).waitFor();
 await g.screenshot({path:path.join(evidence,'synthetic-ticket.png')});await click(g,'Schließen');
 await g.setViewportSize({width:320,height:900});await g.waitForTimeout(400);await g.screenshot({path:path.join(evidence,'my-tickets-mobile.png')});
 checks.push('own ticket document and narrow ticket list displayed');
 // Synthetic cancellation stimulus; approval and cent amount go through host UI.
 const revoked=await g.request.post(`http://127.0.0.1:${backendPort}/api/directory/events/${purchased.event_id}/withdraw`,{headers:{Authorization:'Bearer '+token,Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300'},data:{}});assert.equal(revoked.status(),200);
 stage('organizer partial/full refund');const {p:h}=await fresh('host.a');
 await click(h,'Gastgeberverwaltung');await click(h,'Tickets und Erstattungen verwalten');
 await h.getByText('Testkonto verbunden',{exact:true}).waitFor();await click(h,'Erstattung prüfen und genehmigen');
 await enter(h,'Erstattungsbetrag in Cent','625');await postClick(h,'Erstattung bestätigen','/approve');
 await h.getByText('Provision 0,63 € · zurückgegeben 0,32 €',{exact:true}).first().waitFor();
 checks.push('host approves partial refund including proportional fee through UI');await h.screenshot({path:path.join(evidence,'partial-refund.png')});
 await click(h,'Erstattung prüfen und genehmigen');await postClick(h,'Erstattung bestätigen','/approve');
 checks.push('host approves remaining refund through UI');await h.screenshot({path:path.join(evidence,'full-refund.png')});
 stage('platform team fee');const {p:t}=await fresh('team');await click(t,'Plattformprovision verwalten');
 await t.screenshot({path:path.join(evidence,'platform-fee.png')});checks.push('platform team fee settings displayed');
 assert.deepEqual(errors,[]);writeFileSync(path.join(evidence,'browser-result.json'),JSON.stringify({passed:true,date:new Date().toISOString(),browser:await browser.version(),ui:`http://127.0.0.1:${uiPort}`,checks,pageErrors:0},null,2)+'\n');console.log('PASS: '+checks.length+' ticketing browser checkpoints');
}catch(error){console.error(JSON.stringify({phase,error:error.name,message:error.message.replace(/[a-f0-9]{64}/g,'[redacted]')}));process.exitCode=1;
 for(const p of browser.contexts().flatMap(c=>c.pages())){await p.screenshot({path:path.join(evidence,'failure-'+browser.contexts().indexOf(p.context())+'.png')}).catch(()=>{});console.log((await p.locator('body').innerText()).slice(-3500));}
}finally{await browser.close();await new Promise(r=>server.close(r));}
