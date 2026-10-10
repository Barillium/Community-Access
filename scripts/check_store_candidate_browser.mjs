// Local synthetic browser preview only; no native-device or payment acceptance.
import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
if(!process.env.CA_PLAYWRIGHT_MODULE)throw Error('Use an existing Playwright installation.');
const {chromium}=require(process.env.CA_PLAYWRIGHT_MODULE);
const root=path.resolve(process.argv[2]);
const evidence=path.resolve(process.argv[3]??'.local/store-launch/browser');
assert.ok(readFileSync(path.join(root,'candidate.json'),'utf8').includes('"store_ready": false'));
mkdirSync(evidence,{recursive:true});
const server=createServer((req,res)=>{
 const uri=new URL(req.url,'http://127.0.0.1');
 if(uri.pathname.startsWith('/api/')){
  res.setHeader('content-type','application/json');
  if(uri.pathname==='/api/directory/home')return res.end(JSON.stringify({signed_in:false,events:[],hero:[]}));
  if(uri.pathname==='/api/directory/events')return res.end(JSON.stringify({events:[],series:[],page:1,has_more:false}));
  if(uri.pathname.includes('providers'))return res.end(JSON.stringify({providers:[]}));
  res.writeHead(401);return res.end(JSON.stringify({code:'UNAUTHORIZED',message:'Synthetic preview: no account session.'}));
 }
 try{
  const file=path.resolve(root,'.'+(uri.pathname==='/'?'/index.html':uri.pathname));
  assert.ok(file.startsWith(root+'/'));
  res.setHeader('content-type',({'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.png':'image/png','.svg':'image/svg+xml'})[path.extname(file)]??'application/octet-stream');
  res.end(readFileSync(file));
 }catch{res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const origin='http://127.0.0.1:'+server.address().port;
const browser=await chromium.launch({headless:true});
const checks=[],errors=[],external=[];
try{
 for(const [label,width,height] of [['phone',390,844],['tablet',768,1024],['desktop',1440,1000]]){
  const page=await browser.newPage({viewport:{width,height},locale:'de-DE'});
  page.setDefaultTimeout(20000);
  page.on('pageerror',e=>errors.push({label,message:e.message.slice(0,200)}));
  await page.route('**/*',route=>{const url=new URL(route.request().url());if(url.origin===origin)return route.continue();external.push(url.origin);return route.abort();});
  // Redirect the compiled public API origin to the local synthetic responder.
  // The candidate files themselves are unchanged; no public server is contacted.
  await page.addInitScript(({origin})=>{
   const open=XMLHttpRequest.prototype.open;
   XMLHttpRequest.prototype.open=function(method,url,...rest){const target=new URL(String(url),location.href);if(target.origin==='https://communityaccess.de')url=origin+target.pathname+target.search;return open.call(this,method,url,...rest);};
   const fetchOriginal=window.fetch;
   window.fetch=function(input,init){if(typeof input==='string'&&input.startsWith('https://communityaccess.de/'))input=origin+input.slice('https://communityaccess.de'.length);return fetchOriginal.call(this,input,init);};
  },{origin});
  await page.goto(origin);
  const account=page.getByRole('button',{name:/^(Konto|Anmelden)$/}).first();
  await account.waitFor({state:'visible'});
  await page.screenshot({path:path.join(evidence,label+'-home.png')});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Horizontal overflow: '+label);
  await account.click();
  const email=page.getByRole('textbox',{name:'E-Mail',exact:true});
  if(!await email.count())await page.getByRole('button',{name:'Anmelden',exact:true}).first().click();
  await email.waitFor({state:'visible'});
  assert.equal(await email.inputValue(),'','No demo email in store candidate');
  await page.getByRole('button',{name:'Konto anlegen',exact:true}).click();
  const age=page.getByRole('checkbox',{name:/mindestens 16 Jahre/});
  await age.scrollIntoViewIfNeeded();await age.waitFor({state:'visible'});
  assert.equal(await age.getAttribute('aria-checked'),'false');
  await page.screenshot({path:path.join(evidence,label+'-registration.png')});
  checks.push(label+': home, blank account email, explicit unchecked age-16 confirmation, no horizontal page overflow');
  await page.close();
 }
 const page=await browser.newPage({viewport:{width:390,height:844}});
 for(const name of ['support','konto-loeschen']){
  await page.goto(origin+'/'+name+'.html');
  assert.ok(await page.locator('a[href^="mailto:info@communityaccess.de"]').count());
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.screenshot({path:path.join(evidence,name+'-phone.png'),fullPage:true});
  checks.push(name+': public contact route and mobile layout');
 }
 assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
 writeFileSync(path.join(evidence,'report.json'),JSON.stringify({scope:'Local Chromium browser with synthetic API responses; no native device acceptance',checks,page_errors:errors,external_requests:external,native_device_tested:false,published:false},null,2)+'\n');
 console.log(JSON.stringify({passed:checks.length,evidence,native_device_tested:false}));
}finally{await browser.close();await new Promise(r=>server.close(r));}
