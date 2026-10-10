import {extendedProduct,directoryRouteEnabled} from './product_scope.mjs';
import {createAccountDeletion} from './account_deletion.mjs';
import {validateAccountAge} from './account_age.mjs';
import {platformBlocked,enforceAccountAction} from './account_policy.mjs';
import {createLegal} from './legal.mjs';
import { createServer } from 'node:http';
import { DirectoryError } from './directory.mjs';
import { apiOrigin, uiOrigin, dashboardOrigin, syntheticEmail } from './auth.mjs';
import { createRequestLimits, createSecuritySummary, apiSecurityHeaders, createRetentionJob } from './request_security.mjs';

const authPosts = new Set(['sign-up/email', 'sign-in/email', 'sign-out',
  'request-password-reset', 'send-verification-email']);
const localHosts = new Set(['127.0.0.1:8000', 'localhost:8000']);
const json = (response, status, body) => {
  response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  response.end(JSON.stringify(body));
};
const escape = (text) => text.replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function createApp({ auth, mailbox, dashboardEnabled, consumeLink,
  acceptsEmail = syntheticEmail, privateMail = false, databaseRestricted = false, directory = null,
  apiOrigin:authOrigin=apiOrigin,uiOrigin:applicationOrigin=uiOrigin,social=null,
  minimumAccountAge=0,accountAgeReviewed=false,mailBudgetEnabled=false,ticketing=null,pool=null,privateCommunitiesEnabled=true, requestLimits=createRequestLimits(), onSecuritySummary, runAuthRequest=async work=>({result:await work(),mailFailed:false}) }) {
  const deletion=pool?createAccountDeletion(pool,auth):null;
  const legal=directory&&!privateMail&&pool?createLegal(pool):null;
  const allowedHosts=new Set([...localHosts,new URL(authOrigin).host]);
  const security=createSecuritySummary(onSecuritySummary);
  let active=0;
  // Serialize same-address signups in this bounded single-process pilot. A
  // unique-index race must not reveal an account through a different response.
  const signups=new Map();
  async function signup(email,work){
    const key=typeof email==='string'?email.trim().toLowerCase():null;
    const previous=signups.get(key)??Promise.resolve();
    const current=previous.catch(()=>{}).then(work);
    signups.set(key,current);
    try{return await current;}finally{if(signups.get(key)===current)signups.delete(key);}
  }
  const limited=(response,result)=>{
    if(!result)return false;
    response.setHeader('Retry-After',String(result.retryAfter));
    json(response,429,{code:'RATE_LIMITED'});return true;
  };
  const server=createServer({headersTimeout:10000,requestTimeout:15000,
    connectionsCheckingInterval:1000,maxHeaderSize:16384},async (request, response) => {
    apiSecurityHeaders(response);
    response.once('finish',()=>security.response(response.statusCode));
    let admitted=false;
    try {
      if (!allowedHosts.has(request.headers.host)) return json(response, 403, { code: 'LOCAL_ONLY' });
      if(typeof request.url!=='string'||request.url.length>8192||!request.url.startsWith('/')||
          request.url.startsWith('//')||/[\\#\x00-\x20]/.test(request.url)) return json(response,400,{code:'INVALID_URL'});
      const url = new URL(request.url, authOrigin);
      if(url.pathname!=='/health'&&limited(response,requestLimits.global()))return;
      if(active>=16){response.setHeader('Retry-After','1');return json(response,503,{code:'BUSY'});}
      active++;
      admitted=true;
      const dashRoute = dashboardEnabled && url.pathname.startsWith('/api/auth/dash/');
      const origin = request.headers.origin;
      if (origin && origin !== applicationOrigin && origin !== authOrigin &&
          !(social?.isApplePost(request) && origin === 'https://appleid.apple.com') &&
          !(dashRoute && origin === dashboardOrigin)) return json(response, 403, { code: 'ORIGIN_DENIED' });
      if (origin) {
        response.setHeader('Access-Control-Allow-Origin', origin);
        response.setHeader('Access-Control-Allow-Credentials', 'true');
        response.setHeader('Vary', 'Origin');
        response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        response.setHeader('Access-Control-Expose-Headers', 'set-auth-token, Retry-After');
      }
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('Referrer-Policy', 'no-referrer');
      if (request.method === 'OPTIONS') { response.writeHead(204); return response.end(); }
      if((url.pathname.startsWith('/api/auth/')||url.pathname.startsWith('/api/account/social/')||
          ['/api/account/verify','/api/account/reset'].includes(url.pathname))&&
          limited(response,requestLimits.auth()))return;
      if(!extendedProduct&&(url.pathname.startsWith('/api/account/social/')||/\/api\/auth\/(sign-in\/social|link-social|callback\/)/.test(url.pathname)))return json(response,404,{code:'NOT_FOUND'});
      if (social && await social.handle(request,response,url)) return;
      const deletionRoute=deletion && ['/api/account/deletion','/api/account/deletion/queue'].includes(url.pathname);
      const legalRoute=legal&&url.pathname.startsWith('/api/legal/');
      const ticketRoute=ticketing&&url.pathname.startsWith('/api/ticketing/');
      const accessRoute = directory && url.pathname.startsWith('/api/access/');
      const directoryRoute = directory && url.pathname.startsWith('/api/directory/');
      if (url.search && !dashRoute && !directoryRoute) return json(response, 400, { code: 'QUERY_NOT_SUPPORTED' });
      if (request.method === 'GET' && url.pathname === '/health') {
        return json(response, 200, { auth: true, synthetic: !privateMail, dashboardEnabled,
          apiOrigin: authOrigin, uiOrigin: applicationOrigin, databaseRestricted,
          ticketingSynthetic:!!ticketing,securityControls:{apiRateLimits:true,mailBudget:mailBudgetEnabled} });
      }
      if (request.method === 'GET' && url.pathname === '/testing/mailbox') {
        if (privateMail) return json(response, 404, { code: 'NOT_IMPLEMENTED' });
        response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store', 'Content-Security-Policy': "default-src 'none'; base-uri 'none'; frame-ancestors 'none'" });
        return response.end('<!doctype html><html lang="de"><title>Lokales Testpostfach</title>' +
          '<h1>Lokales Testpostfach</h1><p>Ausschließlich synthetische Konten. Kein E-Mail-Versand.</p>' +
          mailbox.map((mail) => `<p>${escape(mail.email)}: <a href="${escape(mail.url)}">${mail.kind === 'verify' ? 'E-Mail bestätigen' : 'Passwort zurücksetzen'}</a></p>`).join('') + '</html>');
      }
      const headers = new Headers();
      for (const name of ['origin', 'authorization', 'cookie']) {
        if (request.headers[name]) headers.set(name, request.headers[name]);
      }
      // A supplied bearer must stand on its own; never fall back to a cookie.
      if(headers.has('authorization'))headers.delete('cookie');
      if (request.method === 'GET' && url.pathname === '/api/account/me') {
        const session = await auth.api.getSession({ headers });
        if (!session) return json(response, 401, { code: 'UNAUTHENTICATED' });
        if(limited(response,requestLimits.account(session.user,request.method)))return;
        if(directory)await directory.accessFlow.purge();
        // Only the validated HttpOnly session cookie can restore the in-memory bearer.
        if(!headers.has('authorization')&&headers.has('cookie')){
          const context=await auth.$context;
          const name=context.authCookies.sessionToken.name;
          const cookie=headers.get('cookie').split(';').map(v=>v.trim()).find(v=>v.startsWith(name+'='));
          if(cookie)response.setHeader('set-auth-token',cookie.slice(name.length+1));
        }
        const blocked=directory&&await platformBlocked(pool,session.user);
        if(blocked)return json(response,200,{user:{name:session.user.name,email:session.user.email,email_verified:session.user.emailVerified},platform_blocked:true,product_available:false,directory_available:false,ticketing_available:!!ticketing,is_host:false,is_team:false,can_manage_access:false,can_scan:false,applications:[],memberships:[],events:[]});
        const capabilities=directory?(await pool.query(`SELECT
          EXISTS(SELECT 1 FROM ca_team WHERE user_id=$1) OR EXISTS(SELECT 1 FROM ca_community_staff WHERE user_id=$1 AND expires_at>NOW()) OR EXISTS(SELECT 1 FROM ca_host WHERE user_id=$1) OR EXISTS(SELECT 1 FROM ca_organizer_member WHERE user_id=$1 AND status='active' AND accepted_at IS NOT NULL) AS can_manage_access,
          EXISTS(SELECT 1 FROM ca_scanner WHERE user_id=$1 AND expires_at>NOW()) AS can_scan`,[session.user.id])).rows[0]:{};
        return json(response, 200, { ...capabilities, platform_blocked:false, user: { name: session.user.name, email: session.user.email,
          email_verified: session.user.emailVerified }, product_available: !!directory,
          ticketing_available:!!ticketing,directory_available: !!directory, preferences_configured:directory?(await directory.discovery.preferences(session.user)).configured:true, is_host: directory ? await directory.isHost(session.user) : false,
          applications: [], memberships: [], events: [],
          ...(directory ? await directory.accessFlow.snapshot(session.user) : {}) });
      }
      const path = url.pathname.replace(/^\/api\/auth\//, '');
      const accountLink = ['/api/account/verify', '/api/account/reset'].includes(url.pathname);
      if (!dashRoute && !directoryRoute && !accessRoute && !ticketRoute && !legalRoute && !deletionRoute && (request.method !== 'POST' || (!authPosts.has(path) && !accountLink))) {
        return json(response, 404, { code: 'NOT_IMPLEMENTED' });
      }
      let body = {};
      if (request.method === 'POST') {
        if (!request.headers['content-type']?.startsWith('application/json')) return json(response, 415, { code: 'JSON_REQUIRED' });
        const chunks=[];
        let size=0;
        const maxBody=directoryRoute&&url.pathname==='/api/directory/manage/event'?400000:16384;
        if(Number(request.headers['content-length'])>maxBody)return json(response,413,{code:'BODY_TOO_LARGE'});
        for await (const chunk of request) {
          size+=chunk.length;
          if(size>maxBody)return json(response,413,{code:'BODY_TOO_LARGE'});
          chunks.push(chunk);
        }
        const raw=Buffer.concat(chunks).toString('utf8');
        try { body = JSON.parse(raw); } catch { return json(response, 400, { code: 'INVALID_JSON' }); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) return json(response, 400, { code: 'INVALID_JSON' });
      }
      if(deletionRoute){
        const session=await auth.api.getSession({headers});
        if(!session)return json(response,401,{code:'UNAUTHENTICATED'});
        if(limited(response,requestLimits.account(session.user,request.method)))return;
        if(url.pathname.endsWith('/queue')) {
          if(request.method!=='GET'||!directory)return json(response,404,{code:'NOT_FOUND'});
          return json(response,200,await deletion.queue(session));
        }
        if(request.method==='GET')return json(response,200,await deletion.read(session));
        if(request.method==='POST'){
          if(limited(response,requestLimits.auth()))return;
          return json(response,200,await deletion.request(session,headers,body));
        }
        return json(response,405,{code:'METHOD_NOT_ALLOWED'});
      }
      if(legalRoute){
        const session=await auth.api.getSession({headers});
        if(!session&&request.headers.authorization)return json(response,401,{code:'UNAUTHENTICATED'});
        if(limited(response,requestLimits.account(session?.user,request.method)))return;
        if(request.method==='POST'&&url.pathname==='/api/legal/reports'&&limited(response,requestLimits.auth()))return;
        return json(response,200,await enforceAccountAction(pool,session?.user,()=>legal.route(session?.user,url.pathname.slice('/api/legal/'.length),request.method,body),{complaint:request.method==='GET'&&url.pathname==='/api/legal/mine'||request.method==='POST'&&(url.pathname==='/api/legal/reports'||/^\/api\/legal\/actions\/[a-f0-9-]{36}\/statement$/.test(url.pathname))}));
      }
      if(ticketRoute){
        if(url.pathname.startsWith('/api/ticketing/internal/')){
          if(request.method!=='POST'||!['127.0.0.1','::1'].includes(request.socket.remoteAddress)||
            !ticketing.authorizesService(request.headers.authorization))return json(response,403,{code:'SERVICE_DENIED'});
          const action=url.pathname.slice('/api/ticketing/internal/'.length);
          if(!['redeem','validate'].includes(action))return json(response,404,{code:'NOT_FOUND'});
          return json(response,200,await ticketing.nativeAuthorization(body,action==='redeem'));
        }
        const session=await auth.api.getSession({headers});
        if(!session&&request.headers.authorization)return json(response,401,{code:'UNAUTHENTICATED'});
        if(limited(response,requestLimits.account(session?.user,request.method)))return;
        return json(response,200,await enforceAccountAction(pool,session?.user,()=>ticketing.route(session?.user,url.pathname.slice('/api/ticketing/'.length),request.method,body),{complaint:request.method==='GET'&&(url.pathname==='/api/ticketing/mine'||/^\/api\/ticketing\/orders\/[a-f0-9-]{36}$/.test(url.pathname))}));
      }
      if(accessRoute){
        const session=await auth.api.getSession({headers});
        if(limited(response,requestLimits.account(session?.user,request.method)))return;
        const accessPath=url.pathname.slice('/api/access/'.length);
        if(!privateCommunitiesEnabled&&request.method==='POST'&&(accessPath==='applications'||/^communities\/[a-f0-9-]{36}\/invite$/.test(accessPath)||/^policy\/events\/[a-f0-9-]{36}\/(share|approve-share)$/.test(accessPath)))return json(response,409,{code:'PRIVATE_COMMUNITIES_PAUSED'});
        if(ticketing&&request.method==='POST'&&/^policy\/(events|orders)\/[a-f0-9-]{36}\/(checkin|token)$/.test(accessPath))await ticketing.reconcile();
        const data=await enforceAccountAction(pool,session?.user,()=>accessPath.startsWith('policy/')?directory.privateAccess.route(session?.user,accessPath.slice(7),request.method,body):directory.accessFlow.route(session?.user,accessPath,request.method,body),{complaint:request.method==='GET'&&accessPath==='policy/complaints'||request.method==='POST'&&/^policy\/cases\/[a-f0-9-]{36}\/appeal$/.test(accessPath)});
        if(ticketing)await ticketing.reconcile();
        return json(response,200,data);
      }
      if (directoryRoute) {
        const session = await auth.api.getSession({ headers });
        if (!session && request.headers.authorization) return json(response,401,{code:'UNAUTHENTICATED'});
        const user = session?.user;
        if(limited(response,requestLimits.account(user,request.method)))return;
        await directory.discovery.purge();
        await directory.accessFlow.purge();
        const route = url.pathname.slice('/api/directory/'.length);
        if(!directoryRouteEnabled(route,request.method,body))return json(response,404,{code:'NOT_FOUND'});
        const allowedQuery = route === 'manage' ? ['profile_id'] : route === 'organizers' ? ['q','community','page'] : route==='events' ? ['q','page','scope'] : route==='venues' ? ['q','page'] : route === 'venue' ? ['name'] : /^(organizers\/[0-9a-f-]{36}\/program|series\/[0-9a-f-]{36})$/.test(route) ? ['page'] : [];
        if ([...url.searchParams.keys()].some(k => !allowedQuery.includes(k)) ||
            allowedQuery.some(k=>url.searchParams.getAll(k).length>1)) return json(response,400,{code:'INVALID_QUERY'});
        let data;
        await enforceAccountAction(pool,user,async()=>{
        const match = /^(organizers|requests|links|events|series)\/([0-9a-f-]{36})(?:\/(access|interest|visit|apply|redeem|decide|withdraw|revoke|program))?$/.exec(route);
        if (request.method === 'GET') {
          if (route === 'home') data = await directory.discovery.home(user);
          else if(route==='preferences') data=await directory.discovery.preferences(user);
          else if(route==='communities') data=await directory.discovery.communities(user);
          else if(match?.[1]==='events'&&match[3]==='access') data=await directory.discovery.access(user,match[2]);
          else if (route === 'organizers') data = await directory.list(url.searchParams,user);
          else if (route === 'events') data = await directory.catalog.publicEvents(url.searchParams,user);
          else if (route === 'venues') data = await directory.venues(url.searchParams);
          else if (route === 'venue') data = await directory.venueEvents(url.searchParams);
          else if (route === 'bookmarks') data = await directory.catalog.bookmarks(user);
          else if (route === 'manage') data = {...await directory.management(user,url.searchParams.get('profile_id')),ticketing_available:!!ticketing};
          else if (match?.[1] === 'organizers' && !match[3]) data = await directory.detail(match[2],user);
          else if (match?.[1] === 'organizers' && match[3] === 'access') data = await directory.access(match[2],user);
          else if (match?.[1] === 'organizers' && match[3] === 'program') data = await directory.catalog.program(match[2],user,url.searchParams.get('page')??1);
          else if (match?.[1] === 'events' && !match[3]) data = await directory.catalog.eventDetail(match[2],user);
          else if (match?.[1] === 'series' && !match[3]) data = await directory.catalog.seriesDetail(match[2],user,url.searchParams.get('page')??1);
          else return json(response,404,{code:'NOT_FOUND'});
        } else if (request.method === 'POST') {
          if(route==='preferences') data=await directory.discovery.preferences(user,body);
          else if(route==='forget-visit') data=await directory.discovery.forgetVisit(user,body);
          else if(route==='follow') data=await directory.discovery.follow(user,body);
          else if(route==='manage/form') data=await directory.discovery.saveForm(user,body);
          else if(route==='manage/interest') data=await directory.discovery.decide(user,body);
          else if(match?.[1]==='events'&&match[3]==='interest') data=await directory.discovery.interest(user,match[2],body);
          else if(match?.[1]==='events'&&match[3]==='withdraw') data=await directory.discovery.withdraw(user,match[2]);
          else if(match?.[1]==='events'&&match[3]==='visit') data=await directory.discovery.visit(user,match[2]);
          else if (route === 'bookmark') data = await directory.catalog.bookmark(user,body);
          else if (route === 'manage/preview') data = await directory.catalog.preview(user,body);
          else if (route === 'manage/profile') data = await directory.save(user,body);
          else if (route === 'manage/event') data = await directory.saveEvent(user,body);
          else if (route === 'manage/link') data = await directory.issueLink(user,body);
          else if (route === 'manage/series') data = await directory.catalog.saveSeries(user,body);
          else if (route === 'manage/grant') data = await directory.catalog.grant(user,body);
          else if (route === 'manage/revoke') data = await directory.catalog.revoke(user,body);
          else if (match?.[1] === 'organizers' && match[3] === 'apply') data = await directory.apply(match[2],user,body);
          else if (match?.[1] === 'organizers' && match[3] === 'redeem') data = await directory.redeem(user,match[2],body);
          else if (match?.[1] === 'requests' && match[3] === 'decide') data = await directory.decide(user,match[2],body);
          else if (match?.[1] === 'requests' && match[3] === 'withdraw') data = await directory.withdraw(user,match[2]);
          else if (match?.[1] === 'links' && match[3] === 'revoke') data = await directory.revokeLink(user,match[2]);
          else return json(response,404,{code:'NOT_FOUND'});
        } else return json(response,405,{code:'METHOD_NOT_ALLOWED'});
        });
        if(response.writableEnded)return;
        if(ticketing)await ticketing.reconcile();
        return json(response,200,data);
      }
      if (!dashRoute && body.email !== undefined && !acceptsEmail(body.email)) {
        return json(response, 422, { code: privateMail ? 'INVALID_EMAIL' : 'SYNTHETIC_EMAIL_REQUIRED' });
      }
      // Validate the complete public link contract before consuming anything.
      // In particular, an extra `password` must not shadow `newPassword`.
      if (accountLink) {
        const reset = url.pathname.endsWith('/reset');
        const allowed = reset ? ['email','token','newPassword'] : ['email','token'];
        if (Object.keys(body).some(key => !allowed.includes(key)) ||
            !acceptsEmail(body.email) || typeof body.token !== 'string' ||
            !/^[a-f0-9]{64}$/.test(body.token)) {
          return json(response,422,{code:'INVALID_ACCOUNT_LINK'});
        }
        if (reset && typeof body.newPassword !== 'string') {
          return json(response,422,{code:'INVALID_PASSWORD'});
        }
      }
      if(path==='sign-up/email'){
        const ageError=validateAccountAge(body,{minimumAccountAge,accountAgeReviewed});
        if(ageError)return json(response,ageError.status,{code:ageError.code});
        // Product metadata is validated here and never added to provider/user fields.
        delete body.age_acknowledged;delete body.minimum_age;
      }
      // Reject password formats the existing Flutter form cannot accept.
      const password = accountLink ? body.newPassword : body.password;
      if (password !== undefined && (typeof password !== 'string' || password.length < 12 ||
          password.length > 72 || Buffer.byteLength(password) > 72)) {
        return json(response, 422, { code: 'INVALID_PASSWORD' });
      }
      let upstream = url.pathname + (dashRoute ? url.search : '');
      let method = request.method;
      if (accountLink) {
        const kind = url.pathname.endsWith('/verify') ? 'verify' : 'reset';
        const token = await consumeLink(kind, body.email, body.token);
        if (!token) return json(response, 422, { code: 'INVALID_ACCOUNT_LINK' });
        if (kind === 'verify') {
          upstream = `/api/auth/verify-email?token=${encodeURIComponent(token)}`;
          method = 'GET';
        } else {
          upstream = '/api/auth/reset-password';
          body = { token, newPassword: body.newPassword };
        }
      } else if (path === 'request-password-reset' || path === 'send-verification-email') {
        body = { email: body.email, redirectTo: applicationOrigin + '/' };
      }
      headers.set('Content-Type', 'application/json');
      const authenticate=()=>auth.handler(new Request(authOrigin+upstream,{method,headers,...(method==='POST'?{body:JSON.stringify(body)}:{})}));
      const {result,mailFailed,mailUncertain} = await runAuthRequest(()=>path==='sign-up/email'?signup(body.email,authenticate):authenticate());
      if(mailUncertain)return json(response,503,{code:'LINK_STATUS_UNKNOWN'});
      if(mailFailed)return json(response,503,{code:'MAIL_UNAVAILABLE'});
      if (!result.ok) {
        const retry=result.headers.get('retry-after');
        if(result.status===429&&/^\d{1,6}$/.test(retry??''))response.setHeader('Retry-After',retry);
        return json(response, result.status, { code: 'AUTH_REQUEST_FAILED' });
      }
      if(path==='sign-up/email')return json(response,200,{registration_requested:true});
      const signedToken = result.headers.get('set-auth-token');
      if (signedToken) response.setHeader('set-auth-token', signedToken);
      if (path === 'sign-out' && social?.providers.length) await social.expireSession(response);
      // HttpOnly cookies retain the database-validated session across reloads.
      // Absolute expiry is enforced by Better Auth; no browser token storage.
      const cookies=result.headers.getSetCookie?.()??[];
      if(cookies.length)response.setHeader('Set-Cookie',cookies);
      const data = await result.text();
      response.writeHead(result.status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      response.end(data || '{}');
    } catch (error) {
      if (error instanceof DirectoryError) return json(response,error.status,{code:error.code});
      if(error?.code==='MAIL_BUDGET_EXHAUSTED')security.record('mail_budget_exhausted');
      json(response, 503, { code: 'AUTH_SERVICE_UNAVAILABLE' });
    }finally{if(admitted)active--;}
  });
  // Skip overlapping timer runs; request-time checks still enforce retention.
  const cleanup=directory?createRetentionJob(directory,()=>security.record('cleanup_failed')):null;
  let ticketBusy=false;
  const ticketTimer=ticketing?setInterval(async()=>{if(ticketBusy)return;ticketBusy=true;try{await ticketing.reconcile();}catch{security.record('cleanup_failed');}finally{ticketBusy=false;}},5000):null;
  ticketTimer?.unref();
  const retentionTimer=cleanup?setInterval(()=>cleanup(),60000):null;
  retentionTimer?.unref();
  const summaryTimer=setInterval(()=>security.flush(),60000);summaryTimer.unref();
  server.on('close',()=>{if(ticketTimer)clearInterval(ticketTimer);if(retentionTimer)clearInterval(retentionTimer);clearInterval(summaryTimer);security.flush();});
  return server;
}
