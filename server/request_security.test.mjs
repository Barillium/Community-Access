import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {createApp} from './http.mjs';
import {createRequestLimits,createSecuritySummary,createRetentionJob} from './request_security.mjs';

const listen=server=>new Promise((resolve,reject)=>{
  server.once('error',reject);server.listen(0,'127.0.0.1',resolve);
});
const close=server=>new Promise(resolve=>server.close(resolve));
const call=(server,path,{method='GET',body,headers={}}={})=>new Promise((resolve,reject)=>{
  const req=request({hostname:'127.0.0.1',port:server.address().port,path,method,
    headers:{Host:'127.0.0.1:8000',Connection:'close','Content-Type':'application/json',...headers}},res=>{
    let text='';res.setEncoding('utf8');res.on('data',chunk=>text+=chunk);
    res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:JSON.parse(text)}));
    res.on('error',reject);
  });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
});
const directoryFixture=()=>({
  accessFlow:{purge:async()=>{},route:async()=>({ok:true})},
  discovery:{purge:async()=>{}},catalog:{publicEvents:async()=>({events:[]})},
});

test('global and account limits recover, share writes across routes and fail closed at key capacity',()=>{
  let time=1000;
  const limits=createRequestLimits({now:()=>time,globalMax:2,authMax:1,accountMax:3,writeMax:1,maxKeys:8});
  assert.equal(limits.global(),null);assert.equal(limits.global(),null);
  assert.deepEqual(limits.global(),{retryAfter:59});
  assert.equal(limits.auth(),null);assert.deepEqual(limits.auth(),{retryAfter:59});
  const user={id:'synthetic-a'};
  assert.equal(limits.account(user,'POST'),null);
  assert.ok(limits.account(user,'POST'));
  assert.equal(limits.account(user,'GET'),null);
  assert.equal(limits.account(user,'GET'),null);
  assert.ok(limits.account(user,'GET'));
  assert.equal(limits.account({id:'synthetic-b'},'GET'),null);
  time=60000;
  assert.equal(limits.global(),null);assert.equal(limits.account(user,'POST'),null);
  const bounded=createRequestLimits({maxKeys:1});
  assert.equal(bounded.account(user,'GET'),null);
  assert.ok(bounded.account({id:'synthetic-b'},'GET'));
  for(const invalid of [0,-1,Infinity,1.5])assert.throws(()=>createRequestLimits({globalMax:invalid}));
});

test('cleanup does not overlap a still-running branch when the other branch fails',async()=>{
  let calls=0,failures=0,release;
  const pending=new Promise(resolve=>release=resolve);
  const cleanup=createRetentionJob({discovery:{purge:async()=>{calls++;throw new Error('private details');}},
    accessFlow:{purge:async()=>{calls++;await pending;}}},()=>failures++);
  const first=cleanup();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(calls,2);assert.equal(failures,0);
  assert.equal(cleanup(),first);assert.equal(calls,2);
  release();await first;assert.equal(failures,1);
  await cleanup();assert.equal(calls,4);assert.equal(failures,2);
});

test('anonymous catalog throttles before session/database work despite spoofed proxy headers',async()=>{
  let sessions=0,queries=0;
  const directory=directoryFixture();
  directory.catalog.publicEvents=async()=>{queries++;return {events:[]};};
  const server=createApp({mailbox:[],directory,requestLimits:createRequestLimits({globalMax:2}),
    auth:{api:{getSession:async()=>{sessions++;return null;}}}});
  await listen(server);
  try{
    for(let i=0;i<3;i++){
      const response=await call(server,'/api/directory/events?q=synthetic',{headers:{
        'X-Forwarded-For':`192.0.2.${i}`,'CF-Connecting-IP':`192.0.2.${i}`,
        'X-User-ID':`synthetic-${i}`}});
      assert.equal(response.status,i<2?200:429);
      if(i===2){assert.ok(Number(response.headers['retry-after'])>0);assert.deepEqual(response.body,{code:'RATE_LIMITED'});}
    }
    assert.equal(sessions,2);assert.equal(queries,2);
    assert.equal((await call(server,'/health')).status,200);
  }finally{await close(server);}
});

