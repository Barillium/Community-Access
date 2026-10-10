import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAccountMailer, createMailBudget } from './account_mail.mjs';

const env = { RESEND_API_KEY: 're_synthetic_fixture_only' };
const link = (kind = 'verify') => ({ kind, email: 'synthetic@example.test',
  url: `http://127.0.0.1:8300/#${kind}=${'a'.repeat(64)}&email=synthetic%40example.test` });

test('Resend templates and idempotency use fixed recipient and server endpoint', async () => {
  const sent = [];
  const send = createAccountMailer({ env, fetchImpl: async (url, options) => {
    sent.push({ url, options }); return Response.json({ id: 'synthetic-message' });
  } });
  await send(link()); await send(link()); await send(link('reset'));
  assert.equal(sent[0].url, 'https://api.resend.com/emails');
  assert.equal(sent[0].options.redirect, 'error');
  assert.equal(sent[0].options.headers['Idempotency-Key'], sent[1].options.headers['Idempotency-Key']);
  assert.notEqual(sent[0].options.headers['Idempotency-Key'], sent[2].options.headers['Idempotency-Key']);
  const body = JSON.parse(sent[0].options.body);
  assert.equal(body.from, 'Community Access <info@communityaccess.de>');
  assert.deepEqual(body.to, ['synthetic@example.test']);
  assert.ok(body.html.includes('&amp;email='));
  assert.ok(body.text.includes(link().url));
  assert.ok(!sent[0].options.headers['Idempotency-Key'].includes('synthetic@'));
  assert.ok(sent[0].options.signal instanceof AbortSignal);
});

test('invalid addresses, kinds, origins and link contents never reach the provider', async () => {
  let calls = 0;
  const send = createAccountMailer({ env, fetchImpl: async () => { calls++; } });
  for (const invalid of [
    { ...link(), kind: 'newsletter' }, { ...link(), email: 'a@example.invalid' },
    { ...link(), email: 'a\r\nb@example.test' },
    { ...link(), url: link().url.replace('127.0.0.1', 'example.test') },
    { ...link(), url: link().url.replace('/#', '/?tracking=yes#') },
    { ...link(), url: link().url.replace('synthetic%40', 'different%40') },
    { ...link(), url: link().url + '&extra=yes' },
  ]) await assert.rejects(send(invalid));
  assert.equal(calls, 0);
});

test('explicit HTTPS UI origin supports recovery but rejects different destinations',async()=>{
  const sent=[];
  const send=createAccountMailer({env:{...env,CA_AUTH_UI_ORIGIN:'https://app.example.invalid'},fetchImpl:async(_,options)=>{
    sent.push(JSON.parse(options.body));return Response.json({id:'synthetic-message'});
  }});
  await send({...link(),url:link().url.replace('http://127.0.0.1:8300','https://app.example.invalid')});
  assert.equal(sent.length,1);assert.ok(sent[0].text.includes('https://app.example.invalid'));
  await assert.rejects(send(link()));assert.equal(sent.length,1);
});

test('provider and transport failures are redacted and never reported as success', async () => {
  for (const fetchImpl of [
    async () => { throw new Error('PRIVATE_KEY ADDRESS TOKEN'); },
    async () => Response.json({ error: 'PRIVATE_KEY ADDRESS TOKEN' }, { status: 429 }),
    async () => Response.json({ unexpected: true }),
  ]) {
    const send = createAccountMailer({ env, fetchImpl });
    await assert.rejects(send(link()), (error) => {
      assert.equal(error.message, 'Account email delivery unavailable.');
      assert.equal(error.cause, undefined); return true;
    });
  }
  assert.throws(() => createAccountMailer({ env: {} }), /server-side Resend key/);
});

test('rolling global mail budget reserves before concurrent sends and bounds all recipients',async()=>{
  let time=1000,calls=0;
  const reserve=createMailBudget({now:()=>time,maxPerHour:2,maxPerDay:3});
  const send=createAccountMailer({env,reserve,fetchImpl:async()=>{
    calls++;return Response.json({id:'synthetic-message'});
  }});
  const message=i=>({kind:i%2?'verify':'reset',email:`fixture-${i}@example.test`,
    url:`http://127.0.0.1:8300/#${i%2?'verify':'reset'}=${'a'.repeat(64)}&email=fixture-${i}%40example.test`});
  const results=await Promise.allSettled(Array.from({length:10},(_,i)=>send(message(i))));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,2);assert.equal(calls,2);
  for(const r of results.filter(r=>r.status==='rejected')){
    assert.equal(r.reason.code,'MAIL_BUDGET_EXHAUSTED');
    assert.equal(r.reason.message,'Account email delivery unavailable.');
    assert.equal(r.reason.cause,undefined);
  }
  time+=3600000;
  await send(message(10));assert.equal(calls,3);
  await assert.rejects(send(message(11)),{code:'MAIL_BUDGET_EXHAUSTED'});
  time+=86400000;
  await send(message(12));assert.equal(calls,4);
});

test('transport failures consume budget; invalid messages consume none',async()=>{
  let calls=0;
  const send=createAccountMailer({env,reserve:createMailBudget({maxPerHour:1,maxPerDay:1}),
    fetchImpl:async()=>{calls++;throw new Error('private provider details');}});
  await assert.rejects(send({...link(),kind:'invalid'}));assert.equal(calls,0);
  await assert.rejects(send(link()));assert.equal(calls,1);
  await assert.rejects(send(link('reset')),{code:'MAIL_BUDGET_EXHAUSTED'});
  assert.equal(calls,1);
});
