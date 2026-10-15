import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker.mjs';

const origin = 'https://community-access-development.stany-nyssen.workers.dev';
const env = { GIT_COMMIT: 'test-commit', ASSETS: {
  fetch: async () => new Response('<html>Preview</html>', { headers: { 'Content-Type': 'text/html' } }),
} };
const request = (path, method = 'GET') => worker.fetch(new Request(origin + path, { method }), env);

test('health identifies Development, commit and disconnected backend', async () => {
  const res = await request('/__development/health');
  const data = await res.json();
  assert.equal(data.backendConnected, false);
  assert.equal(data.environment, 'development');
  assert.equal(data.gitCommit, 'test-commit');
  assert.match(res.headers.get('X-Robots-Tag'), /noindex/);
});

test('account, payments, mutations and testing endpoints stay unavailable', async () => {
  for (const path of ['/api/account/me', '/api/auth/sign-in/email', '/api/ticketing/orders', '/api/directory/events', '/testing/reset']) {
    const res = await request(path, 'POST');
    assert.equal(res.status, 503);
    assert.equal((await res.json()).code, 'DEVELOPMENT_PREVIEW_ONLY');
  }
});

test('public date range uses inclusive start and exclusive end', async () => {
  // Freeze only the catalog clock so this regression remains valid after October 2026.
  const original = Date.now;
  Date.now = () => Date.parse('2026-10-15T00:00:00Z');
  try {
    const all = await (await request('/api/directory/events')).json();
    assert.ok(all.events.length > 0);
    const first = all.events[0];
    const data = await (await request('/api/directory/events?from=' + encodeURIComponent(first.starts_at))).json();
    assert.ok(data.events.some(item => item.id === first.id));
    const before = await (await request('/api/directory/events?before=' + encodeURIComponent(first.starts_at))).json();
    assert.equal(before.events.length, 0);
  } finally { Date.now = original; }
});

test('empty communities have the guest contract; static responses remain unindexed', async () => {
  assert.deepEqual((await (await request('/api/directory/communities')).json()).items, []);
  assert.equal((await (await request('/api/directory/communities')).json()).signed_in, false);
  const res = await request('/');
  assert.match(res.headers.get('X-Robots-Tag'), /noindex/);
  assert.equal(res.headers.get('Cache-Control'), 'no-cache');
});