test('account identity is server validated; changing tokens does not evade write limits',async()=>{
  let mutations=0;
  const directory=directoryFixture();
  directory.accessFlow.route=async()=>{mutations++;return {ok:true};};
  const server=createApp({mailbox:[],directory,requestLimits:createRequestLimits({writeMax:1}),
    auth:{api:{getSession:async({headers})=>({user:{id:headers.get('authorization')==='Bearer other-account'?'b':'a'}})}}});
  await listen(server);
  try{
    const first=await call(server,'/api/access/first',{method:'POST',body:{},headers:{Authorization:'Bearer first-session'}});
    assert.equal(first.status,200);
    const second=await call(server,'/api/access/other-route',{method:'POST',body:{},headers:{Authorization:'Bearer replacement-session'}});
    assert.equal(second.status,429);
    assert.equal((await call(server,'/api/access/other-route',{method:'POST',body:{},headers:{Authorization:'Bearer other-account'}})).status,200);
    assert.equal(mutations,2);
  }finally{await close(server);}
});

test('auth budget protects account-link processing before consuming any token',async()=>{
  let consumed=0;
  const server=createApp({mailbox:[],requestLimits:createRequestLimits({authMax:1}),
    consumeLink:async()=>{consumed++;return null;},auth:{}});
  await listen(server);
  try{
    const args={method:'POST',body:{email:'synthetic@example.invalid',token:'a'.repeat(64)}};
    assert.equal((await call(server,'/api/account/verify',args)).status,422);
    assert.equal((await call(server,'/api/account/reset',args)).status,429);
    assert.equal(consumed,1);
  }finally{await close(server);}
});

test('security summaries are bounded, contain no request values and keep error responses redacted',async()=>{
  const emitted=[];
  const server=createApp({mailbox:[],onSecuritySummary:s=>emitted.push(s),
    auth:{api:{getSession:async()=>{throw new Error('private-address token password');}}}});
  await listen(server);
  try{
    const response=await call(server,'/api/account/me',{headers:{Authorization:'Bearer synthetic-private-token'}});
    assert.equal(response.status,503);assert.deepEqual(response.body,{code:'AUTH_SERVICE_UNAVAILABLE'});
    assert.equal(response.headers['x-frame-options'],'DENY');
    assert.equal(response.headers['cache-control'],'no-store');
    assert.match(response.headers['content-security-policy'],/default-src 'none'/);
    assert.equal(response.headers['permissions-policy'],'camera=(), microphone=(), geolocation=()');
    assert.equal(emitted.length,0);
  }finally{await close(server);}
  assert.deepEqual(emitted,[{event:'security_summary',counts:{unavailable:1}}]);
  const summary=createSecuritySummary(s=>emitted.push(s));
  summary.record('private-address token password');summary.flush();
  assert.equal(emitted.length,1);
  summary.record('cleanup_failed');summary.flush();summary.flush();
  assert.equal(emitted.length,2);
});

test('busy requests do not enter auth; cancellation does not release still-running work',{timeout:10000},async()=>{
  let entered=0;
  let resolveSession;
  const pendingSession=new Promise(resolve=>resolveSession=resolve);
  const server=createApp({mailbox:[],auth:{api:{getSession:async()=>{entered++;return pendingSession;}}}});
  await listen(server);
  const requests=Array.from({length:15},()=>call(server,'/api/account/me'));
  const cancelled=request({hostname:'127.0.0.1',port:server.address().port,path:'/api/account/me',
    headers:{Host:'127.0.0.1:8000',Connection:'close'}},()=>{});
  cancelled.on('error',()=>{});cancelled.end();
  try{
    // Let all requests reach the held session lookup without a fixed sleep.
    while(entered<16)await new Promise(resolve=>setImmediate(resolve));
    cancelled.destroy();await new Promise(resolve=>setImmediate(resolve));
    const busy=await call(server,'/api/account/me');
    assert.equal(busy.status,503);assert.deepEqual(busy.body,{code:'BUSY'});
    assert.equal(busy.headers['retry-after'],'1');assert.equal(entered,16);
    resolveSession(null);
    assert.ok((await Promise.all(requests)).every(r=>r.status===401));
    assert.equal((await call(server,'/api/account/me')).status,401);
  }finally{resolveSession(null);await Promise.allSettled(requests);await close(server);}
});
