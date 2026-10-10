// Run only against the fresh synthetic --native-ticketing-demo and a finished local Flutter build.
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
const evidence=path.resolve(process.argv[3]??'/private/tmp/community-access-legal-ticketing-evidence');mkdirSync(evidence,{recursive:true});
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
try {
 stage('open unpaid native checkout');
 const {p:g,token}=await fresh('guest.b');await click(g,'Zur Hauptseite');await click(g,'Event ansehen: Demo Ticketabend · pretix');
 const age=g.getByRole('checkbox',{name:'Ich erfülle das Mindestalter von 18 Jahren.',exact:true});await age.scrollIntoViewIfNeeded();await g.waitForTimeout(300);await age.click();
 const purchased=await postClick(g,'Eigenes Ticket kaufen','/checkout');
 await g.getByText('Synthetischer Ticketverkäufer',{exact:true}).first().waitFor();
 await click(g,'pretix-Checkout vorbereiten');await btn(g,'pretix-Checkout öffnen').waitFor();
 const next=g.context().waitForEvent('page');await click(g,'pretix-Checkout öffnen');const native=await next;await native.waitForLoadState('domcontentloaded');const checkoutURL=native.url();
 assert.equal((await native.context().request.get(checkoutURL)).status(),200);
 checks.push('seller snapshot shown and unpaid native checkout already open');
 stage('anonymous mobile report');
 const anon=await browser.newPage({viewport:{width:390,height:844}});anon.setDefaultTimeout(15000);anon.on('pageerror',()=>errors.push(phase));
 await anon.goto(`http://127.0.0.1:${uiPort}/`);await click(anon,'Hilfe & Kontakt');await click(anon,'Veranstaltung melden');
 assert.equal(await btn(anon,'Meldung einreichen').isDisabled(),true);
 await enter(anon,'Inhaltsreferenz','events/'+purchased.event_id);
 await enter(anon,'Warum könnte das Angebot rechtswidrig sein?','Synthetic browser permission concern');
 await enter(anon,'Dein Name','Synthetic browser reporter');await enter(anon,'Kontakt-E-Mail','bad');
 const faith=anon.getByRole('checkbox',{name:'Ich melde nach bestem Wissen und halte meine Angaben für richtig und vollständig.',exact:true});await faith.scrollIntoViewIfNeeded();await anon.waitForTimeout(300);await faith.click();
 await click(anon,'Meldung einreichen');await anon.getByText('Synthetische E-Mail mit @example.invalid erforderlich.',{exact:true}).waitFor();
 await anon.waitForTimeout(400);await anon.screenshot({path:path.join(evidence,'report-validation-mobile.png')});
 await enter(anon,'Kontakt-E-Mail','reporter@example.invalid');
 const response=anon.waitForResponse(r=>r.url().endsWith('/api/legal/reports')&&r.request().method()==='POST');await click(anon,'Meldung einreichen');const receipt=await response;assert.equal(receipt.status(),200);assert.equal(receipt.request().headers()['authorization'],undefined);
 const reported=await receipt.json();assert.equal(reported.received,true);await anon.getByText('Meldung empfangen: '+reported.reference,{exact:true}).last().waitFor();await anon.screenshot({path:path.join(evidence,'report-received-mobile.png')});
 checks.push('anonymous mobile submission, initially unchecked good faith and visible contact validation');
 stage('organizer declaration');const {p:h}=await fresh('host.a');await click(h,'Gastgeberverwaltung');await click(h,'Tickets und Erstattungen verwalten');await click(h,'Verkäuferangaben');
 await h.getByRole('textbox',{name:'Vollständiger Verkäufername',exact:true}).waitFor();await h.waitForTimeout(400);await h.screenshot({path:path.join(evidence,'seller-management.png')});await click(h,'Back');
 const declarationButton=h.getByText('Demo Ticketabend · pretix',{exact:true}).locator('xpath=following::flt-semantics[@role="button"][normalize-space(.)="Veranstalterbestätigung"][1]');await declarationButton.scrollIntoViewIfNeeded();await h.waitForTimeout(300);await declarationButton.click();
 const declaration=h.getByRole('checkbox').first();assert.equal(await declaration.isChecked(),false);assert.equal(await btn(h,'Bestätigung speichern').isDisabled(),true);await h.waitForTimeout(400);await h.screenshot({path:path.join(evidence,'declaration-unchecked.png')});
 checks.push('seller management separate from event location and organizer confirmation not preselected');
 await h.setViewportSize({width:390,height:844});
 const responsibility=h.getByRole('checkbox',{name:/Ich bestätige, dass ich als Veranstalter und Ticketverkäufer die Verantwortung/});
 await btn(h,'Bestätigung speichern').scrollIntoViewIfNeeded();await h.waitForTimeout(400);
 assert.equal(await responsibility.isChecked(),false);await h.screenshot({path:path.join(evidence,'declaration-responsibility-mobile.png')});
 await responsibility.click();const acknowledged=await postClick(h,'Bestätigung speichern','/declaration');
 assert.equal(acknowledged.ready,true);assert.equal(acknowledged.terms_version,'local-responsibility-draft-20261009');assert.equal(acknowledged.declaration.terms_version,acknowledged.terms_version);
 await h.getByText('Bestätigung gespeichert.',{exact:true}).last().waitFor();
 assert.equal(await responsibility.isChecked(),false);
 checks.push('explicit organizer responsibility acknowledgement saves matching text version on mobile without an official permission review');

 stage('team review and sales pause');const {p:t}=await fresh('team');await click(t,'Veranstaltungsmeldungen prüfen');await t.getByRole('button',{name:new RegExp('events/'+purchased.event_id)}).first().click();await click(t,'Bearbeitung übernehmen');
 await enter(t,'Event-ID zur Prüfung',purchased.event_id);await enter(t,'Begründung und Rechts- oder Regelgrundlage','Synthetic browser permit clarification');
 await click(t,'Begründete Entscheidung speichern');await t.getByText('Demo Ticketabend · pretix',{exact:true}).waitFor();
 const decided=await postClick(t,'Begründete Entscheidung speichern','/decision');assert.equal(decided.legal_state,'sales_paused');
 await t.setViewportSize({width:390,height:844});await t.waitForTimeout(400);await t.screenshot({path:path.join(evidence,'team-decision-mobile.png')});
 const denied=await native.context().request.get(checkoutURL);assert.equal(denied.status(),403);assert.ok((await denied.text()).includes('CHECKOUT_DENIED'));
 const order=await g.request.get(`http://127.0.0.1:${backendPort}/api/ticketing/orders/${purchased.id}`,{headers:{Authorization:'Bearer '+token,Origin:'http://127.0.0.1:8300'}});assert.equal(order.status(),200);const stopped=await order.json();assert.equal(stopped.blocked,true);assert.equal(stopped.legal_stopped,true);
 checks.push('assigned independent team decides using displayed event version; existing native session denied after pause');
 await click(t,'Back');await click(t,'Lokales Testpostfach');await t.getByText(/reporter@example.invalid/).first().waitFor();await t.screenshot({path:path.join(evidence,'synthetic-notices.png')});
 checks.push('synthetic receipt and decision visible in local team mailbox');
 // Also exercise keyboard focus on the general form, without submitting another report.
 await click(anon,'Back');await click(anon,'Veranstaltung melden');await enter(anon,'Inhaltsreferenz','events/synthetic-keyboard');await anon.keyboard.press('Tab');
 assert.equal(await anon.locator('input:focus,textarea:focus,flt-semantics[tabindex="0"]:focus').count()>0,true);
 await anon.screenshot({path:path.join(evidence,'report-keyboard-mobile.png')});checks.push('report form supports keyboard traversal');
 assert.deepEqual(errors,[]);writeFileSync(path.join(evidence,'browser-result.json'),JSON.stringify({passed:true,date:new Date().toISOString(),browser:await browser.version(),checks,pageErrors:0},null,2)+'\n');console.log('PASS: '+checks.length+' legal ticketing browser checkpoints');
}catch(error){console.error(JSON.stringify({phase,error:error.name,message:error.message.replace(/[a-f0-9]{64}/g,'[redacted]').replace(/\/order\/[^\s]+/g,'/order/[redacted]')}));process.exitCode=1;
 for(const p of browser.contexts().flatMap(c=>c.pages()))await p.screenshot({path:path.join(evidence,'failure-'+browser.contexts().indexOf(p.context())+'.png')}).catch(()=>{});
}finally{await browser.close();await new Promise(r=>server.close(r));}
