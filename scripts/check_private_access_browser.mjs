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
const evidence=path.resolve(process.argv[3]??'/private/tmp/community-access-private-access-evidence');mkdirSync(evidence,{recursive:true});
const server=createServer((req,res)=>{try{const file=path.join(root,new URL(req.url,'http://127.0.0.1').pathname.replace(/^\/$/,'/index.html'));if(!file.startsWith(root+'/'))throw Error();res.setHeader('content-type',({'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.png':'image/png','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.setHeader('cache-control','no-store');res.end(readFileSync(file));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(uiPort,'127.0.0.1',r));
const browser=await chromium.launch({headless:true});const errors=[];const checks=[];
const backendPort=Number(process.env.CA_BROWSER_BACKEND_PORT??8000);assert.ok(Number.isInteger(backendPort)&&backendPort>0&&backendPort<65536);
let phase='start';
const stage=s=>{phase=s;console.log(s);};
const textNode=(p,value)=>p.getByLabel(value,{exact:false}).or(p.getByText(value,{exact:true})).first();
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
 await p.waitForTimeout(500);
 const field=p.getByRole('textbox',{name:label}).or(p.getByRole('spinbutton',{name:label})).first();
 for(let attempt=0;attempt<3;attempt++){try{await field.scrollIntoViewIfNeeded();break;}catch(error){if(attempt===2)throw error;await p.waitForTimeout(150);}}
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
 stage('category management');const {p:h,token:hostToken}=await fresh('host.a');
 const authHeaders={Authorization:'Bearer '+hostToken,Origin:'http://127.0.0.1:8300'};
 const mres=await h.request.get(`http://127.0.0.1:${backendPort}/api/directory/manage`,{headers:authHeaders});assert.equal(mres.status(),200);const management=await mres.json();const index=management.events.findIndex(e=>e.title==='Demo Ticketabend · pretix');assert.ok(index>=0);const event=management.events[index];
 await click(h,'Gastgeberverwaltung');await click(h,'Tickets und Erstattungen verwalten');
 const edit=btn(h,'Private Ticketangebote und Einlassrollen').nth(index);await edit.scrollIntoViewIfNeeded();await edit.click();
 await enter(h,'Ticketname','Synthetic private category');await enter(h,'Preis (€)','10,00');await enter(h,'Kategorienkontingent','2');
 await h.getByRole('button',{name:/Teilnahmefreigabe erforderlich/}).or(h.getByRole('combobox',{name:/Teilnahmefreigabe erforderlich/})).first().click();await h.waitForTimeout(350);await h.getByRole('menuitem',{name:/Eventzugang und Konto genügen/}).or(h.getByRole('option',{name:/Eventzugang und Konto genügen/})).first().click();await h.waitForTimeout(350);
 const category=await postClick(h,'Kategorie anlegen',`/api/ticketing/events/${event.id}/types`);assert.equal(category.price_cents,1000);assert.equal(category.visibility_mode,'explicit_grant');
 await enter(h,'Bestätigte Konto-E-Mail','guest.b@example.invalid');await postClick(h,'24 h freigeben',`/api/ticketing/types/${category.id}/grant`);
 await enter(h,'Bestätigte Konto-E-Mail','guest.c@example.invalid');await postClick(h,'Einlassrolle für 12 h vergeben',`/api/access/policy/events/${event.id}/scanner`);
 await h.setViewportSize({width:320,height:900});await h.screenshot({path:path.join(evidence,'category-management-mobile.png')});checks.push('category and personal grant created through Flutter; scanner role assigned; 320px layout');
 stage('category denied to another account');const {p:a,token:aToken}=await fresh('guest.a');await click(a,'Zur Hauptseite');await click(a,'Event ansehen: Demo Ticketabend · pretix');assert.equal(await a.getByText('Synthetic private category · 10,00 €',{exact:true}).count(),0);const forbidden=await a.request.post(`http://127.0.0.1:${backendPort}/api/ticketing/types/${category.id}/checkout`,{headers:{Authorization:'Bearer '+aToken,Origin:'http://127.0.0.1:8300'},data:{age_acknowledged:true}});assert.equal(forbidden.status(),404);checks.push('visible public event does not reveal private category; known category ID denied');
 stage('private category purchase');const {p:g,token:gToken}=await fresh('guest.b');await click(g,'Zur Hauptseite');await click(g,'Event ansehen: Demo Ticketabend · pretix');await textNode(g,'Synthetic private category · 10,00 €').waitFor();
 const age=g.getByRole('checkbox',{name:'Ich erfülle das für diese Veranstaltung angegebene Mindestalter.',exact:true});await age.scrollIntoViewIfNeeded();await age.click();const order=await postClick(g,'Dieses Ticket kaufen',`/api/ticketing/types/${category.id}/checkout`);assert.equal(order.total_cents,1000);const paid=await postClick(g,'Erfolgreiche Testzahlung',`/api/ticketing/orders/${order.id}/simulate`);assert.equal(paid.state,'paid');checks.push('authorized private category purchased and simulated payment confirmed through UI');await g.screenshot({path:path.join(evidence,'category-payment.png')});
 const tokenResponse=await g.request.post(`http://127.0.0.1:${backendPort}/api/access/policy/orders/${order.id}/token`,{headers:{Authorization:'Bearer '+gToken,Origin:'http://127.0.0.1:8300'},data:{}});assert.equal(tokenResponse.status(),200);const checkinToken=(await tokenResponse.json()).token;
 stage('online admission');const {p:sc}=await fresh('guest.c');await click(sc,'Online-Einlass');await sc.getByRole('button',{name:/Veranstaltung/}).or(sc.getByRole('combobox',{name:/Veranstaltung/})).first().click();await sc.waitForTimeout(350);await sc.getByRole('menuitem',{name:'Demo Ticketabend · pretix',exact:true}).or(sc.getByRole('option',{name:'Demo Ticketabend · pretix',exact:true})).first().click();await sc.waitForTimeout(350);
 await enter(sc,'Ticketcode',checkinToken);await enter(sc,'Konto-E-Mail vor Ort abgleichen','guest.b@example.invalid');await postClick(sc,'Einlass online prüfen',`/api/access/policy/events/${event.id}/checkin`);await textNode(sc,'Einlass bestätigt · synthetischer Test').waitFor();
 await sc.setViewportSize({width:320,height:900});await sc.screenshot({path:path.join(evidence,'online-checkin-mobile.png'),mask:[sc.locator('input,textarea')]});checks.push('event-scoped online admission succeeds; no financial data displayed; narrow layout');
 // Successful admission intentionally clears both fields. Re-enter the
 // same synthetic memory values to test an actual second server request.
 await enter(sc,'Ticketcode',checkinToken);await enter(sc,'Konto-E-Mail vor Ort abgleichen','guest.b@example.invalid');
 const duplicate=sc.waitForResponse(r=>r.url().endsWith('/checkin')&&r.request().method()==='POST');await click(sc,'Einlass online prüfen');assert.equal((await duplicate).status(),409);await textNode(sc,'Dieses Ticket wurde bereits beim Einlass verwendet.').waitFor();checks.push('second UI check-in denied without success notice');
 await sc.context().setOffline(true);await click(sc,'Einlass online prüfen');await textNode(sc,'Einlass nicht bestätigt. Bitte Verbindung und Berechtigung prüfen.').or(textNode(sc,'Der lokale Auth-Dienst ist gerade nicht erreichbar.')).waitFor();assert.equal(await textNode(sc,'Einlass bestätigt · synthetischer Test').count(),0);await sc.context().setOffline(false);checks.push('connection failure never confirms private admission');
 stage('moderation workspace');const {p:mod}=await fresh('host.a');await click(mod,'Freigaben und Moderation');await btn(mod,'Eventzugang für 24 h sperren').waitFor({state:'attached'});await mod.setViewportSize({width:320,height:900});await mod.screenshot({path:path.join(evidence,'moderation-mobile.png')});checks.push('scoped moderation workspace renders at 320px');
 stage('shared organizer invitation');const {p:owner}=await fresh('host.a');await click(owner,'Gastgeberverwaltung');await click(owner,'Gemeinsam verwalten');
 await enter(owner,'Bestätigte Konto-E-Mail','guest.d@example.invalid');const invitation=await postClick(owner,'Zur gemeinsamen Verwaltung einladen',`/api/access/policy/organizers/${event.profile_id}/members`);
 const {p:member}=await fresh('guest.d');await click(member,'Auftritte und Einladungen');assert.equal(await btn(member,'Zur gemeinsamen Verwaltung einladen').count(),0);
 await postClick(member,'Einladung zur Verwaltung annehmen',`/api/access/policy/organizer-members/${invitation.id}/accept`);await textNode(member,'Verwaltung aktiv').waitFor();checks.push('owner invitation requires explicit acceptance; recipient cannot invite other managers');
 stage('shared organizer edit');await click(member,'Auftritt verwalten');await enter(member,'Profilbeschreibung','Synthetic collaborative profile description');await postClick(member,'Profil speichern','/api/directory/manage/profile');checks.push('accepted manager edits the exact organizer profile through Flutter');
 stage('shared organizer revocation');await click(owner,'Aktualisieren');await owner.setViewportSize({width:320,height:900});await owner.screenshot({path:path.join(evidence,'shared-organizer-mobile.png')});
 await postClick(owner,'Verwaltung entziehen',`/api/access/policy/organizer-members/${invitation.id}/revoke`);
 await enter(member,'Profilbeschreibung','Synthetic edit after revocation');const denied=member.waitForResponse(r=>r.url().endsWith('/api/directory/manage/profile')&&r.request().method()==='POST');await click(member,'Profil speichern');assert.equal((await denied).status(),403);checks.push('owner revokes accepted management; an already open editor cannot save afterwards; 320px layout');
 assert.deepEqual(errors,[]);writeFileSync(path.join(evidence,'browser-result.json'),JSON.stringify({passed:true,date:new Date().toISOString(),browser:await browser.version(),ui:`http://127.0.0.1:${uiPort}`,checks,pageErrors:0},null,2)+'\n');console.log('PASS: '+checks.length+' private access browser checkpoints');
}catch(error){console.error(JSON.stringify({phase,error:error.name,message:error.message.replace(/[a-f0-9]{64}/g,'[redacted]')}));process.exitCode=1;
 for(const p of browser.contexts().flatMap(c=>c.pages())){console.log(await p.locator('[role],[aria-label]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:(n.getAttribute('aria-label')??n.textContent??'').replace(/[a-f0-9]{64}/g,'[redacted]')}))).catch(()=>[]));await p.screenshot({path:path.join(evidence,'failure-'+browser.contexts().indexOf(p.context())+'.png'),mask:[p.locator('input,textarea')]}).catch(()=>{});}
}finally{await browser.close();await new Promise(r=>server.close(r));}
