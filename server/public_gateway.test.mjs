import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { mkdtemp, writeFile, mkdir, symlink, rm } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createPublicGateway } from './public_gateway.mjs';
import {createRequestLimits} from './request_security.mjs';

const origin = 'https://communityaccess.de';
const listen = server => new Promise((accept,reject) => {
  server.once('error',reject); server.listen(0,'127.0.0.1',accept);
});
const close = server => new Promise(accept => server.close(accept));

test('public HTTPS gateway excludes test/admin routes and preserves only fixed social handoff', async () => {
  const root = await mkdtemp(join(realpathSync(tmpdir()),'ca-public-test-'));
  await mkdir(join(root,'assets'));
  await mkdir(join(root,'assets','packages','ca_design','fonts'),{recursive:true});
  await writeFile(join(root,'assets','packages','ca_design','fonts','Archivo%5Bwdth,wght%5D.ttf'),'Synthetic font fixture');
  await writeFile(join(root,'index.html'),'<title>Synthetic release</title>');
  for(const name of ['favicon.svg','favicon.png','social-preview.png','impressum.html','datenschutz.html']) {
    await writeFile(join(root,name),'Synthetic public asset');
  }
  await writeFile(join(root,'public-release.json'),JSON.stringify({apiOrigin:origin,uiOrigin:origin,privateMail:true}));
  await writeFile(join(root,'private.txt'),'synthetic-secret-not-public');
  await symlink(join(root,'private.txt'),join(root,'assets','linked.txt'));
  let health = {synthetic:false,dashboardEnabled:false,apiOrigin:origin,uiOrigin:origin,databaseRestricted:true,securityControls:{apiRateLimits:true,mailBudget:true}};
  let redirect = origin + '/#social=success';
  const forwarded = [];
  const upstream = createServer((req,res) => {
    if (req.url === '/health') {res.setHeader('Content-Type','application/json'); return res.end(JSON.stringify(health));}
    forwarded.push({url:req.url,method:req.method,host:req.headers.host,cookie:req.headers.cookie});
    if (req.url.startsWith('/api/auth/callback/')) {
      res.writeHead(302,{'Location':redirect,'Set-Cookie':'synthetic=bridge; Secure; HttpOnly; SameSite=None'});
      return res.end();
    }
    res.writeHead(200,{'Content-Type':'application/json','set-auth-token':'synthetic-signed-session'});
    res.end('{"synthetic":true}');
  });
  await listen(upstream);
  let gateway;
  const config = {webRoot:root,upstreamPort:upstream.address().port};
  try {
    health.synthetic = true;
    await assert.rejects(createPublicGateway(config), /Private HTTPS/);
    health.synthetic = false; health.dashboardEnabled = true;
    await assert.rejects(createPublicGateway(config), /Private HTTPS/);
    health.dashboardEnabled = false; health.uiOrigin = 'https://foreign.example.test';
    await assert.rejects(createPublicGateway(config), /Private HTTPS/);
    health.uiOrigin = origin;
    health.databaseRestricted = false;
    await assert.rejects(createPublicGateway(config), /Private HTTPS/);
    health.databaseRestricted = true;
    health.securityControls.mailBudget=false;
    await assert.rejects(createPublicGateway(config),/Private HTTPS/);
    health.securityControls.mailBudget=true;
    gateway = await createPublicGateway(config);
    await listen(gateway);
    const call = (path,{method='GET',host='communityaccess.de',body='',...headers}={}) => new Promise((accept,reject) => {
      const pending = request({hostname:'127.0.0.1',port:gateway.address().port,path,method,
        headers:{Host:host,Connection:'close','X-Forwarded-Proto':'https',...headers}},res => {
        let text = ''; res.setEncoding('utf8'); res.on('data',chunk => {text += chunk;});
        res.on('end',() => accept({status:res.statusCode,headers:res.headers,body:text}));
        res.on('error',reject);
      });
      pending.on('error',reject); pending.end(body);
    });
    const page=await call('/');assert.equal(page.status,200);
    assert.match(page.headers['content-security-policy'],/default-src 'self'/);
    assert.match(page.headers['content-security-policy'],/connect-src 'self';/);
    assert.match(page.headers['content-security-policy'],/frame-ancestors 'none'/);
    assert.equal(page.headers['permissions-policy'],'camera=(), microphone=(), geolocation=()');
    for(const name of ['favicon.svg','favicon.png','social-preview.png','impressum.html','datenschutz.html']) {
      assert.equal((await call('/'+name)).status,200,name);
    }
    const font=await call('/assets/packages/ca_design/fonts/Archivo%255Bwdth,wght%255D.ttf');
    assert.equal(font.status,200);assert.equal(font.body,'Synthetic font fixture');
    for(const denied of ['/assets/packages/ca_design/fonts/Archivo%5Bwdth,wght%5D.ttf',
      '/assets/packages/ca_design/fonts/Archivo%252e%252e.ttf',
      '/assets/packages/ca_design/fonts/%252e%252e/private.txt']){
      assert.equal((await call(denied)).status,404);
    }
    assert.equal((await call('/',{host:'127.0.0.1:8400'})).status,403);
    for(const protocol of ['http','https, http','HTTPS','']){
      const denied=await call('/api/auth/callback/google?code=synthetic&state=synthetic',{'X-Forwarded-Proto':protocol});
      assert.equal(denied.status,403);assert.equal(denied.headers.location,undefined);
      assert.deepEqual(JSON.parse(denied.body),{code:'HTTPS_REQUIRED'});
    }
    for (const path of ['/health','/testing/mailbox','/api/auth/dash/user',
      '/api/directory/manage','/public-release.json','/private.txt','/assets/linked.txt',
      '/api/auth/../sign-in/email','/api/auth/%2e%2e/sign-in/email','//api/account/me',
      '/api/account/me%3Fq=1','/api\\account/me','/assets/../private.txt']) {
      assert.equal((await call(path)).status,404,path);
    }
    assert.equal(forwarded.length,0);
    assert.equal((await call('/api/account/me',{method:'POST'})).status,405);
    assert.equal((await call('/api/account/me?x=1')).status,400);
    assert.equal((await call('/api/account/social/start',{method:'POST',Origin:'https://foreign.example.test'})).status,403);
    assert.equal((await call('/api/account/social/start',{method:'POST',body:'x'.repeat(16385)})).status,413);
    assert.equal(forwarded.length,0);
    const handoff = await call('/api/account/social/session',{method:'POST',Origin:origin,
      Cookie:'synthetic=bridge','Content-Type':'application/json',body:'{}'});
    assert.equal(handoff.status,200);
    assert.equal(handoff.headers['set-auth-token'],'synthetic-signed-session');
    assert.equal(forwarded[0].host,'communityaccess.de');
    assert.equal(forwarded[0].cookie,'synthetic=bridge');
    const apple = await call('/api/auth/callback/apple',{method:'POST',Origin:'https://appleid.apple.com',
      'Content-Type':'application/x-www-form-urlencoded',body:'code=synthetic&state=synthetic'});
    assert.equal(apple.status,302);
    assert.equal(apple.headers.location,origin + '/#social=success');
    assert.match(apple.headers['set-cookie'][0], /Secure; HttpOnly/);
    for (const target of ['https://[malformed','https://foreign.example.test/','http://communityaccess.de/',
      origin + '/#code=synthetic',origin + '/?code=synthetic#social=success',origin + '/other#social=success']) {
      redirect = target;
      assert.equal((await call('/api/auth/callback/google?code=synthetic&state=synthetic')).status,502);
    }
    health.synthetic = true;
    const before = forwarded.length;
    assert.equal((await call('/api/account/me')).status,503);
    assert.equal(forwarded.length,before);
  } finally {
    if (gateway) await close(gateway);
    await close(upstream);
    await rm(root,{recursive:true,force:true});
  }
});

