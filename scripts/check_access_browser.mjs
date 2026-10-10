// Run only against the fresh synthetic --access-demo and a finished local Flutter build.
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
const evidence=path.resolve(process.argv[3]??'/private/tmp/community-access-browser-evidence');mkdirSync(evidence,{recursive:true});
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
async function fresh(key){const p=await browser.newPage({viewport:{width:1440,height:1100},timezoneId:'Europe/Berlin'});if(backendPort!==8000||uiPort!==8300)await p.route('http://127.0.0.1:8000/**',async route=>{const original=route.request();const response=await route.fetch({url:original.url().replace('127.0.0.1:8000',`127.0.0.1:${backendPort}`),headers:{...original.headers(),host:'127.0.0.1:8000',origin:'http://127.0.0.1:8300',referer:'http://127.0.0.1:8300/'}});await route.fulfill({response,headers:{...response.headers(),'access-control-allow-origin':`http://127.0.0.1:${uiPort}`}});});p.setDefaultTimeout(12000);p.on('pageerror',()=>errors.push(phase));p.on('response',r=>{const pathname=new URL(r.url()).pathname;if(pathname==='/api/account/me'||pathname==='/api/access/policy/staff')console.log('Network:',r.request().method(),pathname,r.status());});await p.goto(`http://127.0.0.1:${uiPort}/`);
 // The responsive account menu is a presentation step; neither it nor language
 // selection starts a session. Desktop can expose the same sign-in directly.
 await btn(p,'Konto').or(btn(p,'Anmelden')).first().waitFor({state:'visible'});
 if(await btn(p,'Konto').count())await click(p,'Konto');
 const email=p.getByRole('textbox',{name:'E-Mail',exact:true});
 if(!await email.count())await btn(p,'Anmelden').first().click();
 await email.waitFor({state:'visible'});await enter(p,'E-Mail',key+'@example.invalid');await enter(p,'Passwort','Synthetic-2026!');const r=p.waitForResponse(r=>r.url().endsWith('/api/auth/sign-in/email'));await click(p,'Anmelden');const res=await r;assert.equal(res.status(),200);const token=res.headers()['set-auth-token'];assert.ok(token,'Successful sign-in must provide an in-memory session');await btn(p,'Zugang verwalten').waitFor({state:'visible'});await click(p,'Zugang verwalten');await btn(p,'Veranstalteraufnahme').waitFor();return {p,token};}
