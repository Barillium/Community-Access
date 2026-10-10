import { createServer, request as upstreamRequest } from 'node:http';

const dashboardOrigin = 'https://dash.better-auth.com';
const reply = (response, status, code) => {
  response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  response.end(JSON.stringify({ code }));
};

// The public tunnel reaches this read-only gateway, never the full auth server.
export function createDashboardGateway({ upstreamPort = 8000 } = {}) {
  let windowStart = Date.now();
  let requests = 0;
  let active = 0;
  const server = createServer((request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    const port = server.address().port;
    if (request.headers.host !== `127.0.0.1:${port}`) return reply(response, 403, 'HOST_DENIED');
    if (Date.now() - windowStart >= 60000) { windowStart = Date.now(); requests = 0; }
    if (++requests > 120 || active >= 8) return reply(response, 429, 'RATE_LIMITED');
    // Match the raw path so encoding, dot segments and absolute URLs cannot
    // escape the dashboard namespace when the upstream parses the request.
    if (!/^\/api\/auth\/dash\/[a-z0-9]+(?:[/-][a-z0-9]+)*(?:\?[^#]*)?$/.test(request.url) || request.url.length > 4096) {
      return reply(response, 404, 'ROUTE_DENIED');
    }
    const origin = request.headers.origin;
    if (origin && origin !== dashboardOrigin) return reply(response, 403, 'ORIGIN_DENIED');
    if (origin) {
      response.setHeader('Access-Control-Allow-Origin', dashboardOrigin);
      response.setHeader('Vary', 'Origin');
      response.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    }
    if (request.method === 'OPTIONS') {
      if (request.headers['access-control-request-method'] !== 'GET') return reply(response, 405, 'METHOD_DENIED');
      response.writeHead(204); return response.end();
    }
    if (request.method !== 'GET') return reply(response, 405, 'METHOD_DENIED');
    const authorization = request.headers.authorization;
    if (typeof authorization !== 'string' || authorization.length > 8192 ||
        !/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(authorization)) {
      return reply(response, 401, 'DASHBOARD_SIGNATURE_REQUIRED');
    }
    // Better Auth verifies the JWT signature, age, API-key binding and (for
    // normal dashboard routes) JTI. This gateway never receives the API key.
    active++;
    const pending = upstreamRequest({ hostname: '127.0.0.1', port: upstreamPort,
      path: request.url, method: 'GET', headers: { Authorization: authorization,
        ...(origin ? { Origin: origin } : {}) }, timeout: 10000 }, (result) => {
      const chunks = [];
      let size = 0;
      result.on('data', (chunk) => {
        size += chunk.length;
        if (size > 2097152) pending.destroy(new Error('Response limit'));
        else chunks.push(chunk);
      });
      result.on('end', () => {
        if (response.destroyed || response.writableEnded) return;
        response.writeHead(result.statusCode, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        response.end(Buffer.concat(chunks));
      });
      result.on('error', () => { if (!response.writableEnded && !response.destroyed) reply(response, 502, 'UPSTREAM_UNAVAILABLE'); });
    });
    pending.on('timeout', () => pending.destroy(new Error('Timeout')));
    pending.on('error', () => { if (!response.writableEnded && !response.destroyed) reply(response, 502, 'UPSTREAM_UNAVAILABLE'); });
    pending.on('close', () => { active--; });
    response.on('close', () => { if (!response.writableEnded) pending.destroy(); });
    pending.end();
  });
  server.headersTimeout = 10000;
  server.requestTimeout = 10000;
  return server;
}
