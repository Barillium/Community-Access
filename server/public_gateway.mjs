import { createServer, request } from 'node:http';
import { readFile, realpath, stat } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { staticRepresentation } from './static_compression.mjs';
import { createRequestLimits, createSecuritySummary } from './request_security.mjs';

const origin = 'https://communityaccess.de';
const host = 'communityaccess.de';
const posts = new Set([
  '/api/auth/sign-up/email', '/api/auth/sign-in/email', '/api/auth/sign-out',
  '/api/auth/request-password-reset', '/api/auth/send-verification-email',
  '/api/account/verify', '/api/account/reset',
  '/api/account/social/start', '/api/account/social/session',
]);
const gets = new Set(['/api/account/me', '/api/account/social/providers']);
const callback = /^\/api\/auth\/callback\/(google|apple|facebook)$/;
const rootFiles = new Set(['index.html', 'flutter_bootstrap.js', 'flutter.js',
  'flutter_service_worker.js', 'main.dart.js', 'main.dart.mjs', 'main.dart.wasm',
  'manifest.json', 'version.json', 'favicon.svg', 'favicon.png', 'social-preview.png',
  'impressum.html', 'datenschutz.html', 'support.html', 'konto-loeschen.html', 'event_flyer_picker.js']);
// Flutter URL-encodes the literal percent signs in this bundled font name.
// Admit only this exact known asset; never decode arbitrary request paths.
const packagedAssets=new Map([['/assets/packages/ca_design/fonts/Archivo%255Bwdth,wght%255D.ttf',
  'assets/packages/ca_design/fonts/Archivo%5Bwdth,wght%5D.ttf']]);
const types = {'.html':'text/html; charset=utf-8', '.js':'text/javascript',
  '.mjs':'text/javascript', '.wasm':'application/wasm', '.json':'application/json',
  '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp',
  '.ttf':'font/ttf', '.otf':'font/otf', '.woff2':'font/woff2', '.css':'text/css'};
const reply = (res, status, code) => {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, {'Content-Type':'application/json', 'Cache-Control':'no-store'});
  res.end(JSON.stringify({code}));
};

// The probe reads deployment metadata only, never users, mail or credentials.
export async function verifyPrivateBackend(upstreamPort = 8000) {
  const data = await new Promise((accept, reject) => {
    const pending = request({hostname:'127.0.0.1', port:upstreamPort, path:'/health',
      headers:{Host:host, Connection:'close'}, timeout:3000}, res => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', chunk => {
        raw += chunk;
        if (raw.length > 4096) pending.destroy(new Error('Invalid health response'));
      });
      res.on('error', reject);
      res.on('end', () => {
        try {
          if (res.statusCode !== 200) throw new Error('Backend unavailable');
          accept(JSON.parse(raw));
        } catch { reject(new Error('Backend unavailable')); }
      });
    });
    pending.on('timeout', () => pending.destroy(new Error('Backend unavailable')));
    pending.on('error', reject);
    pending.end();
  });
  if (data.synthetic !== false || data.dashboardEnabled !== false ||
      data.apiOrigin !== origin || data.uiOrigin !== origin || data.databaseRestricted !== true ||
      data.securityControls?.apiRateLimits!==true||data.securityControls?.mailBudget!==true) {
    throw new Error('Private HTTPS backend required');
  }
}

