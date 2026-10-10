import { test } from 'node:test';
import assert from 'node:assert/strict';
import { gunzipSync } from 'node:zlib';
import { staticRepresentation } from './static_compression.mjs';

test('static gzip preserves bytes and honours explicit refusal', async () => {
  const source = Buffer.from('synthetic static release\n'.repeat(1000));
  const encoded = await staticRepresentation(source, 'br, gzip;q=0.8');
  assert.equal(encoded.encoding, 'gzip');
  assert.deepEqual(gunzipSync(encoded.data), source);
  assert.ok(encoded.data.length < source.length);
  for (const accept of ['', 'gzip;q=0, *;q=1', 'br', 'gzip;q=invalid']) {
    const result = await staticRepresentation(source, accept);
    assert.equal(result.encoding, undefined, accept);
    assert.deepEqual(result.data, source);
  }
  assert.equal((await staticRepresentation(source, '*')).encoding, 'gzip');
  assert.equal((await staticRepresentation(Buffer.from('small'), 'gzip')).encoding, undefined);
});
