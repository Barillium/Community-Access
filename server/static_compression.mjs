import { gzip } from 'node:zlib';
import { promisify } from 'node:util';

const compress = promisify(gzip);

// Only static assets call this helper. Auth responses and cookies stay untouched.
export async function staticRepresentation(data, acceptEncoding = '') {
  const codings = String(acceptEncoding).toLowerCase().split(',').map(value => {
    const [name, ...parameters] = value.trim().split(';');
    const quality = parameters.find(parameter => /^\s*q\s*=/.test(parameter));
    const q = quality ? Number(quality.split('=')[1].trim()) : 1;
    return { name, q: Number.isFinite(q) && q >= 0 && q <= 1 ? q : 0 };
  });
  const gzipQuality = codings.find(coding => coding.name === 'gzip')?.q ??
    codings.find(coding => coding.name === '*')?.q ?? 0;
  if (data.length < 1024 || gzipQuality === 0) return { data };
  const encoded = await compress(data);
  return encoded.length < data.length ? { data: encoded, encoding: 'gzip' } : { data };
}
