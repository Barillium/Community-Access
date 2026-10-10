import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { request } from 'node:http';
import { fileURLToPath } from 'node:url';
import { createAuth } from './auth.mjs';
import { createApp } from './http.mjs';

const execute = promisify(execFile);
const root = fileURLToPath(new URL('../', import.meta.url));

test('account, signed session and one-time links survive a PostgreSQL and auth restart', async () => {
  const data = process.env.CA_AUTH_RESTART_TEST_DATA;
  // This test may restart only its freshly generated, synthetic test cluster.
  assert.ok(data?.startsWith(root + '.local/better-auth/run-'));
  assert.match(data.slice(root.length), /^\.local\/better-auth\/run-[A-Za-z0-9_-]+\/data$/);
  assert.equal(process.env.BETTER_AUTH_DASHBOARD_ENABLED, undefined);
  let state;
  let server;
  let port;
  const email = 'restart-check@example.invalid';
  const password = 'Synthetic-Restart-2026!';
  const start = async () => {
    state = await createAuth();
    server = createApp(state);
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });
    port = server.address().port;
  };
  const stop = async () => {
    if (server?.listening) await new Promise((resolve) => server.close(resolve));
    server = null;
    if (state) await state.pool.end();
    state = null;
  };
  const call = (path, body, token) => new Promise((resolve, reject) => {
    const pending = request({ hostname: '127.0.0.1', port, path,
      method: body === undefined ? 'GET' : 'POST',
      headers: { Host: '127.0.0.1:8000', Origin: 'http://127.0.0.1:8300',
        Connection: 'close', 'Content-Type': 'application/json',
        ...(token ? { Authorization: 'Bearer ' + token } : {}) } }, (response) => {
      let payload = '';
      response.setEncoding('utf8');
      response.on('data', (part) => { payload += part; });
      response.on('end', () => resolve({ status: response.statusCode,
        headers: response.headers, body: JSON.parse(payload) }));
      response.on('error', reject);
    });
    pending.on('error', reject);
    pending.end(body === undefined ? undefined : JSON.stringify(body));
  });
  const pg = async (...args) => {
    try {
      await execute('/opt/homebrew/opt/postgresql@17/bin/pg_ctl',
        ['-D', data, '-w', '-t', '15', ...args], { timeout: 25000, env: process.env });
    } catch { throw new Error('Synthetic PostgreSQL restart failed; diagnostics withheld.'); }
  };
  try {
    await start();
    const signup = await call('/api/auth/sign-up/email', { name: 'Restart fixture', email, password });
    assert.equal(signup.status, 200);
    assert.equal(signup.headers['set-auth-token'],undefined);
    const session = (await call('/api/auth/sign-in/email',{email,password})).headers['set-auth-token'];
    assert.ok(session);
    const verification = new URLSearchParams(new URL(state.mailbox.at(-1).url).hash.slice(1)).get('verify');
    assert.equal((await call('/api/auth/request-password-reset', { email })).status, 200);
    const reset = new URLSearchParams(new URL(state.mailbox.at(-1).url).hash.slice(1)).get('reset');
    await stop();
    await pg('-m', 'fast', 'stop');
    await pg('-l', data + '/../server.log', '-o',
      '-c unix_socket_directories=' + process.env.CA_DATABASE_SOCKET, 'start');
    await start();
    assert.equal(state.mailbox.length, 0); // The local inbox is deliberately ephemeral.
    const account = await call('/api/account/me', undefined, session);
    assert.equal(account.status, 200);
    assert.equal(account.body.user.email, email);
    // Availability describes installed features, not admission or organizer rights.
    assert.equal(account.body.product_available, true);
    assert.equal(account.body.user.email_verified, false);
    assert.equal(account.body.is_host, false);
    assert.deepEqual(account.body.memberships, []);
    assert.deepEqual(account.body.events, []);
    const denied = await call('/api/access/policy/workspace', undefined, session);
    assert.equal(denied.status, 403);
    assert.equal(denied.body.code, 'VERIFY_EMAIL');
    assert.equal((await call('/api/auth/sign-in/email', { email, password })).status, 200);
    assert.equal((await call('/api/account/verify', { email, token: verification })).status, 200);
    assert.equal((await call('/api/account/me', undefined, session)).body.user.email_verified, true);
    assert.equal((await call('/api/account/verify', { email, token: verification })).status, 422);
    assert.equal((await call('/api/account/reset', { email, token: reset, newPassword: 'Changed-Restart-2026!' })).status, 200);
    assert.equal((await call('/api/account/reset', { email, token: reset, newPassword: 'Changed-Restart-2026!' })).status, 422);
    assert.equal((await call('/api/account/me', undefined, session)).status, 401);
    assert.equal((await call('/api/auth/sign-in/email', { email, password })).status, 401);
    const login = await call('/api/auth/sign-in/email', { email, password: 'Changed-Restart-2026!' });
    assert.equal(login.status, 200);
    assert.equal((await call('/api/auth/sign-out', {}, login.headers['set-auth-token'])).status, 200);
    assert.equal((await call('/api/account/me', undefined, login.headers['set-auth-token'])).status, 401);
  } finally { await stop(); }
});
