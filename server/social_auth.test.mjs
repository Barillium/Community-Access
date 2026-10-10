import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {generateKeyPairSync} from 'node:crypto';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {seedDirectory} from './directory_fixtures.mjs';

test('social sign-in: real Better Auth/PostgreSQL with synthetic provider exchanges',async t=>{
  const key=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
  const env={...process.env,CA_SOCIAL_PROVIDERS:'google,apple,facebook',
    CA_AUTH_API_ORIGIN:'https://auth.example.invalid',CA_AUTH_UI_ORIGIN:'https://app.example.invalid',
    GOOGLE_CLIENT_ID:'synthetic-google',GOOGLE_CLIENT_SECRET:'synthetic-google-secret',
    APPLE_CLIENT_ID:'invalid.example.synthetic',APPLE_TEAM_ID:'SYNTHETIC1',APPLE_KEY_ID:'SYNTHETIC2',
    APPLE_PRIVATE_KEY:key.privateKey.export({type:'pkcs8',format:'pem'}),
    FACEBOOK_CLIENT_ID:'synthetic-facebook',FACEBOOK_CLIENT_SECRET:'synthetic-facebook-secret'};
  const originalFetch=globalThis.fetch;
  let externalCalls=0;
  globalThis.fetch=()=>{externalCalls++;throw new Error('No external calls in synthetic social tests.');};
  const state=await createAuth({env});
  const f=await seedDirectory(state);
  const context=await state.auth.$context;
  // Only the external code/profile exchanges are mocked. Better Auth still
  // performs its real state, account linking, session and database operations.
  let identity={sub:'synthetic-subject',name:'Synthetic social guest',email:'social@example.invalid',emailVerified:true};
  let exchanges=0;
  for(const provider of context.socialProviders){
    provider.validateAuthorizationCode=async()=>{exchanges++;return {accessToken:'synthetic-provider-token',refreshToken:'synthetic-refresh',idToken:'synthetic-id-token',scopes:['email']};};
    provider.getUserInfo=async()=>({user:identity,data:identity});
    provider.accountSubject=({profile})=>profile.sub;
  }
  const server=createApp(state);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,{body,method=body===undefined?'GET':'POST',cookie='',token,origin=env.CA_AUTH_UI_ORIGIN,type='application/json'}={})=>new Promise((resolve,reject)=>{
    const req=request(base+path,{method,headers:{Host:'auth.example.invalid',Origin:origin,'Content-Type':type,Connection:'close',
      ...(cookie?{Cookie:cookie}:{}),...(token?{Authorization:'Bearer '+token}:{})}},res=>{
      let raw='';res.setEncoding('utf8');res.on('data',v=>raw+=v);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,
        data:res.headers['content-type']?.includes('application/json')?JSON.parse(raw):raw}));res.on('error',reject);
    });req.on('error',reject);req.end(body===undefined?undefined:typeof body==='string'?body:JSON.stringify(body));
  });
  const jar=(response,previous='')=>{
    const values=new Map(previous.split(';').map(v=>v.trim()).filter(Boolean).map(v=>{const i=v.indexOf('=');return [v.slice(0,i),v.slice(i+1)];}));
    for(const cookie of response.headers['set-cookie']??[]){const pair=cookie.split(';')[0],i=pair.indexOf('=');
      if(/max-age=0(?:;|$)/i.test(cookie))values.delete(pair.slice(0,i));else values.set(pair.slice(0,i),pair.slice(i+1));}
    return [...values].map(([k,v])=>k+'='+v).join('; ');
  };
  const start=async(provider,options={})=>{
    // Each independent scenario gets a fresh fixture rate window. Production
    // limits remain enabled and are exercised separately below.
    await state.pool.query('DELETE FROM "rateLimit"');
    const result=await call('/api/account/social/start',{body:{provider,link:!!options.link},token:options.token});
    assert.equal(result.status,200);const url=new URL(result.data.url);
    assert.equal(url.searchParams.get('redirect_uri'),env.CA_AUTH_API_ORIGIN+'/api/auth/callback/'+provider);
    assert.ok(url.searchParams.get('state'));return {result,url,cookie:jar(result)};
  };
  const finish=async(provider,flow,{cookie=flow.cookie,extra='',appleForm=false}={})=>{
    const query=new URLSearchParams({code:'synthetic-code',state:flow.url.searchParams.get('state')});
    if(appleForm){query.set('id_token','untrusted-form-token');query.set('user',JSON.stringify({name:{firstName:'Synthetic'}}));
      return call('/api/auth/callback/apple',{method:'POST',body:query.toString(),cookie,type:'application/x-www-form-urlencoded',origin:'https://appleid.apple.com'});}
    return call('/api/auth/callback/'+provider+'?'+query+extra,{cookie,origin:undefined});
  };
  const bridge=async(cookie)=>call('/api/account/social/session',{body:{},cookie});
  let googleToken;
  try{
    await t.test('discovery and fixed destinations, origin and field restrictions',async()=>{
      assert.deepEqual((await call('/api/account/social/providers')).data,{providers:['google','apple','facebook']});
      assert.equal((await call('/api/account/social/start',{body:{provider:'google'},origin:'https://attacker.example.invalid'})).status,403);
      for(const body of [{provider:'other'},{provider:'google',callbackURL:'https://evil.example.invalid'},{provider:'google',scopes:['mail']},{provider:'google',idToken:{token:'forged'}}]){
        assert.equal((await call('/api/account/social/start',{body})).status,422);
      }
      assert.equal((await call('/api/auth/callback/google?state=a&state=b')).status,400);
      assert.equal((await call('/api/account/me',{origin:'https://appleid.apple.com'})).status,403);
    });
    await t.test('Google code callback → signed handoff → verified account, no inherited product rights',async()=>{
      const flow=await start('google');
      assert.ok(flow.url.searchParams.get('code_challenge'));assert.equal(flow.url.searchParams.get('access_type'),'online');
      assert.ok((flow.result.headers['set-cookie']??[]).every(cookie=>cookie.includes('HttpOnly')&&cookie.includes('Secure')));
      const result=await finish('google',flow,{extra:'&scope=openid%20email&authuser=0&prompt=select_account&iss=https%3A%2F%2Faccounts.google.com'});
      assert.equal(result.status,303);assert.equal(result.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=success');
      const cookie=jar(result,flow.cookie);const session=await bridge(cookie);
      assert.equal(session.status,200);assert.deepEqual(session.data,{authenticated:true});googleToken=session.headers['set-auth-token'];assert.ok(googleToken);
      assert.ok(session.headers['set-cookie'].every(c=>c.includes('Max-Age=0')));
      const me=await call('/api/account/me',{token:googleToken});assert.equal(me.status,200);assert.equal(me.data.user.email_verified,true);
      assert.equal(me.data.is_host,false);assert.deepEqual(me.data.memberships,[]);
      assert.equal((await call('/api/directory/manage',{token:googleToken})).status,403);
      assert.equal((await call('/api/directory/events/'+f.hiddenEvent.id,{token:googleToken})).status,404);
      const stored=(await state.pool.query('SELECT "accessToken","refreshToken","idToken" FROM account WHERE "providerId"=\'google\'')).rows[0];
      assert.notEqual(stored.accessToken,'synthetic-provider-token');assert.notEqual(stored.refreshToken,'synthetic-refresh');
      assert.equal(stored.idToken,null);
      const replay=await finish('google',flow);assert.equal(replay.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
    });
    await t.test('missing/forged state cannot exchange identity and callback errors reveal no details',async()=>{
      const flow=await start('google'),before=exchanges;
      const result=await finish('google',flow,{cookie:''});assert.equal(result.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');assert.equal(exchanges,before);
      const forged=await call('/api/auth/callback/google?code=x&state=forged');assert.equal(forged.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
      const mixed=await start('google'),beforeMixed=exchanges;
      const swapped=await finish('facebook',mixed);assert.equal(swapped.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');assert.equal(exchanges,beforeMixed);
      // An expired state also cannot reach the external code exchange.
      const expired=await start('google');
      await state.pool.query('UPDATE verification SET "expiresAt"=NOW()-INTERVAL \'1 minute\' WHERE identifier=$1',['auth-state:'+expired.url.searchParams.get('state')]);
      assert.equal((await finish('google',expired)).headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
      const cancelled=await start('google');
      const error=await call('/api/auth/callback/google?state='+cancelled.url.searchParams.get('state')+'&error=access_denied&error_description=private-detail',{cookie:cancelled.cookie});
      assert.equal(error.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');assert.equal(error.data,'');
      assert.equal((await bridge('')).status,401);assert.equal((await bridge('__Secure-better-auth.session_token=forged')).status,401);
    });
    await t.test('Apple form callback supports one-time user fields without publishing them in a redirect',async()=>{
      identity={sub:'synthetic-apple-subject',name:'Synthetic Apple',email:'apple@example.invalid',emailVerified:true};
      const flow=await start('apple');assert.equal(flow.url.searchParams.get('response_mode'),'form_post');assert.ok(flow.url.searchParams.get('nonce'));
      const result=await finish('apple',flow,{appleForm:true});assert.equal(result.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=success');
      const session=await bridge(jar(result,flow.cookie));assert.equal(session.status,200);
      const me=await call('/api/account/me',{token:session.headers['set-auth-token']});assert.equal(me.data.user.email,'apple@example.invalid');
      const stored=await state.auth.options.socialProviders.apple.mapProfileToUser({sub:identity.sub});
      assert.equal(stored.email,identity.email);assert.equal(stored.emailVerified,true);
      assert.deepEqual(await state.auth.options.socialProviders.apple.mapProfileToUser({sub:'never-linked'}),{});
      assert.equal((await call('/api/auth/callback/apple',{body:'code=x&state=x&state=y',type:'application/x-www-form-urlencoded',origin:'https://appleid.apple.com'})).status,400);
    });
    await t.test('Facebook creates a distinct account and fails safely when email is absent',async()=>{
      identity={sub:'synthetic-facebook-subject',name:'Synthetic Facebook',email:'facebook@example.invalid',emailVerified:true};
      const flow=await start('facebook');const result=await finish('facebook',flow);assert.equal(result.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=success');
      const session=await bridge(jar(result,flow.cookie));assert.equal((await call('/api/account/me',{token:session.headers['set-auth-token']})).data.user.email,identity.email);
      identity={sub:'synthetic-no-email',name:'No email'};
      const missing=await start('facebook');assert.equal((await finish('facebook',missing)).headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
      assert.equal((await state.pool.query('SELECT 1 FROM account WHERE "accountId"=$1',[identity.sub])).rowCount,0);
    });
    await t.test('existing password accounts cannot be implicitly merged; verified fresh linking preserves grants',async()=>{
      const user=f.users['guest.a'];identity={sub:'synthetic-linked-subject',name:'Synthetic Linked',email:user.email,emailVerified:true};
      const anonymous=await start('google');assert.equal((await finish('google',anonymous)).headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
      const login=await call('/api/auth/sign-in/email',{body:{email:user.email,password:f.password}}),token=login.headers['set-auth-token'];assert.ok(token);
      await state.directory.catalog.grant(f.users['host.a'],{kind:'series',id:f.series.id,email:user.email});
      const before=(await state.pool.query('SELECT id FROM "user" WHERE email=$1',[user.email])).rows[0].id;
      const flow=await start('google',{link:true,token});const result=await finish('google',flow);assert.equal(result.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=success');
      const session=await bridge(jar(result,flow.cookie));assert.equal(session.status,200);
      assert.equal((await call('/api/directory/events/'+f.hiddenEvent.id,{token:session.headers['set-auth-token']})).status,200);
      const account=(await state.pool.query('SELECT "userId" FROM account WHERE "providerId"=\'google\' AND "accountId"=$1',[identity.sub])).rows[0];assert.equal(account.userId,before);
      const again=await start('google');const callback=await finish('google',again);assert.equal(callback.headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=success');
      const againSession=await bridge(jar(callback,again.cookie));assert.equal((await call('/api/directory/events/'+f.hiddenEvent.id,{token:againSession.headers['set-auth-token']})).status,200);
    });
    await t.test('linking requires verified fresh session and rejects different email/account takeover',async()=>{
      const unverified=await call('/api/auth/sign-in/email',{body:{email:f.users.unverified.email,password:f.password}});
      assert.equal((await call('/api/account/social/start',{body:{provider:'google',link:true},token:unverified.headers['set-auth-token']})).status,403);
      const login=await call('/api/auth/sign-in/email',{body:{email:f.users['guest.b'].email,password:f.password}}),token=login.headers['set-auth-token'];
      identity={sub:'wrong-link-subject',name:'Synthetic attacker',email:'other@example.invalid',emailVerified:true};
      const flow=await start('facebook',{link:true,token});assert.equal((await finish('facebook',flow)).headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');
      await state.pool.query('UPDATE session SET "createdAt"=NOW()-INTERVAL \'11 minutes\' WHERE "userId"=$1',[f.users['guest.b'].id]);
      assert.equal((await call('/api/account/social/start',{body:{provider:'google',link:true},token})).status,403);
      assert.equal((await call('/api/account/social/start',{body:{provider:'google',link:true},token:'forged'})).status,401);
    });
    await t.test('logout during pending linking prevents callback account changes',async()=>{
      const user=f.users['guest.c'];identity={sub:'revoked-link-subject',name:'Synthetic revoked',email:user.email,emailVerified:true};
      const login=await call('/api/auth/sign-in/email',{body:{email:user.email,password:f.password}}),token=login.headers['set-auth-token'];
      const flow=await start('facebook',{link:true,token});
      assert.equal((await call('/api/auth/sign-out',{body:{},token})).status,200);
      const before=exchanges;assert.equal((await finish('facebook',flow)).headers.location,env.CA_AUTH_UI_ORIGIN+'/#social=error');assert.equal(exchanges,before);
      assert.equal((await state.pool.query('SELECT 1 FROM account WHERE "accountId"=$1',[identity.sub])).rowCount,0);
    });
    await t.test('logout revokes social session and replay; no external network used',async()=>{
      assert.equal((await call('/api/auth/sign-out',{body:{},token:googleToken})).status,200);
      assert.equal((await call('/api/account/me',{token:googleToken})).status,401);
      const name=context.authCookies.sessionToken.name;
      assert.equal((await bridge(name+'='+googleToken)).status,401);
      assert.equal(externalCalls,0);
    });
    await t.test('social login attempts remain rate limited',async()=>{
      await state.pool.query('DELETE FROM "rateLimit"');
      let result;
      for(let i=0;i<10;i++){
        result=await call('/api/account/social/start',{body:{provider:'google'}});
        if(result.status===429)break;
      }
      assert.equal(result.status,429);assert.deepEqual(result.data,{code:'SOCIAL_START_FAILED'});
    });
  }finally{globalThis.fetch=originalFetch;await new Promise(resolve=>server.close(resolve));await state.pool.end();}
});
