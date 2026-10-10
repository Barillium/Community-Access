import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';

test('store account deletion is authenticated, idempotent and preserves the account without automatic erasure', async t => {
  const state = await createAuth();
  const server = createApp(state);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const call = (path, body, token) => new Promise((resolve,reject) => {
    const req = request(`http://127.0.0.1:${server.address().port}${path}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300',
        'Content-Type':'application/json',Connection:'close',
        ...(token ? {Authorization:`Bearer ${token}`} : {})},
    }, res => {let raw='';res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,data:JSON.parse(raw)}));});
    req.on('error',reject);req.end(body === undefined ? undefined : JSON.stringify(body));
  });
  try {
    const password='Synthetic-2026!';
    const email='deletion.store@example.invalid';
    await call('/api/auth/sign-up/email',{name:'Synthetic account',email,password});
    const login=await call('/api/auth/sign-in/email',{email,password});
    const token=login.headers['set-auth-token'];assert.ok(token);
    await t.test('anonymous requests and forged target IDs are denied',async()=>{
      assert.equal((await call('/api/account/deletion',{confirmation:'DELETE_ACCOUNT'})).status,401);
      assert.equal((await call('/api/account/deletion',{confirmation:'DELETE_ACCOUNT',user_id:'other'},token)).status,422);
      assert.equal((await call('/api/account/deletion',{},token)).status,422);
      assert.equal((await call('/api/account/deletion',{confirmation:'DELETE_ACCOUNT',password:'wrong-password'},token)).status,403);
      assert.equal((await call('/api/account/deletion',undefined,token)).data.request,null);
    });
    await t.test('parallel retries return one durable request and never claim deletion',async()=>{
      const responses=await Promise.all(Array.from({length:4},()=>call('/api/account/deletion',{confirmation:'DELETE_ACCOUNT',password},token)));
      assert.ok(responses.every(r=>r.status===200));
      assert.equal(new Set(responses.map(r=>r.data.request.id)).size,1);
      assert.ok(responses.every(r=>r.data.account_deleted===false));
      assert.equal((await state.pool.query('SELECT COUNT(*)::int AS n FROM ca_account_deletion_request')).rows[0].n,1);
      assert.equal((await call('/api/account/deletion',undefined,token)).data.request.status,'requested');
      assert.equal((await call('/api/account/me',undefined,token)).status,200);
      assert.equal((await state.pool.query('SELECT COUNT(*)::int AS n FROM "user" WHERE email=$1',[email])).rows[0].n,1);
    });
    await t.test('another account cannot read the request',async()=>{
      const other='other.store@example.invalid';
      await call('/api/auth/sign-up/email',{name:'Other synthetic',email:other,password});
      const second=(await call('/api/auth/sign-in/email',{email:other,password})).headers['set-auth-token'];
      assert.equal((await call('/api/account/deletion',undefined,second)).data.request,null);
      assert.equal((await call('/api/account/deletion/queue',undefined,second)).status,403);
    });

  } finally {
    if(server.listening)await new Promise(resolve=>server.close(resolve));
    await state.pool.end();
  }
});
