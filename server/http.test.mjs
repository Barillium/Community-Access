import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { createApp } from './http.mjs';

test('localhost dashboard alias preserves host and origin boundaries', async () => {
  const forwarded = [];
  const server = createApp({
    dashboardEnabled: true,
    mailbox: [],
    auth: { handler: async (request) => {
      forwarded.push({ url: request.url, authorization: request.headers.get('authorization') });
      return Response.json({ code: 'UNAUTHORIZED' }, { status: 401 });
    } },
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = `http://127.0.0.1:${server.address().port}`;
  const call = (path, host, origin) => new Promise((resolve, reject) => {
    const pending = request(address + path, {
      headers: { Host: host, Connection: 'close', ...(origin ? { Origin: origin } : {}) },
    }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('error', reject);
      response.on('end', () => resolve({
        status: response.statusCode, headers: response.headers, json: () => JSON.parse(body),
      }));
    });
    pending.on('error', reject);
    pending.end();
  });
  try {
    for (const host of ['127.0.0.1:8000', 'localhost:8000']) {
      assert.equal((await call('/health', host)).status, 200);
    }
    for (const host of ['example.invalid:8000', 'localhost.example.invalid:8000', 'localhost:8300']) {
      const response = await call('/health', host);
      assert.equal(response.status, 403);
      assert.deepEqual(await response.json(), { code: 'LOCAL_ONLY' });
    }
    const dash = await call('/api/auth/dash/validate?check=synthetic', 'localhost:8000', 'https://dash.better-auth.com');
    assert.equal(dash.status, 401);
    assert.equal(dash.headers['access-control-allow-origin'], 'https://dash.better-auth.com');
    assert.deepEqual(forwarded, [{
      url: 'http://127.0.0.1:8000/api/auth/dash/validate?check=synthetic', authorization: null,
    }]);
    assert.equal((await call('/api/auth/dash/validate', 'localhost:8000', 'https://example.invalid')).status, 403);
    assert.equal((await call('/api/auth/sign-up/email', 'localhost:8000', 'https://dash.better-auth.com')).status, 403);
    assert.equal(forwarded.length, 1);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('larger event media budget is restricted to the existing event write route',async()=>{
 const server=createApp({dashboardEnabled:false,mailbox:[],directory:{accessFlow:{purge:async()=>({deleted:0})},discovery:{purge:async()=>({deleted:0})},saveEvent:async()=>({id:'synthetic'})},auth:{api:{getSession:async()=>({user:{id:'synthetic',emailVerified:true}})}}});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const call=(path,size)=>new Promise((resolve,reject)=>{
  const req=request(`http://127.0.0.1:${server.address().port}/api/${path}`,{method:'POST',headers:{Host:'127.0.0.1:8000','Content-Type':'application/json',Connection:'close'}},res=>{
   let raw='';res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(raw)}));res.on('error',reject);
  });req.on('error',reject);req.end(JSON.stringify({demo:'x'.repeat(size)}));
 });
 try{
  assert.equal((await call('directory/manage/event',350000)).status,200);
  assert.equal((await call('directory/manage/event',400000)).status,413);
  assert.equal((await call('auth/sign-in/email',17000)).status,413);
  assert.equal((await call('directory/manage/profile',17000)).status,413);
 }finally{await new Promise(resolve=>server.close(resolve));}
});
