import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { createDashboardGateway } from './dashboard_gateway.mjs';

test('public gateway exposes only signed read-only dashboard requests', async () => {
  const forwarded = [];
  const upstream = createServer((incoming, response) => {
    forwarded.push({ path: incoming.url, authorization: incoming.headers.authorization,
      cookie: incoming.headers.cookie });
    response.writeHead(401, { 'Set-Cookie': 'synthetic=must-not-forward', 'Content-Type': 'application/json' });
    response.end('{"code":"SYNTHETIC_INVALID_SIGNATURE"}');
  });
  const listen = (server) => new Promise((resolve, reject) => {
    server.once('error', reject); server.listen(0, '127.0.0.1', resolve);
  });
  await listen(upstream);
  const gateway = createDashboardGateway({ upstreamPort: upstream.address().port });
  await listen(gateway);
  const port = gateway.address().port;
  const call = (path, { method = 'GET', host = `127.0.0.1:${port}`, ...headers } = {}) => new Promise((resolve, reject) => {
    const pending = request({ hostname: '127.0.0.1', port, path, method,
      headers: { Host: host, Connection: 'close', ...headers } }, (response) => {
      let body = ''; response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => resolve({ status: response.statusCode, headers: response.headers, body }));
      response.on('error', reject);
    });
    pending.on('error', reject); pending.end();
  });
  try {
    const signed = { Authorization: 'Bearer synthetic.payload.signature' };
    for (const path of ['/testing/mailbox', '/health', '/api/auth/sign-in/email', '/api/account/me',
      '/api/auth/dash/../sign-in/email', '/api/auth/dash/%2e%2e/sign-in/email', '//api/auth/dash/validate']) {
      assert.equal((await call(path, signed)).status, 404);
    }
    assert.equal((await call('/api/auth/dash/validate')).status, 401);
    assert.equal((await call('/api/auth/dash/validate', { ...signed, host: 'example.invalid' })).status, 403);
    assert.equal((await call('/api/auth/dash/validate', { ...signed, Origin: 'https://example.invalid' })).status, 403);
    for (const method of ['POST', 'PATCH', 'DELETE']) {
      assert.equal((await call('/api/auth/dash/user', { ...signed, method })).status, 405);
    }
    assert.equal(forwarded.length, 0);
    const preflight = await call('/api/auth/dash/validate', { method: 'OPTIONS',
      Origin: 'https://dash.better-auth.com', 'Access-Control-Request-Method': 'GET' });
    assert.equal(preflight.status, 204);
    assert.equal((await call('/api/auth/dash/validate', { method: 'OPTIONS',
      Origin: 'https://dash.better-auth.com', 'Access-Control-Request-Method': 'POST' })).status, 405);
    const result = await call('/api/auth/dash/validate?check=synthetic', {
      ...signed, Origin: 'https://dash.better-auth.com', Cookie: 'synthetic=must-not-forward',
    });
    assert.equal(result.status, 401);
    assert.equal(result.headers['access-control-allow-origin'], 'https://dash.better-auth.com');
    assert.equal(result.headers['set-cookie'], undefined);
    assert.deepEqual(forwarded, [{ path: '/api/auth/dash/validate?check=synthetic',
      authorization: signed.Authorization, cookie: undefined }]);
    for (let count = 0; count < 121; count++) await call('/health');
    assert.equal((await call('/api/auth/dash/validate', signed)).status, 429);
    assert.equal(forwarded.length, 1);
  } finally {
    await new Promise((resolve) => gateway.close(resolve));
    await new Promise((resolve) => upstream.close(resolve));
  }
});
