import {platformBlocked} from './account_policy.mjs';
import { createPrivateKey, sign } from 'node:crypto';
import { verifyProviderIdToken } from 'better-auth/oauth2';

export const socialOrder = ['google', 'apple', 'facebook'];
export function secureAppleProvider(provider) {
  provider.requiresIdTokenNonce = true;
  provider.idToken.algorithms = ['RS256'];
  const authorize = provider.createAuthorizationURL.bind(provider);
  provider.createAuthorizationURL = async (options) => {
    if (!options.idTokenNonce) throw new Error('Apple nonce required.');
    const url = await authorize(options);
    url.searchParams.set('nonce',options.idTokenNonce);
    return url;
  };
  const userInfo = provider.getUserInfo.bind(provider);
  provider.getUserInfo = async (tokens) => {
    if (!tokens.idToken || !tokens.expectedIdTokenNonce ||
        !await verifyProviderIdToken(provider,tokens.idToken,tokens.expectedIdTokenNonce)) return null;
    return userInfo(tokens);
  };
}
const providerHosts = { google: ['accounts.google.com'], apple: ['appleid.apple.com'], facebook: ['www.facebook.com', 'facebook.com'] };
const origin = (value, fallback) => {
  const url = new URL(value || fallback);
  if (url.origin !== (value || fallback) || url.username || url.password ||
      (url.protocol !== 'https:' && url.origin !== fallback)) throw new Error('Invalid auth origin.');
  return url.origin;
};
const required = (env, name) => {
  if (typeof env[name] !== 'string' || !env[name].trim()) throw new Error('Social provider configuration incomplete.');
  return env[name].trim();
};
export function authOrigins(env = {}) {
  return {
    apiOrigin:origin(env.CA_AUTH_API_ORIGIN,'http://127.0.0.1:8000'),
    uiOrigin:origin(env.CA_AUTH_UI_ORIGIN,'http://127.0.0.1:8300'),
  };
}
// All credentials stay server-side. No provider is enabled merely by installing Better Auth.
export function socialConfiguration(env = {}) {
  const {apiOrigin,uiOrigin} = authOrigins(env);
  const requested = env.CA_SOCIAL_PROVIDERS ? env.CA_SOCIAL_PROVIDERS.split(',').map(v => v.trim()) : [];
  if (new Set(requested).size !== requested.length || requested.some(v => !socialOrder.includes(v))) throw new Error('Unknown social provider.');
  const providers = socialOrder.filter(v => requested.includes(v));
  if (providers.length) required(env, 'BETTER_AUTH_SECRET');
  const socialProviders = {};
  for (const id of providers) {
    const prefix = id.toUpperCase();
    const clientId = required(env, `${prefix}_CLIENT_ID`);
    if (id === 'apple') {
      if (!apiOrigin.startsWith('https:') || !uiOrigin.startsWith('https:')) throw new Error('Apple requires HTTPS origins.');
      const team = required(env, 'APPLE_TEAM_ID'), kid = required(env, 'APPLE_KEY_ID');
      if (!/^[A-Z0-9]{10}$/.test(team) || !/^[A-Z0-9]{10}$/.test(kid)) throw new Error('Invalid Apple identifiers.');
      let key;
      try { key = createPrivateKey(required(env, 'APPLE_PRIVATE_KEY')); } catch { throw new Error('Invalid Apple signing key.'); }
      if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') throw new Error('Invalid Apple signing key.');
      const now = Math.floor(Date.now() / 1000);
      const b64 = value => Buffer.from(JSON.stringify(value)).toString('base64url');
      const unsigned = `${b64({alg:'ES256',kid})}.${b64({iss:team,iat:now,exp:now+180*86400,aud:'https://appleid.apple.com',sub:clientId})}`;
      const clientSecret = `${unsigned}.${sign('sha256',Buffer.from(unsigned),{key,dsaEncoding:'ieee-p1363'}).toString('base64url')}`;
      socialProviders.apple = {clientId,clientSecret};
    } else {
      socialProviders[id] = {clientId,clientSecret:required(env,`${prefix}_CLIENT_SECRET`),
        ...(id === 'google' ? {prompt:'select_account',accessType:'online',includeGrantedScopes:false} : {})};
    }
  }
  return {apiOrigin,uiOrigin,providers,socialProviders};
}

