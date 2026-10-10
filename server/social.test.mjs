import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign,verify} from 'node:crypto';
import {socialConfiguration,secureAppleProvider} from './social.mjs';

const secret='synthetic-auth-key-'.repeat(4);
const ec=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
export const fixtureSocialEnv={CA_SOCIAL_PROVIDERS:'google,apple,facebook',BETTER_AUTH_SECRET:secret,
  CA_AUTH_API_ORIGIN:'https://auth.example.invalid',CA_AUTH_UI_ORIGIN:'https://app.example.invalid',
  GOOGLE_CLIENT_ID:'synthetic-google',GOOGLE_CLIENT_SECRET:'synthetic-google-secret',
  APPLE_CLIENT_ID:'invalid.example.synthetic',APPLE_TEAM_ID:'SYNTHETIC1',APPLE_KEY_ID:'SYNTHETIC2',
  APPLE_PRIVATE_KEY:ec.privateKey.export({type:'pkcs8',format:'pem'}),
  FACEBOOK_CLIENT_ID:'synthetic-facebook',FACEBOOK_CLIENT_SECRET:'synthetic-facebook-secret'};

test('social configuration is opt-in and deterministic Google → Apple → Facebook',()=>{
  assert.deepEqual(socialConfiguration({}).providers,[]);
  const config=socialConfiguration({...fixtureSocialEnv,CA_SOCIAL_PROVIDERS:'facebook,apple,google'});
  assert.deepEqual(config.providers,['google','apple','facebook']);
  assert.equal(config.socialProviders.google.accessType,'online');
  assert.equal(config.socialProviders.google.includeGrantedScopes,false);
});
test('missing credentials, invalid origins and Apple HTTP are rejected without secrets',()=>{
  for(const env of [
    {...fixtureSocialEnv,BETTER_AUTH_SECRET:''}, {...fixtureSocialEnv,GOOGLE_CLIENT_SECRET:''},
    {...fixtureSocialEnv,CA_SOCIAL_PROVIDERS:'google,google'}, {...fixtureSocialEnv,CA_SOCIAL_PROVIDERS:'evil'},
    {...fixtureSocialEnv,CA_AUTH_API_ORIGIN:'https://user:private@example.invalid'},
    {...fixtureSocialEnv,CA_AUTH_UI_ORIGIN:'https://app.example.invalid/path'},
    {...fixtureSocialEnv,CA_AUTH_API_ORIGIN:'http://127.0.0.1:8000'},
    {...fixtureSocialEnv,APPLE_PRIVATE_KEY:'synthetic-invalid-key'},
    {...fixtureSocialEnv,APPLE_TEAM_ID:'x'},
  ]) assert.throws(()=>socialConfiguration(env),error=>!error.message.includes('private')&&!error.message.includes('synthetic-'));
});
test('Apple client assertion uses ES256, correct audience/service and bounded expiry',()=>{
  const token=socialConfiguration(fixtureSocialEnv).socialProviders.apple.clientSecret;
  const [header,payload,signature]=token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header,'base64url')),{alg:'ES256',kid:'SYNTHETIC2'});
  const claims=JSON.parse(Buffer.from(payload,'base64url'));
  assert.equal(claims.iss,'SYNTHETIC1');assert.equal(claims.sub,'invalid.example.synthetic');
  assert.equal(claims.aud,'https://appleid.apple.com');assert.equal(claims.exp-claims.iat,180*86400);
  assert.equal(verify('sha256',Buffer.from(header+'.'+payload),{key:ec.publicKey,dsaEncoding:'ieee-p1363'},Buffer.from(signature,'base64url')),true);
});
test('Apple exchanged identity requires valid signature, issuer, audience, expiry and nonce',async()=>{
  const rsa=generateKeyPairSync('rsa',{modulusLength:2048});
  const nonce='synthetic-nonce';let passed=0,options;
  const provider={idToken:{jwks:async()=>rsa.publicKey,issuer:'https://appleid.apple.com',audience:'synthetic-service',maxTokenAge:'1h',nonceComparison:'exact'},
    createAuthorizationURL:async value=>{options=value;return new URL('https://appleid.apple.com/auth/authorize');},
    getUserInfo:async()=>{passed++;return {user:{email:'apple@example.invalid'}};}};
  secureAppleProvider(provider);
  const authorization=await provider.createAuthorizationURL({idTokenNonce:nonce});assert.equal(authorization.searchParams.get('nonce'),nonce);
  assert.equal(options.idTokenNonce,nonce);
  const jwt=(overrides={},key=rsa.privateKey)=>{
    const now=Math.floor(Date.now()/1000),b64=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
    const unsigned=b64({alg:'RS256',kid:'synthetic'})+'.'+b64({iss:'https://appleid.apple.com',aud:'synthetic-service',iat:now,exp:now+300,nonce,sub:'synthetic-subject',...overrides});
    return unsigned+'.'+sign('sha256',Buffer.from(unsigned),key).toString('base64url');
  };
  assert.ok(await provider.getUserInfo({idToken:jwt(),expectedIdTokenNonce:nonce}));
  for(const idToken of [jwt({iss:'https://attacker.example.invalid'}),jwt({aud:'other-service'}),jwt({exp:1}),jwt({nonce:'wrong'}),jwt({},ec.privateKey)]) {
    assert.equal(await provider.getUserInfo({idToken,expectedIdTokenNonce:nonce}),null);
  }
  assert.equal(await provider.getUserInfo({idToken:jwt()}),null);assert.equal(passed,1);
});
