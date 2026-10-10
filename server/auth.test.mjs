import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { createAuth } from './auth.mjs';
import { createApp } from './http.mjs';

test('local PostgreSQL authentication and access boundaries', async (t) => {
  const state = await createAuth();
  const server = createApp(state);
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const port = server.address().port;
  const base = `http://127.0.0.1:${port}`;
  let token;
  const email = 'auth.test@example.invalid';
  const password = 'Synthetic-2026!';
  const call = (path, body, bearer = token, origin = 'http://127.0.0.1:8300', cookie = null) => new Promise((resolve, reject) => {
    // node:http preserves the production Host while each isolated test uses
    // its own ephemeral loopback port. Fetch overwrites Host on this runtime.
    const req = request(base + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { Host: '127.0.0.1:8000', 'Content-Type': 'application/json', Origin: origin, Connection: 'close',
        ...(cookie ? {Cookie:cookie} : {}), ...(bearer ? { Authorization: 'Bearer ' + bearer } : {}) },
    }, res => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', chunk => raw += chunk);
      res.on('end', () => resolve(new Response(raw, {status:res.statusCode,headers:res.headers})));
      res.on('error', reject);
    });
    req.on('error', reject);
    req.end(body === undefined ? undefined : JSON.stringify(body));
  });
  const link = (kind) => {
    const mail = state.mailbox.findLast((item) => item.kind === kind && item.email === email);
    return new URLSearchParams(new URL(mail.url).hash.slice(1)).get(kind);
  };
  try {
    await t.test('no session and foreign origins are denied; cloud stays disabled', async () => {
      assert.equal((await call('/api/account/me')).status, 401);
      assert.equal((await call('/api/account/me', undefined, null, 'https://example.invalid')).status, 403);
      assert.equal((await (await call('/health')).json()).dashboardEnabled, false);
    });
    await t.test('registration is uniform, creates no session, and explicit login grants no product rights', async () => {
      assert.equal((await call('/api/auth/sign-up/email', { name: 'Synthetic', email: 'real@example.com', password })).status, 422);
      const result = await call('/api/auth/sign-up/email', { name: 'Synthetic', email, password });
      assert.equal(result.status, 200);
      assert.equal(result.headers.get('set-auth-token'),null);
      assert.deepEqual(await result.json(),{registration_requested:true});
      const duplicate=await call('/api/auth/sign-up/email',{name:'Other submitted name',email,password},null);
      assert.equal(duplicate.status,200);
      assert.deepEqual(await duplicate.json(),{registration_requested:true});
      assert.equal(duplicate.headers.get('set-auth-token'),null);
      token=(await call('/api/auth/sign-in/email',{email,password},null)).headers.get('set-auth-token');
      assert.ok(token);
      const snapshot = await (await call('/api/account/me')).json();
      assert.equal(snapshot.user.email, email);
      assert.equal(snapshot.user.email_verified, false);
      assert.equal(snapshot.product_available, true);
      assert.deepEqual(snapshot.memberships, []);
      assert.equal((await call('/api/events/1/location')).status, 404);
      const stored=await state.pool.query('SELECT a.password FROM account a JOIN "user" u ON u.id=a."userId" WHERE u.email=$1',[email]);
      assert.equal(stored.rowCount,1);
      assert.notEqual(stored.rows[0].password,password);
      assert.match(stored.rows[0].password,/^[0-9a-f]+:[0-9a-f]+$/);
      const settings=await state.pool.query("SELECT current_setting('statement_timeout') AS statement, current_setting('idle_in_transaction_session_timeout') AS idle");
      assert.equal(settings.rows[0].statement,'10s');assert.equal(settings.rows[0].idle,'15s');
      const other = await call('/api/auth/sign-up/email', { name: 'Other synthetic', email: 'other@example.invalid', password });
      assert.equal(other.headers.get('set-auth-token'),null);
      const otherLogin=await call('/api/auth/sign-in/email',{email:'other@example.invalid',password},null);
      const own = await (await call('/api/account/me', undefined, otherLogin.headers.get('set-auth-token'))).json();
      assert.equal(own.user.email, 'other@example.invalid');
    });
    await t.test('newest verification link wins, is bound to account and consumed once under concurrency', async () => {
      const previous = link('verify');
      assert.equal((await call('/api/auth/send-verification-email', { email })).status, 200);
      const current = link('verify');
      assert.notEqual(previous, current);
      assert.equal((await call('/api/account/verify', { email, token: previous })).status, 422);
      assert.equal((await call('/api/account/verify', { email: 'other@example.invalid', token: current })).status, 422);
      const responses = await Promise.all([0, 1].map(() => call('/api/account/verify', { email, token: current })));
      assert.deepEqual(responses.map((r) => r.status).sort(), [200, 422]);
      assert.equal((await (await call('/api/account/me')).json()).user.email_verified, true);
    });
    await t.test('logout revokes session in database, including replay', async () => {
      assert.equal((await call('/api/auth/sign-out', {})).status, 200);
      assert.equal((await call('/api/account/me')).status, 401);
      assert.equal((await call('/api/auth/sign-in/email', { email, password: 'WrongPassword123!' })).status, 401);
      const login = await call('/api/auth/sign-in/email', { email, password });
      assert.equal(login.status, 200);
      token = login.headers.get('set-auth-token');
      assert.equal((await call('/api/account/me')).status, 200);
    });
    await t.test('HttpOnly cookie restores the signed session without extending its absolute eight-hour lifetime',async()=>{
      const login=await call('/api/auth/sign-in/email',{email,password},null);
      const setCookie=login.headers.get('set-cookie');assert.ok(setCookie);assert.match(setCookie,/HttpOnly/i);assert.match(setCookie,/SameSite=Lax/i);
      const name=(await state.auth.$context).authCookies.sessionToken.name;
      const cookie=setCookie.split(/, (?=[^; ,]+=)/).find(v=>v.startsWith(name+'=')).split(';')[0];
      const raw=(await login.clone().json()).token;
      const before=(await state.pool.query('SELECT "expiresAt","createdAt" FROM session WHERE token=$1',[raw])).rows[0];
      assert.ok(new Date(before.expiresAt)-new Date(before.createdAt)<=8*3600000+1000);
      const restored=await call('/api/account/me',undefined,null,'http://127.0.0.1:8300',cookie);
      assert.equal(restored.status,200);assert.ok(restored.headers.get('set-auth-token'));assert.equal((await restored.json()).user.email,email);
      const after=(await state.pool.query('SELECT "expiresAt" FROM session WHERE token=$1',[raw])).rows[0];assert.deepEqual(after.expiresAt,before.expiresAt);
      await state.pool.query(`UPDATE session SET "expiresAt"=NOW()-INTERVAL '1 second' WHERE token=$1`,[raw]);
      assert.equal((await call('/api/account/me',undefined,null,'http://127.0.0.1:8300',cookie)).status,401);
      assert.equal((await call('/api/account/me',undefined,'invalid-bearer')).status,401);
    });
    await t.test('reset replaces old links, expires, is used once and revokes all sessions', async () => {
      const second = await call('/api/auth/sign-in/email', { email, password });
      const secondToken = second.headers.get('set-auth-token');
      const unknown = await call('/api/auth/request-password-reset', { email: 'unknown@example.invalid' });
      assert.equal(unknown.status, 200);
      assert.equal((await call('/api/auth/request-password-reset', { email })).status, 200);
      const expired = link('reset');
      await state.pool.query("UPDATE local_account_link SET expires_at=NOW()-INTERVAL '1 minute' WHERE kind='reset'");
      assert.equal((await call('/api/account/reset', { email, token: expired, newPassword: 'Changed-2026!' })).status, 422);
      await call('/api/auth/request-password-reset', { email });
      const old = link('reset');
      await call('/api/auth/request-password-reset', { email });
      const current = link('reset');
      // Invalid requests cannot consume a still-valid wrapper or native token.
      for (const invalid of [
        {email,token:current},
        {email,token:current,newPassword:'short'},
        {email,token:current,password:'Synthetic-2026!',newPassword:'short'},
        {email,token:current,newPassword:'Changed-2026!',extra:true},
      ]) assert.equal((await call('/api/account/reset',invalid)).status,422);
      assert.equal((await state.pool.query('SELECT used FROM local_account_link WHERE kind=\'reset\' AND email=$1',[email])).rows[0].used,false);
      assert.equal((await call('/api/account/reset', { email, token: old, newPassword: 'Changed-2026!' })).status, 422);
      const results = await Promise.all([0, 1].map(() => call('/api/account/reset', { email, token: current, newPassword: 'Changed-2026!' })));
      assert.deepEqual(results.map((r) => r.status).sort(), [200, 422]);
      assert.equal((await call('/api/account/me')).status, 401);
      assert.equal((await call('/api/account/me', undefined, secondToken)).status, 401);
      assert.equal((await call('/api/auth/sign-in/email', { email, password })).status, 401);
      assert.equal((await call('/api/auth/sign-in/email', { email, password: 'Changed-2026!' })).status, 200);
    });
    await t.test('dashboard configuration requires key and cannot point to remote database', async () => {
      await assert.rejects(createAuth({ env: { ...process.env, BETTER_AUTH_DASHBOARD_ENABLED: 'true', BETTER_AUTH_API_KEY: '' } }), /key missing/);
      await assert.rejects(createAuth({ env: { CA_DATABASE_SOCKET: '/remote/db' } }), /local authentication/);
      assert.equal((await call('/api/auth/dash/users')).status, 404);
    });
    await t.test('expired session cannot be replayed even with a valid signed token',async()=>{
      const login=await call('/api/auth/sign-in/email',{email,password:'Changed-2026!'});
      assert.equal(login.status,200);
      const expiredToken=login.headers.get('set-auth-token');assert.ok(expiredToken);
      await state.pool.query('UPDATE session SET "expiresAt"=NOW()-INTERVAL \'1 second\' WHERE "userId"=(SELECT id FROM "user" WHERE email=$1)',[email]);
      assert.equal((await call('/api/account/me',undefined,expiredToken)).status,401);
    });
    await t.test('concurrent duplicate registration creates only one account', async () => {
      // Isolate this concurrency scenario from the preceding signup's native
      // 3-per-10-second window. Production limits remain enabled and unchanged.
      await state.pool.query('DELETE FROM "rateLimit"');
      const concurrentEmail = 'concurrent@example.invalid';
      const results = await Promise.all([0, 1].map(() => call('/api/auth/sign-up/email',
        { name: 'Concurrent synthetic', email: concurrentEmail, password }, null)));
      assert.equal(results.filter((result) => result.headers.has('set-auth-token')).length, 0);
      assert.deepEqual(results.map(r=>r.status),[200,200]);
      assert.deepEqual(await results[0].json(),await results[1].json());
      const rows = await state.pool.query('SELECT COUNT(*)::int AS count FROM "user" WHERE email=$1', [concurrentEmail]);
      assert.equal(rows.rows[0].count, 1);
    });
    await t.test('login attempts are rate limited with bounded responses', async () => {
      let result;
      for (let attempt = 0; attempt < 11; attempt++) {
        result = await call('/api/auth/sign-in/email', { email, password: 'WrongPassword123!' }, null);
        if (result.status === 429) break;
      }
      assert.equal(result.status, 429);
      assert.deepEqual(await result.json(), { code: 'AUTH_REQUEST_FAILED' });
    });
    await t.test('configured dashboard denies unsigned administration without cloud calls', async () => {
      const originalFetch = globalThis.fetch;
      let externalCalls = 0;
      globalThis.fetch = (input, init) => {
        const url = String(input instanceof Request ? input.url : input);
        if (!url.startsWith(base)) {
          externalCalls++;
          throw new Error('External network disabled in synthetic tests.');
        }
        return originalFetch(input, init);
      };
      let configured;
      let dashboardServer;
      try {
        configured = await createAuth({ env: { ...process.env,
          BETTER_AUTH_DASHBOARD_ENABLED: 'true', BETTER_AUTH_API_KEY: 'synthetic-dashboard-key' } });
        const response = await configured.auth.handler(new Request(base + '/api/auth/dash/list-users', {
          headers: { Origin: 'https://dash.better-auth.com' },
        }));
        assert.equal(response.status, 401);
        assert.equal(externalCalls, 0);
        assert.equal(configured.dashboardEnabled, true);
        await new Promise((resolve) => server.close(resolve));
        dashboardServer = createApp(configured);
        await new Promise((resolve, reject) => {
          dashboardServer.once('error', reject);
          dashboardServer.listen(port, '127.0.0.1', resolve);
        });
        const guarded = await call('/api/auth/dash/list-users?limit=10', undefined, null, 'https://dash.better-auth.com');
        assert.equal(guarded.status, 401);
        assert.equal(guarded.headers.get('access-control-allow-origin'), 'https://dash.better-auth.com');
        assert.equal((await call('/api/auth/sign-up/email', { name: 'Synthetic', email, password }, null, 'https://dash.better-auth.com')).status, 403);
        assert.equal((await call('/api/auth/dash/validate', undefined, null, 'https://example.invalid')).status, 403);
        assert.equal(externalCalls, 0);
      } finally {
        globalThis.fetch = originalFetch;
        if (dashboardServer) await new Promise((resolve) => dashboardServer.close(resolve));
        if (configured) await configured.pool.end();
      }
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await state.pool.end();
  }
});
