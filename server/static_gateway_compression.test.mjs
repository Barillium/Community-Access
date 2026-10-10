import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';
import { createPublicGateway } from './public_gateway.mjs';

test('gateway serves compressed GET and matching HEAD without changing release bytes', async () => {
  const root = await mkdtemp(join(realpathSync(tmpdir()), 'ca-gzip-test-'));
  const source = Buffer.from('synthetic JavaScript release;\n'.repeat(2000));
  const origin = 'https://communityaccess.de';
  await writeFile(join(root, 'main.dart.js'), source);
  await writeFile(join(root, 'public-release.json'), JSON.stringify({ apiOrigin: origin, uiOrigin: origin, privateMail: true }));
  const upstream = createServer((req, res) => res.end(JSON.stringify({ synthetic: false, dashboardEnabled: false,
    apiOrigin: origin, uiOrigin: origin, databaseRestricted: true,
    securityControls:{apiRateLimits:true,mailBudget:true} })));
  const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  await listen(upstream);
  let gateway;
  try {
    gateway = await createPublicGateway({ webRoot: root, upstreamPort: upstream.address().port });
    await listen(gateway);
    const call = (method, encoding) => new Promise((resolve, reject) => {
      const req = request({ hostname: '127.0.0.1', port: gateway.address().port, path: '/main.dart.js', method,
        headers: { Host: 'communityaccess.de', 'X-Forwarded-Proto':'https', 'Accept-Encoding': encoding, Connection: 'close' } }, res => {
        const chunks = [];
        res.on('data', chunk => chunks.push(chunk));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
        res.on('error', reject);
      });
      req.on('error', reject); req.end();
    });
    const get = await call('GET', 'gzip');
    assert.equal(get.status, 200);
    assert.equal(get.headers['content-encoding'], 'gzip');
    assert.equal(get.headers.vary, 'Accept-Encoding');
    assert.equal(Number(get.headers['content-length']), get.body.length);
    assert.deepEqual(gunzipSync(get.body), source);
    const head = await call('HEAD', 'gzip');
    assert.equal(head.headers['content-length'], get.headers['content-length']);
    assert.equal(head.headers['content-encoding'], 'gzip');
    assert.equal(head.body.length, 0);
    const identity = await call('GET', 'gzip;q=0');
    assert.equal(identity.headers['content-encoding'], undefined);
    assert.deepEqual(identity.body, source);
  } finally {
    if (gateway) await new Promise(resolve => gateway.close(resolve));
    await new Promise(resolve => upstream.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
});
