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
const evidence=path.resolve(process.argv[3]??'/private/tmp/community-access-native-ticketing-evidence');mkdirSync(evidence,{recursive:true});
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
 stage('Flutter -> native checkout');const {p:g,token}=await fresh('guest.a');
 g.on('response',r=>{if(r.url().includes('/community-access/entry/')||r.url().endsWith('/handoff'))console.log('Handoff response:',r.request().method(),r.status());});
 g.on('console',m=>{if(m.type()==='error')console.log('Browser error:',m.text().replace(/[a-f0-9]{64}/g,'[redacted]').slice(0,400));});
 await click(g,'Zur Hauptseite');await click(g,'Event ansehen: Demo Ticketabend · pretix');
 const age=g.getByRole('checkbox',{name:'Ich erfülle das Mindestalter von 18 Jahren.',exact:true});await age.scrollIntoViewIfNeeded();await age.click();
 const purchased=await postClick(g,'Eigenes Ticket kaufen','/checkout');assert.equal(purchased.native_pretix,true);
 await click(g,'pretix-Checkout vorbereiten');await btn(g,'pretix-Checkout öffnen').waitFor();
 const next=g.context().waitForEvent('page');await click(g,'pretix-Checkout öffnen');const native=await next;await native.waitForLoadState('domcontentloaded');
 assert.match(native.url(),/^http:\/\/127\.0\.0\.1:8400\/demo\/e[a-f0-9]{32}\/checkout\//);
 checks.push('Flutter account and browser-bound handoff opens existing native pretix cart');
 await native.locator('input[name=email]').fill('guest.a@example.invalid');await native.getByRole('button',{name:'Continue',exact:true}).click();
 await native.getByRole('checkbox',{name:'Erfolgreiche Testzahlung simulieren'}).check();await native.getByRole('button',{name:'Continue',exact:true}).click();
 await native.getByRole('button',{name:'Place binding order',exact:true}).click();
 await native.waitForURL(/\/order\//);await native.waitForLoadState('domcontentloaded');
 const nativeText=await native.locator('body').innerText();assert.ok(!nativeText.includes('CHECKOUT_DENIED'));
 await native.screenshot({path:path.join(evidence,'native-order.png'),fullPage:true});
 await click(g,'Zahlungsstatus prüfen');await g.getByText('Bezahlt · Teilnahme bestätigt',{exact:true}).last().waitFor();
 checks.push('native checkout confirms simulated card payment; platform reads native paid order');
 // Inspect the native PDF download and exercise actual session protection.
 const downloadLink=native.getByRole('button',{name:'Download ticket (PDF)',exact:true});
 if(await downloadLink.count()){
   const downloaded=native.waitForEvent('download');await downloadLink.click();
   const file=await downloaded;assert.equal(await file.failure(),null);
   const bytes=readFileSync(await file.path());assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
   checks.push('native PDF ticket downloaded in authorized session');
 }else{throw Error('Native PDF download missing');}
 const copied=native.url();const other=await browser.newContext();const denied=await other.request.get(copied);assert.equal(denied.status(),403);
 const index=await other.request.get(purchased.native_checkout_entry.replace('/community-access/entry/','/'));assert.equal(index.status(),403);await other.close();
 checks.push('native event pages require personal binding, including private ticket information');
 checks.push('forwarded native order URL denied in another browser session');
 const withdrawn=await g.request.post(`http://127.0.0.1:${backendPort}/api/directory/events/${purchased.event_id}/withdraw`,{headers:{Authorization:'Bearer '+token,Origin:'http://127.0.0.1:8300'},data:{}});assert.equal(withdrawn.status(),200);
 const locked=await native.context().request.get(copied);assert.equal(locked.status(),403);
 checks.push('withdrawal blocks existing native order/download session');
 await g.setViewportSize({width:320,height:900});await g.screenshot({path:path.join(evidence,'native-platform-mobile.png')});
 assert.deepEqual(errors,[]);writeFileSync(path.join(evidence,'browser-result.json'),JSON.stringify({passed:true,date:new Date().toISOString(),browser:await browser.version(),ui:`http://127.0.0.1:${uiPort}`,checks,pageErrors:0},null,2)+'\n');console.log('PASS: '+checks.length+' native ticketing browser checkpoints');
}catch(error){console.error(JSON.stringify({phase,error:error.name,message:error.message.replace(/[a-f0-9]{64}/g,'[redacted]').replace(/\/order\/[^\s]+/g,'/order/[redacted]')}));process.exitCode=1;
 for(const p of browser.contexts().flatMap(c=>c.pages()))await p.screenshot({path:path.join(evidence,'failure-'+browser.contexts().indexOf(p.context())+'.png')}).catch(()=>{});
}finally{await browser.close();await new Promise(r=>server.close(r));}