test('gateway limits API before probes, isolates assets and preserves backend Retry-After',async()=>{
  const root=await mkdtemp(join(realpathSync(tmpdir()),'ca-rate-test-'));
  await writeFile(join(root,'index.html'),'<title>Synthetic release</title>');
  await writeFile(join(root,'public-release.json'),JSON.stringify({apiOrigin:origin,uiOrigin:origin,privateMail:true}));
  let probes=0,calls=0;
  const upstream=createServer((req,res)=>{
    if(req.url==='/health'){
      probes++;res.end(JSON.stringify({synthetic:false,dashboardEnabled:false,apiOrigin:origin,
        uiOrigin:origin,databaseRestricted:true,securityControls:{apiRateLimits:true,mailBudget:true}}));return;
    }
    calls++;res.writeHead(429,{'Content-Type':'application/json','Retry-After':'17'});
    res.end(JSON.stringify({code:'AUTH_REQUEST_FAILED'}));
  });
  await listen(upstream);
  let gateway;
  try{
    gateway=await createPublicGateway({webRoot:root,upstreamPort:upstream.address().port,
      requestLimits:createRequestLimits({globalMax:1}),staticLimits:createRequestLimits({globalMax:2})});
    await listen(gateway);
    const call=path=>new Promise((resolve,reject)=>{
      const req=request({hostname:'127.0.0.1',port:gateway.address().port,path,
        headers:{Host:'communityaccess.de',Connection:'close','X-Forwarded-Proto':'https','CF-Connecting-IP':'192.0.2.7'}},res=>{
        res.resume();res.on('end',()=>resolve({status:res.statusCode,headers:res.headers}));
      });req.on('error',reject);req.end();
    });
    const first=await call('/api/account/me');assert.equal(first.status,429);
    assert.equal(first.headers['retry-after'],'17');
    assert.equal((await call('/api/account/me')).status,429);
    assert.equal(probes,2);assert.equal(calls,1);
    assert.equal((await call('/')).status,200);assert.equal((await call('/')).status,200);
    assert.equal((await call('/')).status,429);assert.equal(probes,2);
  }finally{if(gateway)await close(gateway);await close(upstream);await rm(root,{recursive:true,force:true});}
});
