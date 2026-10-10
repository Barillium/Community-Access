import { createHash } from 'node:crypto';
import { authOrigins } from './social.mjs';

const failure = () => new Error('Account email delivery unavailable.');
const escape = (value) => value.replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
export const accountEmail = (email) => typeof email === 'string' && email.length <= 255 &&
  /^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$/.test(email) && !email.toLowerCase().endsWith('@example.invalid');

// A rolling process-wide budget bounds paid provider attempts across recipients
// and both mail types. Reserve synchronously before awaiting network I/O.
// Failed attempts count too. Restart resets this budget; provider-side spending
// controls remain necessary and must be configured by the owner.
export function createMailBudget({now=Date.now,maxPerHour=30,maxPerDay=100}={}) {
  for(const value of [maxPerHour,maxPerDay]){
    if(!Number.isSafeInteger(value)||value<1)throw new Error('Invalid mail budget.');
  }
  const attempts=[];
  return ()=>{
    const time=now();
    while(attempts.length&&attempts[0]<=time-86400000)attempts.shift();
    if(attempts.length>=maxPerDay||attempts.filter(t=>t>time-3600000).length>=maxPerHour){
      const error=failure();error.code='MAIL_BUDGET_EXHAUSTED';throw error;
    }
    attempts.push(time);
  };
}

// Created only by the explicit private runtime; tests inject a network-free transport.
export function createAccountMailer({ env, fetchImpl = fetch, reserve=createMailBudget() }) {
  const key = env.RESEND_API_KEY;
  if (typeof key !== 'string' || !/^re_[A-Za-z0-9_-]+$/.test(key)) {
    throw new Error('Private runtime requires a server-side Resend key.');
  }
  const {uiOrigin} = authOrigins(env);
  return async ({ kind, email, url }) => {
    let link;
    try { link = new URL(url); } catch { throw failure(); }
    if (!['verify', 'reset'].includes(kind) || !accountEmail(email) ||
        link.origin !== uiOrigin || link.pathname !== '/' ||
        link.search || link.username || link.password) throw failure();
    const parts = new URLSearchParams(link.hash.slice(1));
    if (parts.size !== 2 || parts.get('email') !== email ||
        !/^[0-9a-f]{64}$/.test(parts.get(kind) ?? '')) throw failure();
    const title = kind === 'verify' ? 'E-Mail-Adresse bestätigen' : 'Passwort zurücksetzen';
    const destination = uiOrigin.startsWith('https:') ? 'öffnet Community Access' : 'funktioniert auf dem Community-Access-PC';
    const text = `Community Access\n\n${title}:\n${url}\n\nDieser Link gilt 60 Minuten und ${destination}. Wenn du diese Anfrage nicht gestellt hast, ignoriere diese Nachricht.`;
    const html = `<h1>${title}</h1><p><a href="${escape(url)}">${title}</a></p><p>Dieser Link gilt 60 Minuten und ${destination}. Wenn du diese Anfrage nicht gestellt hast, ignoriere diese Nachricht.</p>`;
    // Stable for retries of this exact link; neither address nor token is a header value.
    const id = createHash('sha256').update(kind + '\0' + email + '\0' + url).digest('hex');
    reserve();
    try {
      const result = await fetchImpl('https://api.resend.com/emails', {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json',
          'Idempotency-Key': `account-${id}` },
        body: JSON.stringify({ from: 'Community Access <info@communityaccess.de>',
          to: [email], subject: `Community Access · ${title}`, text, html }),
      });
      if (!result.ok || typeof (await result.json()).id !== 'string') throw failure();
    } catch { throw failure(); } // Never attach provider errors, addresses, keys or links.
  };
}
