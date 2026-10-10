import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { createAuth } from './auth.mjs';
import { createApp } from './http.mjs';

for(const https of [false,true]) test(`private mail callbacks at ${https?'configured HTTPS':'local HTTP'} origins work without external mail`, async () => {
  const messages = [];
  let rejectMail = false, loseAck = false;
  const env = { ...process.env, CA_AUTH_PROFILE: 'private-mail', RESEND_API_KEY: 're_synthetic_fixture_only',
    ...(https?{CA_AUTH_API_ORIGIN:'https://auth.example.invalid',CA_AUTH_UI_ORIGIN:'https://app.example.invalid'}:{}) };
  const state = await createAuth({ env, fetchImpl: async (url, options) => {
    assert.equal(url, 'https://api.resend.com/emails');
    if (rejectMail) return Response.json({error:'synthetic transport denial'},{status:503});
    messages.push(JSON.parse(options.body));
    if(loseAck)throw new Error('Synthetic lost acknowledgement');
    return Response.json({ id: 'synthetic-message' });
  } });
  const server = createApp(state);
  await new Promise((resolve, reject) => {
    server.once('error', reject); server.listen(0, '127.0.0.1', resolve);
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const email = `private-${https?'https':'local'}-fixture@example.test`;
  const password = 'Synthetic-2026!';
  const call = (path, body, token, origin = env.CA_AUTH_UI_ORIGIN??'http://127.0.0.1:8300') => new Promise((resolve, reject) => {
    const pending = request(base + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { Host: https?'auth.example.invalid':'127.0.0.1:8000', Origin: origin, 'Content-Type': 'application/json',
        Connection: 'close', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    }, response => {
      let text = ''; response.setEncoding('utf8');
      response.on('data', chunk => { text += chunk; });
      response.on('error', reject);
      response.on('end', () => resolve(new Response(text, {
        status: response.statusCode, headers: response.headers,
      })));
    });
    pending.on('error', reject); pending.end(body === undefined ? undefined : JSON.stringify(body));
  });
  const tokenFromMail = (kind) => {
    const text = messages.findLast(m => m.subject.includes(kind === 'verify' ? 'bestätigen' : 'zurücksetzen')).text;
    const url = text.split('\n').find(line => /^https?:\/\//.test(line));
    return new URLSearchParams(new URL(url).hash.slice(1)).get(kind);
  };
  try {
    assert.equal((await (await call('/health')).json()).synthetic, false);
    assert.equal(state.databaseRestricted, true);
    assert.equal((await (await call('/health')).json()).databaseRestricted, true);
    for (const sql of ['CREATE ROLE forbidden_private_fixture',
      'CREATE DATABASE forbidden_private_fixture', 'SET ROLE fixture_admin']) {
      await assert.rejects(state.pool.query(sql));
    }
    assert.equal((await call('/testing/mailbox')).status, 404);
    assert.equal((await call('/api/auth/sign-up/email', { name: 'Synthetic fixture', email: 'x@example.invalid', password })).status, 422);
    const signup = await call('/api/auth/sign-up/email', { name: 'Synthetic fixture', email, password });
    assert.equal(signup.status, 200);
    assert.equal(signup.headers.get('set-auth-token'),null);
    const token = (await call('/api/auth/sign-in/email',{email,password})).headers.get('set-auth-token'); assert.ok(token);
    assert.equal(state.mailbox.length, 0);
    assert.equal(messages.length, 1);
    assert.equal((await call('/api/account/verify', { email, token: tokenFromMail('verify') }, token)).status, 200);
    assert.equal((await (await call('/api/account/me', undefined, token)).json()).user.email_verified, true);
    assert.equal((await call('/api/account/verify', { email, token: tokenFromMail('verify') }, token)).status, 422);
    assert.equal((await call('/api/auth/request-password-reset', { email })).status, 200);
    const reset = tokenFromMail('reset');
    const previousLink=(await state.pool.query("SELECT digest,library_token FROM local_account_link WHERE email=$1 AND kind='reset'",[email])).rows[0];
    const originalConnect=state.pool.connect;
    let failedLinkConnection=false;
    state.pool.connect=function(...args){
      // Fail the wrapper connection only; native auth/rate-limit database
      // work must still reach the callback being tested.
      if(!args.length && new Error().stack.includes('sendLink')) {
        failedLinkConnection=true;
        return Promise.reject(new Error('Synthetic wrapper connection unavailable'));
      }
      return originalConnect.apply(this,args);
    };
    try{
      const unavailable=await call('/api/auth/request-password-reset',{email});
      assert.equal(unavailable.status,503);
      assert.deepEqual(await unavailable.json(),{code:'MAIL_UNAVAILABLE'});
      assert.equal(failedLinkConnection,true);
    }finally{state.pool.connect=originalConnect;}
    assert.deepEqual((await state.pool.query("SELECT digest,library_token FROM local_account_link WHERE email=$1 AND kind='reset'",[email])).rows[0],previousLink);
    rejectMail=true;
    const failedReplacement=await call('/api/auth/request-password-reset',{email});
    assert.ok(failedReplacement.status>=400);
    rejectMail=false;
    assert.deepEqual((await state.pool.query("SELECT digest,library_token FROM local_account_link WHERE email=$1 AND kind='reset'",[email])).rows[0],previousLink);
    loseAck=true;
    assert.equal((await call('/api/auth/request-password-reset',{email})).status,503);
    loseAck=false;
    assert.deepEqual((await state.pool.query("SELECT digest,library_token FROM local_account_link WHERE email=$1 AND kind='reset'",[email])).rows[0],previousLink);
    assert.equal((await call('/api/account/reset',{email,token:tokenFromMail('reset'),newPassword:'NewSynthetic-2026!'})).status,422);
    assert.equal((await call('/api/account/reset', { email, token: reset, newPassword: 'NewSynthetic-2026!' })).status, 200);
    assert.equal((await call('/api/account/reset', { email, token: reset, newPassword: 'NewSynthetic-2026!' })).status, 422);
    assert.equal((await call('/api/account/me', undefined, token)).status, 401);
    assert.equal((await call('/api/auth/sign-in/email', { email, password })).status, 401);
    assert.equal((await call('/api/auth/sign-in/email', { email, password: 'NewSynthetic-2026!' })).status, 200);
    // Simulate a lost database COMMIT acknowledgement after a successful
    // commit. The response must not promise that the previous link survived.
    const connect=state.pool.connect;
    let loseCommitAck=true;
    state.pool.connect=function(...args){
      if(args.length)return connect.apply(this,args);
      return connect.call(this).then(client=>{
        const query=client.query,release=client.release;
        let wrapperInserted=false;
        client.query=function(...values){
          if(String(values[0]).includes('INSERT INTO local_account_link'))wrapperInserted=true;
          const pending=query.apply(this,values);
          if(values[0]==='COMMIT'&&wrapperInserted&&loseCommitAck)return pending.then(result=>{loseCommitAck=false;throw new Error('Synthetic lost commit acknowledgement');});
          return pending;
        };
        client.release=function(...values){client.query=query;client.release=release;return release.apply(this,values);};
        return client;
      });
    };
    try{
      const uncertain=await call('/api/auth/request-password-reset',{email});
      assert.equal(uncertain.status,503);assert.deepEqual(await uncertain.json(),{code:'LINK_STATUS_UNKNOWN'});
      assert.equal(loseCommitAck,false);
      const committedToken=tokenFromMail('reset');
      assert.equal((await call('/api/account/reset',{email,token:committedToken,newPassword:'LastSynthetic-2026!'})).status,200);
    }finally{state.pool.connect=connect;}

    assert.equal((await call('/health', undefined, undefined, 'https://foreign.example.test')).status, 403);
    await assert.rejects(createAuth({ env: { ...env, RESEND_API_KEY: '' } }), /Resend key/);
    await assert.rejects(createAuth({ env: { ...env, BETTER_AUTH_SECRET: '' } }), /Stable private/);
  } finally {
    await new Promise(resolve => server.close(resolve)); await state.pool.end();
  }
});