export async function createPublicGateway({webRoot, upstreamPort = 8000,
  requestLimits=createRequestLimits(),staticLimits=createRequestLimits({globalMax:1200}),
  onSecuritySummary} = {}) {
  if (!webRoot) throw new Error('Dedicated release directory required');
  const root = resolve(webRoot);
  if (await realpath(root) !== root || !(await stat(root)).isDirectory()) {
    throw new Error('Regular release directory required');
  }
  const marker = JSON.parse(await readFile(resolve(root, 'public-release.json'), 'utf8'));
  if (marker.apiOrigin !== origin || marker.uiOrigin !== origin || marker.privateMail !== true) {
    throw new Error('Matching private web release required');
  }
  await verifyPrivateBackend(upstreamPort);
  let active = 0;
  const security=createSecuritySummary(onSecuritySummary);
  const server = createServer({headersTimeout:10000,requestTimeout:15000,
    connectionsCheckingInterval:1000,maxHeaderSize:16384},async (req, res) => {
    res.once('finish',()=>security.response(res.statusCode));
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Referrer-Policy','no-referrer');
    res.setHeader('X-Frame-Options','DENY');
    res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'");
    res.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=()');
    res.setHeader('Strict-Transport-Security','max-age=86400');
    res.setHeader('Cache-Control','no-store');
    try {
      if (req.headers.host !== host) return reply(res,403,'HOST_DENIED');
      // This listener is loopback-only behind the owner-operated Cloudflare
      // tunnel. Cloudflare overwrites this header with the visitor protocol.
      // Reject absent/ambiguous/plaintext signals; never reflect callback URLs.
      if(req.headers['x-forwarded-proto']!=='https')return reply(res,403,'HTTPS_REQUIRED');
      if (active >= 16) {res.setHeader('Retry-After','1');return reply(res,503,'BUSY');}
      active++;
      res.once('close', () => { active--; });
      // Reject raw path ambiguity before any URL parser can normalize it.
      if (typeof req.url !== 'string' || req.url.length > 8192 || !req.url.startsWith('/') ||
          req.url.startsWith('//') || /[\\#\x00-\x20]/.test(req.url)) return reply(res,404,'ROUTE_DENIED');
      const path = req.url.split('?')[0];
      if ((/%/.test(path)&&!packagedAssets.has(path)) || path.split('/').some(part => part === '.' || part === '..')) {
        return reply(res,404,'ROUTE_DENIED');
      }
      const isCallback = callback.test(path);
      const isApi = gets.has(path) || posts.has(path) || isCallback;
      // No trust in X-Forwarded-For / CF-Connecting-IP supplied by a browser.
      // Separate aggregate budgets protect this single-process pilot behind a tunnel.
      const limit=(isApi?requestLimits:staticLimits).global();
      if(limit){res.setHeader('Retry-After',String(limit.retryAfter));return reply(res,429,'RATE_LIMITED');}
      if (path.startsWith('/api/') && !isApi) return reply(res,404,'ROUTE_DENIED');
      if (isApi) {
        if (!isCallback && req.url.includes('?')) return reply(res,400,'QUERY_DENIED');
        const allowed = req.method === 'GET' && (gets.has(path) || isCallback) ||
          req.method === 'POST' && (posts.has(path) || path === '/api/auth/callback/apple');
        if (!allowed) return reply(res,405,'METHOD_DENIED');
        const incomingOrigin = req.headers.origin;
        if (incomingOrigin && incomingOrigin !== origin &&
            !(path === '/api/auth/callback/apple' && req.method === 'POST' &&
              incomingOrigin === 'https://appleid.apple.com')) return reply(res,403,'ORIGIN_DENIED');
        // Re-check on each API request: restarting port 8000 as a demo must fail closed.
        await verifyPrivateBackend(upstreamPort);
        const chunks = [];
        let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > 16384) return reply(res,413,'BODY_TOO_LARGE');
          chunks.push(chunk);
        }
        const headers = {Host:host, Connection:'close'};
        for (const name of ['origin','authorization','cookie','content-type']) {
          if (req.headers[name]) headers[name] = req.headers[name];
        }
        const pending = request({hostname:'127.0.0.1', port:upstreamPort, path:req.url,
          method:req.method, headers, timeout:15000}, result => {
          const content = [];
          let bytes = 0;
          result.on('data', chunk => {
            bytes += chunk.length;
            if (bytes > 1048576) pending.destroy(new Error('Response limit'));
            else content.push(chunk);
          });
          result.on('error', () => reply(res,502,'UPSTREAM_UNAVAILABLE'));
          result.on('end', () => {
            if (res.destroyed || res.writableEnded) return;
            const responseHeaders = {'Content-Type':result.headers['content-type'] || 'application/json',
              'Cache-Control':'no-store'};
            for (const name of ['set-cookie','set-auth-token']) {
              if (result.headers[name]) responseHeaders[name] = result.headers[name];
            }
            if([429,503].includes(result.statusCode)&&/^\d{1,6}$/.test(result.headers['retry-after']??'')){
              responseHeaders['Retry-After']=result.headers['retry-after'];
            }
            if (result.headers.location) {
              let target;
              try { target = new URL(result.headers.location, origin); }
              catch { return reply(res,502,'REDIRECT_DENIED'); }
              if (target.origin !== origin || target.pathname !== '/' || target.search ||
                  !['#social=success','#social=error'].includes(target.hash)) {
                return reply(res,502,'REDIRECT_DENIED');
              }
              responseHeaders.Location = target.href;
            }
            res.writeHead(result.statusCode,responseHeaders);
            res.end(Buffer.concat(content));
          });
        });
        pending.on('timeout', () => pending.destroy(new Error('Timeout')));
        pending.on('error', () => reply(res,502,'UPSTREAM_UNAVAILABLE'));
        res.on('close', () => { if (!res.writableEnded) pending.destroy(); });
        pending.end(Buffer.concat(chunks));
        return;
      }
      if (!['GET','HEAD'].includes(req.method)) return reply(res,405,'METHOD_DENIED');
      const relative = packagedAssets.get(path) ?? (path === '/' ? 'index.html' : path.slice(1));
      if (!packagedAssets.has(path) && !rootFiles.has(relative) &&
          !/^(assets|canvaskit|icons)\/[A-Za-z0-9_./-]+$/.test(relative)) return reply(res,404,'ROUTE_DENIED');
      if (relative.split('/').some(part => !part || part.startsWith('.')) ||
          /\.(?:map|symbols|env|pem|p8|sql|log)$/.test(relative)) return reply(res,404,'ROUTE_DENIED');
      const file = resolve(root,relative);
      // realpath equality rejects symlinks, including links within the asset tree.
      try {
        if (await realpath(file) !== file || !(await stat(file)).isFile()) return reply(res,404,'ROUTE_DENIED');
      } catch { return reply(res,404,'ROUTE_DENIED'); }
      const representation = await staticRepresentation(await readFile(file), req.headers['accept-encoding']);
      res.writeHead(200,{'Content-Type':types[extname(file)] || 'application/octet-stream',
        'Content-Length':representation.data.length, 'Cache-Control':'no-store',
        'Vary':'Accept-Encoding',
        ...(representation.encoding ? {'Content-Encoding':representation.encoding} : {})});
      res.end(req.method === 'HEAD' ? undefined : representation.data);
    } catch { reply(res,503,'SERVICE_UNAVAILABLE'); }
  });
  server.headersTimeout = 10000;
  server.requestTimeout = 15000;
  const summaryTimer=setInterval(()=>security.flush(),60000);summaryTimer.unref();
  server.on('close',()=>{clearInterval(summaryTimer);security.flush();});
  return server;
}