const json = (res,status,data) => {res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
async function readBody(req) {
  let raw = '';
  for await (const chunk of req) {raw += chunk;if(Buffer.byteLength(raw)>16384) throw new Error('body');}
  return raw;
}
export function createSocialGateway(auth,config,pool=null) {
  const {apiOrigin,uiOrigin,providers} = config;
  const callbackProvider = path => /^\/api\/auth\/callback\/(google|apple|facebook)$/.exec(path)?.[1];
  const enabledCallback = path => providers.includes(callbackProvider(path));
  const isApplePost = req => req.method==='POST' && enabledCallback(new URL(req.url,apiOrigin).pathname) && callbackProvider(new URL(req.url,apiOrigin).pathname)==='apple';
  const headersFor = req => new Headers(Object.entries(req.headers).filter(([k])=>['origin','cookie','authorization','content-type'].includes(k)));
  const cookieName = async () => (await auth.$context).authCookies.sessionToken.name;
  const cookieAttributes = `Path=/; HttpOnly; SameSite=${providers.includes('apple')?'None':'Lax'}${apiOrigin.startsWith('https:')?'; Secure':''}`;
  const expireSession = async res => res.setHeader('Set-Cookie',`${await cookieName()}=; Max-Age=0; ${cookieAttributes}`);
  const copyCookies = (result,res) => {
    const cookies = result.headers.getSetCookie();
    if(cookies.length) res.setHeader('Set-Cookie',cookies.map(c=>/max-age=0(?:;|$)/i.test(c)?c:
      `${c.replace(/;\s*Max-Age=[^;]*/ig,'')}; Max-Age=300`));
  };
  const trustedRequest = req => req.headers.origin === uiOrigin || req.headers.origin === apiOrigin;
  async function handle(req,res,url) {
    const callback = callbackProvider(url.pathname);
    if(url.pathname==='/api/account/social/providers' && req.method==='GET') {json(res,200,{providers});return true;}
    if(callback) {
      if(!providers.includes(callback)) {json(res,404,{code:'SOCIAL_NOT_CONFIGURED'});return true;}
      if(req.method!=='GET' && !(callback==='apple' && req.method==='POST')) {json(res,405,{code:'METHOD_NOT_ALLOWED'});return true;}
      const allowed=['code','state','error','error_description','iss',
        ...(callback==='google'?['scope','authuser','prompt','hd']:[])];
      if([...url.searchParams.keys()].some(k=>!allowed.includes(k)) || allowed.some(k=>url.searchParams.getAll(k).length>1) || req.url.length>16384) {json(res,400,{code:'INVALID_QUERY'});return true;}
      const headers=headersFor(req);headers.delete('authorization');
      let raw;
      if(req.method==='POST') {
        if(!req.headers['content-type']?.startsWith('application/x-www-form-urlencoded')) {json(res,415,{code:'FORM_REQUIRED'});return true;}
        try {raw=await readBody(req);} catch {json(res,413,{code:'BODY_TOO_LARGE'});return true;}
        const data=new URLSearchParams(raw),keys=[...allowed,'user','id_token'];
        if([...data.keys()].some(k=>!keys.includes(k)) || keys.some(k=>data.getAll(k).length>1) || url.search) {json(res,400,{code:'INVALID_QUERY'});return true;}
        // Identity comes from the server-side code exchange and its verified
        // ID token, never from an unsolicited token supplied to this endpoint.
        data.delete('id_token');raw=data.toString();
      }
      try {
        // Better Auth redirects Apple's form POST to its GET callback. Resolve
        // that step internally so codes and Apple's one-time user data never
        // appear in a browser redirect or the Flutter URL.
        const callbackQuery=raw===undefined?url.search:`?${new URLSearchParams(raw)}`;
        const callbackState=new URLSearchParams(callbackQuery).get('state');
        const context=await auth.$context;
        // The browser may not swap a Google flow to another provider callback.
        // Better Auth still performs cookie binding, expiry and consumption.
        const saved=callbackState?await context.internalAdapter.findVerificationValue(`auth-state:${callbackState}`):null;
        const savedState=saved?JSON.parse(saved.value):null;
        if(!savedState || savedState.socialProvider!==callback) throw new Error('Invalid provider state.');
        if(savedState.link) {
          const current=await auth.api.getSession({headers:new Headers({cookie:req.headers.cookie??''})});
          if(!current || await platformBlocked(pool,current.user) || current.user.id!==savedState.link.userId || !current.user.emailVerified ||
             current.user.email.toLowerCase()!==savedState.link.email.toLowerCase() ||
             Date.now()-new Date(current.session.createdAt).getTime()>10*60*1000) throw new Error('Link session expired.');
        }
        const result=await auth.handler(new Request(apiOrigin+url.pathname+callbackQuery,{method:'GET',headers}));
        const location=result.headers.get('location');
        let success=false;
        if(location) {const destination=new URL(location,uiOrigin);success=result.status>=300&&result.status<400&&destination.origin===uiOrigin&&destination.hash==='#social=success'&&!destination.search;}
        if(success) copyCookies(result,res);else await expireSession(res);
        res.writeHead(303,{'Location':`${uiOrigin}/#social=${success?'success':'error'}`,'Cache-Control':'no-store'});res.end();
      } catch {await expireSession(res);res.writeHead(303,{'Location':`${uiOrigin}/#social=error`,'Cache-Control':'no-store'});res.end();}
      return true;
    }
    if(!url.pathname.startsWith('/api/account/social/')) return false;
    if(!providers.length) {json(res,404,{code:'SOCIAL_NOT_CONFIGURED'});return true;}
    if(req.method!=='POST'||!trustedRequest(req)||url.search) {json(res,403,{code:'ORIGIN_DENIED'});return true;}
    if(!req.headers['content-type']?.startsWith('application/json')) {json(res,415,{code:'JSON_REQUIRED'});return true;}
    let body;
    try {body=JSON.parse(await readBody(req));} catch {json(res,400,{code:'INVALID_JSON'});return true;}
    if(!body||typeof body!=='object'||Array.isArray(body)) {json(res,400,{code:'INVALID_JSON'});return true;}
    if(url.pathname==='/api/account/social/session') {
      if(Object.keys(body).length) {json(res,422,{code:'INVALID_FIELDS'});return true;}
      const name=await cookieName();
      const cookie=req.headers.cookie?.split(';').map(v=>v.trim()).find(v=>v.startsWith(name+'='))?.slice(name.length+1);
      const session=await auth.api.getSession({headers:new Headers({cookie:req.headers.cookie??''})});
      await expireSession(res);
      if(!cookie||!session) {json(res,401,{code:'UNAUTHENTICATED'});return true;}
      res.setHeader('set-auth-token',cookie);
      json(res,200,{authenticated:true});return true;
    }
    if(url.pathname!=='/api/account/social/start') {json(res,404,{code:'NOT_IMPLEMENTED'});return true;}
    if(!providers.includes(body.provider)||Object.keys(body).some(k=>!['provider','link'].includes(k))||(body.link!==undefined&&typeof body.link!=='boolean')) {json(res,422,{code:'INVALID_FIELDS'});return true;}
    const headers=headersFor(req);headers.delete('cookie');
    let session;
    if(body.link) {
      session=await auth.api.getSession({headers});
      if(!session) {json(res,401,{code:'UNAUTHENTICATED'});return true;}
      if(await platformBlocked(pool,session.user)){json(res,403,{code:'PLATFORM_BLOCKED'});return true;}
      if(!session.user.emailVerified||Date.now()-new Date(session.session.createdAt).getTime()>10*60*1000) {json(res,403,{code:'SOCIAL_REAUTH_REQUIRED'});return true;}
    } else headers.delete('authorization');
    const result=await auth.handler(new Request(`${apiOrigin}/api/auth/${body.link?'link-social':'sign-in/social'}`,{method:'POST',headers,body:JSON.stringify({provider:body.provider,callbackURL:`${uiOrigin}/#social=success`,errorCallbackURL:`${uiOrigin}/#social=error`,disableRedirect:true,additionalData:{socialProvider:body.provider}})}));
    if(!result.ok) {json(res,result.status,{code:'SOCIAL_START_FAILED'});return true;}
    const data=await result.json();
    let destination;
    try {destination=new URL(data.url);} catch {json(res,503,{code:'SOCIAL_START_FAILED'});return true;}
    if(destination.protocol!=='https:'||destination.username||destination.password||destination.port||!providerHosts[body.provider].includes(destination.hostname)) {json(res,503,{code:'SOCIAL_START_FAILED'});return true;}
    copyCookies(result,res);
    if(body.link) {
      const token=req.headers.authorization?.replace(/^Bearer /i,'');
      if(!token) {json(res,401,{code:'UNAUTHENTICATED'});return true;}
      const current=res.getHeader('Set-Cookie')??[];
      res.setHeader('Set-Cookie',[...(Array.isArray(current)?current:[current]),`${await cookieName()}=${token}; Max-Age=300; ${cookieAttributes}`]);
    }
    json(res,200,{url:destination.toString()});return true;
  }
  return {providers,enabledCallback,isApplePost,handle,expireSession};
}
