// Single-process pilot limits. Only a server-validated user ID identifies an
// account; client IP headers and bearer token text are never limiter keys.
export function createRequestLimits({ now = Date.now, windowMs = 60000,
  globalMax = 600, authMax = 120, accountMax = 240, writeMax = 60,
  maxKeys = 4096 } = {}) {
  for (const value of [windowMs, globalMax, authMax, accountMax, writeMax, maxKeys]) {
    if (!Number.isSafeInteger(value) || value < 1) throw new Error('Invalid request limit.');
  }
  let epoch = -1;
  const counts = new Map();
  const take = (buckets) => {
    const time = now();
    const current = Math.floor(time / windowMs);
    if (current !== epoch) { counts.clear(); epoch = current; }
    const retryAfter = Math.max(1, Math.ceil(((current + 1) * windowMs - time) / 1000));
    const newKeys = buckets.filter(([key]) => !counts.has(key)).length;
    if (counts.size + newKeys > maxKeys ||
        buckets.some(([key, max]) => (counts.get(key) ?? 0) >= max)) return { retryAfter };
    for (const [key] of buckets) counts.set(key, (counts.get(key) ?? 0) + 1);
    return null;
  };
  return {
    global: () => take([['global', globalMax]]),
    auth: () => take([['auth', authMax]]),
    account: (user, method) => {
      if (!user) return null;
      const buckets = [[`account:${user.id}`, accountMax]];
      if (!['GET', 'HEAD', 'OPTIONS'].includes(method)) buckets.push([`write:${user.id}`, writeMax]);
      return take(buckets);
    },
  };
}

const events = new Set(['unauthenticated', 'forbidden', 'rate_limited',
  'oversized', 'unavailable', 'cleanup_failed', 'mail_budget_exhausted']);

// Fixed counters only: no URL, token, address, user ID, IP or error object.
// Batching prevents an attacker turning every rejected request into a log line.
export function createSecuritySummary(emit = () => {}) {
  let counts = {};
  return {
    record: (event) => {
      if (events.has(event)) counts[event] = Math.min((counts[event] ?? 0) + 1, Number.MAX_SAFE_INTEGER);
    },
    response: (status) => {
      const event = {401:'unauthenticated', 403:'forbidden', 413:'oversized',
        429:'rate_limited', 500:'unavailable', 502:'unavailable', 503:'unavailable'}[status];
      if (event) counts[event] = Math.min((counts[event] ?? 0) + 1, Number.MAX_SAFE_INTEGER);
    },
    flush: () => {
      if (!Object.keys(counts).length) return;
      const summary = {event:'security_summary', counts};
      counts = {};
      try { emit(summary); } catch { /* Monitoring cannot break access control. */ }
    },
  };
}

export function apiSecurityHeaders(response) {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  response.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
  response.setHeader('Cache-Control', 'no-store');
}

export function createRetentionJob(directory, onFailure) {
  let running=null;
  return ()=>{
    if(running)return running;
    running=Promise.allSettled([
      Promise.resolve().then(()=>directory.discovery.purge()),
      Promise.resolve().then(()=>directory.accessFlow.purge()),
    ]).then(results=>{
      if(results.some(result=>result.status==='rejected'))onFailure();
    }).finally(()=>{running=null;});
    return running;
  };
}