async function fieldValue(p,label){const field=p.getByRole('textbox',{name:label,exact:true});await field.scrollIntoViewIfNeeded();await p.waitForTimeout(300);await field.focus();await p.waitForTimeout(150);const value=await p.locator('input:focus,textarea:focus').inputValue();await p.keyboard.press('Tab');await p.waitForTimeout(100);return value;}
async function enterDate(p,label,value){const d=new Date(value);const parts=new Intl.DateTimeFormat('de-DE',{timeZone:'Europe/Berlin',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(d);const part=k=>parts.find(x=>x.type===k).value;await enter(p,label+': Datum',`${part('day')}.${part('month')}.${part('year')}`);await enter(p,label+': Uhrzeit',`${part('hour')}:${part('minute')}`);}
async function check(p,name){const target=p.getByRole('checkbox',{name,exact:true});await target.scrollIntoViewIfNeeded();await p.waitForTimeout(300);await target.click();await p.getByRole('checkbox',{name,exact:true,checked:true}).waitFor();await p.waitForTimeout(300);}
const refresh=async p=>{
 await p.bringToFront();
 // Flutter resumes rendering and semantics when a different test tab returns.
 await p.waitForTimeout(500);
 // Observe the same refresh action together with its request so a locator
 // failure cannot leave an unhandled response-wait promise behind.
 const [response]=await Promise.all([
  p.waitForResponse(r=>r.url().endsWith('/api/account/me')&&r.request().method()==='GET'),
  click(p,'Aktualisieren'),
 ]);
 assert.equal(response.status(),200,'Refresh must recheck the current account');
};
async function select(p,label,value){
 const control=p.getByRole('button',{name:new RegExp(label)}).or(p.getByRole('combobox',{name:new RegExp(label)})).first();
 await control.scrollIntoViewIfNeeded();await p.waitForTimeout(300);await control.click();
 const choice=p.getByRole('menuitem',{name:value,exact:true}).or(p.getByRole('option',{name:value,exact:true})).first();
 await choice.waitFor({state:'visible'});await choice.click();await p.waitForTimeout(300);
}

try{
 stage('organizer submission');const {p:o,token:organizerSession}=await fresh('organizer');await click(o,'Veranstalteraufnahme');await enter(o,'Name des Kollektivs','Demo Browserkollektiv');await enter(o,'Selbstdarstellung','Synthetischer Browsernachweis');await enter(o,'Veranstaltungstypen','Musik und Performance');await o.getByText('Awarenesskonzept vorhanden?',{exact:true}).click();await o.getByRole('menuitem',{name:'Ja',exact:true}).click();await o.getByText('Awarenessteam vorhanden?',{exact:true}).click();await o.getByRole('menuitem',{name:'Nein',exact:true}).click();const application=await postClick(o,'Veranstalterbewerbung einreichen','/api/access/organizer-applications');checks.push('organizer submitted through UI');
 stage('team approval');const {p:t}=await fresh('team');await click(t,'Teamprüfung');const approved=await postClick(t,'Veranstalter aufnehmen',`/api/access/organizer-applications/${application.id}/decide`);assert.ok(approved.community_id);checks.push('team approved through UI');await t.screenshot({path:path.join(evidence,'team-approved.png')});
 stage('explicit community responsibilities');
 // Organizer admission creates a host/profile, never moderation or publication
 // authority. Build both prerequisites through the same scoped team UI.
 await refresh(o);assert.equal(await btn(o,'Communityverwaltung').count(),0);
 await click(t,'Back');await click(t,'Freigaben und Moderation');
 await select(t,'Zuständige Community','Demo Browserkollektiv');
 await enter(t,'Bestätigte Konto-E-Mail','organizer@example.invalid');
 const assigned=await postClick(t,'Moderation für 24 h zuweisen','/api/access/policy/staff');assert.equal(assigned.assigned,true);
 const currentRole=await o.request.get(`http://127.0.0.1:${backendPort}/api/account/me`,{headers:{Authorization:'Bearer '+organizerSession,Host:'127.0.0.1:8000'}});
 assert.equal(currentRole.status(),200);assert.ok((await currentRole.json()).moderated_communities.some(c=>c.id===approved.community_id),'Explicit team assignment must grant exactly the tested community');
 await refresh(o);await btn(o,'Communityverwaltung').waitFor({state:'visible'});
 await click(o,'Back');await click(o,'Freigaben und Moderation');
 await select(o,'Zuständige Community','Demo Browserkollektiv');
 await select(o,'Veranstalterauftritt für Veröffentlichungsrecht','Demo Browserkollektiv');
 const publisher=await postClick(o,'Veröffentlichungsrecht vergeben',`/api/access/policy/communities/${approved.community_id}/publishers`);assert.equal(publisher.enabled,true);
 await click(o,'Back');await click(o,'Zugang verwalten');
 checks.push('team separately assigns scoped moderation; assigned moderator explicitly enables organizer publication');
 stage('community form');await refresh(o);await click(o,'Communityverwaltung');await o.getByText('Community auswählen',{exact:true}).click();await o.getByRole('menuitem',{name:'Demo Browserkollektiv',exact:true}).click();await check(o,'Was interessiert dich an unserem Programm?');await enter(o,'Kontakttext für abgelehnte Gäste','Synthetischer Demokontakt');await postClick(o,'Formular speichern',`/api/access/communities/${approved.community_id}/form`);
 stage('personal invitation');await enter(o,'E-Mail des bestätigten Gastkontos','guest.a@example.invalid');const invitation=await postClick(o,'Persönliche Einladung erstellen',`/api/access/communities/${approved.community_id}/invite`);checks.push('host form and bound personal invitation through UI');
 stage('event creation');
 await click(o,'Veranstalterprofile und Events verwalten');
 await click(o,'Eventangaben hinzufügen');
 await enter(o,'Eventtitel','Demo Browserabend');
 await click(o,'Zurück zur Verwaltung');
 await click(o,'Entwurf behalten');
 await click(o,'Eventangaben hinzufügen');
 assert.equal(await fieldValue(o,'Eventtitel'),'Demo Browserabend');
 checks.push('event draft kept and restored through UI');
 await o.getByRole('button',{name:/Veröffentlichungsstatus/}).click();
 await o.getByRole('menuitem',{name:'Veröffentlicht',exact:true}).click();
 await enterDate(o,'Beginn',new Date(Date.now()+86400000).toISOString());
 await enterDate(o,'Ende',new Date(Date.now()+90000000).toISOString());
 await enterDate(o,'Öffentliche Anfragefrist',new Date(Date.now()+43200000).toISOString());
 await enter(o,'Mindestalter (optional)','18');
 await enter(o,'Geschützte genaue Location','Geschützter synthetischer Browserort');
 await enter(o,'Platzkapazität (leer = unbegrenzt)','1');
 await check(o,'Aktive Communitymitgliedschaft erforderlich');
 const originalDate=await fieldValue(o,'Beginn: Datum');
 const originalTime=await fieldValue(o,'Beginn: Uhrzeit');
 await o.screenshot({path:path.join(evidence,'host-event-dates.png')});
 const event=await postClick(o,'Eventangaben speichern','/api/directory/manage/event');
 checks.push('member event capacity and location created through UI with local date/time controls and publication confirmation');
 await o.getByRole('textbox',{name:'Eigene Events suchen',exact:true}).scrollIntoViewIfNeeded();
 await o.waitForTimeout(300);
 await o.getByText('0 offene Anfragen · 0 Zusagen',{exact:true}).waitFor();
 await o.getByText('1 freie Plätze von 1',{exact:true}).waitFor();
 await o.screenshot({path:path.join(evidence,'host-event-overview.png')});
 await click(o,'Event duplizieren');
 assert.equal(await fieldValue(o,'Eventtitel'),'Demo Browserabend – Kopie');
 assert.equal(await fieldValue(o,'Beginn: Datum'),'');
 await click(o,'Zurück zur Verwaltung');
 await click(o,'Entwurf verwerfen');
 await click(o,'Folgetermin vorbereiten');
 await click(o,'In einer Woche');
 assert.equal(await fieldValue(o,'Eventtitel'),'Demo Browserabend');
 const [day,month,year]=originalDate.split('.').map(Number);
 const nextDate=new Date(Date.UTC(year,month-1,day+7));
 const two=n=>String(n).padStart(2,'0');
 assert.equal(await fieldValue(o,'Beginn: Datum'),`${two(nextDate.getUTCDate())}.${two(nextDate.getUTCMonth()+1)}.${nextDate.getUTCFullYear()}`);
 assert.equal(await fieldValue(o,'Beginn: Uhrzeit'),originalTime);
 await o.screenshot({path:path.join(evidence,'host-next-event.png')});
 await o.setViewportSize({width:320,height:900});
 await o.waitForTimeout(500);
 await fieldValue(o,'Beginn: Datum');
 await o.screenshot({path:path.join(evidence,'host-next-event-mobile.png')});
 await o.setViewportSize({width:1440,height:1100});
 await o.waitForTimeout(500);
 await click(o,'Zurück zur Verwaltung');
 await click(o,'Entwurf verwerfen');
 checks.push('copies omit the date; weekly follow-up preserves local time; both remain unpublished drafts');
 stage('guest application');const {p:g,token:guestSession}=await fresh('guest.a');await enter(g,'Persönliche Einladung',invitation.url);await postClick(g,'Einladung prüfen','/api/access/invitations/preview');await enter(g,'Was interessiert dich an unserem Programm?','Synthetische Browserantwort');const guestApplication=await postClick(g,'Gastbewerbung einreichen','/api/access/applications');checks.push('guest application through UI');
 stage('guest admission');await click(o,'Back');await refresh(o);await btn(o,'Gast aufnehmen').waitFor();await postClick(o,'Gast aufnehmen',`/api/access/applications/${guestApplication.id}/decide`);

 checks.push('manual guest membership through UI');
 stage('event request and pre-approval denial');await refresh(g);await check(g,'Ich bestätige, mindestens 18 Jahre alt zu sein.');const locUrl=`http://127.0.0.1:${backendPort}/api/access/events/${event.id}/location`;let response=await g.request.get(locUrl,{headers:{Authorization:'Bearer '+guestSession,Host:'127.0.0.1:8000'}});assert.equal(response.status(),404);await postClick(g,'Interesse bekunden',`/api/directory/events/${event.id}/interest`);checks.push('location denied before separate attendance approval');
 stage('attendance approval');await click(o,'Veranstalterprofile und Events verwalten');await click(o,'Verwaltung neu laden');await postClick(o,'Teilnahme zusagen','/api/directory/manage/interest');await refresh(g);await btn(g,'Geschützte Location abrufen').waitFor();await g.getByText('Teilnahme zugesagt',{exact:true}).waitFor();const loaded=g.waitForResponse(r=>r.url()===locUrl.replace(`:${backendPort}/`,':8000/')); await click(g,'Geschützte Location abrufen');response=await loaded;assert.equal(response.status(),200);assert.equal(response.headers()['cache-control'],'no-store');await g.getByText('Geschützter synthetischer Browserort',{exact:true}).waitFor();await g.screenshot({path:path.join(evidence,'confirmed-location.png')});await click(g,'Schließen');checks.push('location freshly retrieved after attendance approval through UI');
 stage('membership revocation');await click(o,'Back');await refresh(o);await click(o,'Mitgliedschaft entziehen');const revoked=o.waitForResponse(r=>r.url().endsWith('/revoke')&&r.request().method()==='POST');await click(o,'Entziehen');assert.equal((await revoked).status(),200);await refresh(g);await g.getByText('Demo Browserkollektiv · Mitgliedschaft entzogen',{exact:true}).waitFor();assert.equal(await btn(g,'Geschützte Location abrufen').count(),0);response=await g.request.get(locUrl,{headers:{Authorization:'Bearer '+guestSession,Host:'127.0.0.1:8000'}});assert.equal(response.status(),404);assert.equal(response.headers()['cache-control'],'no-store');await g.screenshot({path:path.join(evidence,'revoked-access.png')});await g.setViewportSize({width:320,height:900});await g.screenshot({path:path.join(evidence,'revoked-mobile.png')});checks.push('membership revoked through UI and new location retrieval denied');
 assert.deepEqual(errors,[]);writeFileSync(path.join(evidence,'browser-result.json'),JSON.stringify({passed:true,date:new Date().toISOString(),browser:await browser.version(),ui:`http://127.0.0.1:${uiPort}`,api:`http://127.0.0.1:${backendPort}`,localTransportAdapter:backendPort!==8000||uiPort!==8300,checks,pageErrors:errors.length},null,2)+'\n');console.log('PASS: '+checks.length+' browser checkpoints');
} catch(error){
 console.error(JSON.stringify({phase,error:error.name,message:error.message.replace(/[a-f0-9]{64}/g,'[redacted]')}));
 let index=0;for(const context of browser.contexts())for(const page of context.pages()){
  try{await page.screenshot({path:path.join(evidence,`failed-${index++}.png`),mask:[page.locator('input,textarea')]});}catch{}
 }
 process.exitCode=1;
}finally{await browser.close();await new Promise(r=>server.close(r));}
