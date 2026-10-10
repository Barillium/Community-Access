import {readFile} from 'node:fs/promises';
import {accountAgePolicy} from './account_age.mjs';
import {AsyncLocalStorage} from 'node:async_hooks';
import { betterAuth } from 'better-auth';
import { bearer } from 'better-auth/plugins/bearer';
import { getMigrations } from 'better-auth/db/migration';
import { dash } from '@better-auth/infra';
import { Pool } from 'pg';
import { randomBytes, createHash } from 'node:crypto';
import { statSync } from 'node:fs';
import {createTicketing} from './ticketing.mjs';
import {syntheticPretixClient} from './pretix_client.mjs';
import { createDirectory } from './directory.mjs';
import { accountEmail, createAccountMailer } from './account_mail.mjs';
import { socialConfiguration, createSocialGateway, secureAppleProvider } from './social.mjs';

export const uiOrigin = 'http://127.0.0.1:8300';
export const apiOrigin = 'http://127.0.0.1:8000';
export const dashboardOrigin = 'https://dash.better-auth.com';
export const syntheticEmail = (email) => typeof email === 'string' &&
  /^[^@\s]+@example\.invalid$/.test(email) && email.length <= 255;
const digest = (token) => createHash('sha256').update(token).digest('hex');

export async function createAuth({ env = process.env, fetchImpl } = {}) {
  const socialConfig = socialConfiguration(env);
  const {apiOrigin:authOrigin,uiOrigin:applicationOrigin} = socialConfig;
  const profile = env.CA_AUTH_PROFILE ?? 'synthetic';
  // This runtime has no approved real product/payment adapter. Fail before DB or mail access.
  if (env.NODE_ENV === 'production' && profile !== 'private-mail') throw new Error('Production product runtime is not yet implemented; use the release readiness report.');
  if (!['synthetic', 'private-mail'].includes(profile)) throw new Error('Unknown auth profile.');
  const agePolicy = accountAgePolicy(env);
  const privateMail = profile === 'private-mail';
  if (privateMail && !env.BETTER_AUTH_SECRET?.trim()) throw new Error('Stable private auth secret required.');
  const acceptsEmail = privateMail ? accountEmail : syntheticEmail;
  const deliver = privateMail ? createAccountMailer({ env, fetchImpl }) : null;
  const socket = env.CA_DATABASE_SOCKET;
  if (!socket || !/^\/(?:private\/)?tmp\/ca-auth-[^/]+$/.test(socket) ||
      (statSync(socket).mode & 0o077) !== 0) {
    throw new Error('Private local authentication database socket required.');
  }
  const dashboardEnabled = env.BETTER_AUTH_DASHBOARD_ENABLED === 'true';
  if (dashboardEnabled && !env.BETTER_AUTH_API_KEY?.trim()) {
    throw new Error('Dashboard enabled but server-side API key missing.');
  }
  const databaseUser = env.CA_DATABASE_USER ?? 'fixture_admin';
  if (!['fixture_admin','auth_app'].includes(databaseUser)) throw new Error('Unknown local database role.');
  const pool = new Pool({ host: socket, port: 55440, user: databaseUser,
    database: 'community_auth', max: 6, connectionTimeoutMillis: 3000,
    statement_timeout:10000, idle_in_transaction_session_timeout:15000 });
  if (socialConfig.socialProviders.apple) {
    socialConfig.socialProviders.apple.mapProfileToUser = async (profile) => {
      if (profile.email || typeof profile.sub !== 'string') return {};
      // Apple may omit email/name on subsequent consent. Only an already linked
      // Apple subject can supply the saved values; no guessed email or email match.
      // Better Auth verifies the exchanged ID token before accepting its account key.
      const result = await pool.query(`SELECT u.email,u.name,u."emailVerified"
        FROM account a JOIN "user" u ON u.id=a."userId"
        WHERE a."providerId"='apple' AND a."accountId"=$1`, [profile.sub]);
      const user = result.rows[0];
      return user ? {email:user.email,name:user.name,emailVerified:user.emailVerified} : {};
    };
  }
  const mailbox = [];
  const mailStatus = new AsyncLocalStorage();
  const runAuthRequest = work => mailStatus.run({failed:false,uncertain:false},async()=>{const result=await work();return {result,mailFailed:mailStatus.getStore().failed,mailUncertain:mailStatus.getStore().uncertain};});
  async function sendLink(kind, user, libraryToken) {
    if (!acceptsEmail(user.email)) throw new Error('Account address rejected.');
    const token = randomBytes(32).toString('hex');
    const mail = { kind, email: user.email,
      url: `${applicationOrigin}/#${kind}=${token}&email=${encodeURIComponent(user.email)}` };
    let connection, committing=false;
    try {
      connection = await pool.connect();
      await connection.query('BEGIN');
      await connection.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [kind + user.email]);
      await connection.query('DELETE FROM local_account_link WHERE kind=$1 AND email=$2', [kind, user.email]);
      await connection.query(`INSERT INTO local_account_link (digest, kind, email, library_token, expires_at)
        VALUES ($1,$2,$3,$4,NOW()+INTERVAL '60 minutes')`, [digest(token), kind, user.email, libraryToken]);
      // Keep the previous link valid when the bounded transport rejects the
      // replacement. Provider acceptance is not proof of actual delivery.
      if (deliver) await deliver(mail);
      committing=true;
      await connection.query('COMMIT');
    } catch (error) {
      let rollbackFailed=false;
      if(connection)try{await connection.query('ROLLBACK');}catch{rollbackFailed=true;}
      const status=mailStatus.getStore();
      if(status){if(committing||rollbackFailed)status.uncertain=true;else status.failed=true;}
      throw error;
    } finally { connection?.release(); }
    if (!deliver) {
      mailbox.push(mail);
      if (mailbox.length > 100) mailbox.shift();
    }
  }
  const options = {
    appName: privateMail ? 'Community Access' : 'Community Access · Lokaler Auth-Test',
    baseURL: authOrigin,
    secret: env.BETTER_AUTH_SECRET || randomBytes(48).toString('base64url'),
    database: pool,
    trustedOrigins: [applicationOrigin, authOrigin, ...(dashboardEnabled ? [dashboardOrigin] : []),
      ...(socialConfig.providers.includes('apple') ? ['https://appleid.apple.com'] : [])],
    socialProviders: socialConfig.socialProviders,
    account: {storeStateStrategy:'database',encryptOAuthTokens:true,accountLinking:{enabled:true,disableImplicitLinking:true,allowDifferentEmails:false}},
    ...(socialConfig.providers.length ? {advanced:{defaultCookieAttributes:{
      httpOnly:true,secure:authOrigin.startsWith('https:'),sameSite:socialConfig.providers.includes('apple')?'none':'lax',
    }}} : {}),
    telemetry: { enabled: false },
    logger: { disabled: true },
    session: { expiresIn: 60 * 60 * 8, disableSessionRefresh: true, cookieCache: { enabled: false } },
    emailAndPassword: { enabled: true, autoSignIn: false,
      onExistingUserSignUp: async ({user}) => { if(!user.emailVerified) await auth.api.sendVerificationEmail({body:{email:user.email}}); },
      minPasswordLength: 12, maxPasswordLength: 72,
      revokeSessionsOnPasswordReset: true,
      resetPasswordTokenExpiresIn: 3600,
      sendResetPassword: async ({ user, token }) => sendLink('reset', user, token) },
    emailVerification: { sendOnSignUp: true, expiresIn: 3600,
      sendVerificationEmail: async ({ user, token }) => sendLink('verify', user, token) },
    rateLimit: { enabled: true, window: 60, max: 60, storage: 'database',
      customRules: { '/request-password-reset': { window: 60, max: 10 },
        '/sign-in/email': { window: 60, max: 10 } } },
    databaseHooks: {
      // ID tokens prove the callback identity but are not needed afterwards.
      account: {
        create: {before: async account => ({data:{...account,idToken:null}})},
        update: {before: async account => ({data:account.idToken===undefined?account:{...account,idToken:null}})},
      },
      user: {
      create: { before: async (user) => {
        if (!acceptsEmail(user.email)) throw new Error('Account address rejected.');
        return { data: user };
      } },
      update: { before: async (user) => {
        if (user.email !== undefined && !acceptsEmail(user.email)) throw new Error('Account address rejected.');
        return { data: user };
      } },
    } },
    plugins: [bearer({ requireSignature: true }), ...(dashboardEnabled ? [dash({
      apiKey: env.BETTER_AUTH_API_KEY, activityTracking: { enabled: false },
    })] : [])],
  };
  const auth = betterAuth(options);
  try {
    // The socket restriction above prevents migration of any remote database.
    if(env.CA_AUTH_BOOTSTRAP!=='false') await (await getMigrations(options)).runMigrations();
    if(env.CA_AUTH_BOOTSTRAP!=='false') await pool.query(`CREATE TABLE IF NOT EXISTS local_account_link (
      digest text PRIMARY KEY, kind text NOT NULL, email text NOT NULL,
      library_token text NOT NULL, expires_at timestamptz NOT NULL,
      used boolean NOT NULL DEFAULT false, UNIQUE(kind, email))`);
    if(env.CA_AUTH_BOOTSTRAP!=='false') await pool.query(await readFile(new URL('./migrations/0010-account-deletion.sql', import.meta.url), 'utf8'));
    const context = await auth.$context;
    const appleProvider = context.socialProviders.find(provider => provider.id === 'apple');
    if (appleProvider) secureAppleProvider(appleProvider);
  } catch (error) { await pool.end(); throw error; }
  async function consumeLink(kind, email, token) {
    if (!acceptsEmail(email) || typeof token !== 'string' || !/^[0-9a-f]{64}$/.test(token)) return null;
    const result = await pool.query(`UPDATE local_account_link SET used=true
      WHERE digest=$1 AND kind=$2 AND email=$3 AND used=false AND expires_at>NOW()
      RETURNING library_token`, [digest(token), kind, email]);
    return result.rows[0]?.library_token ?? null;
  }
  const role = await pool.query(`SELECT current_user AS name, rolsuper, rolcreatedb,
    rolcreaterole, rolreplication, rolbypassrls,
    EXISTS(SELECT 1 FROM pg_auth_members WHERE member=pg_roles.oid) AS inherited
    FROM pg_roles WHERE rolname=current_user`);
  const databaseRestricted = role.rows[0]?.name === 'auth_app' &&
    ['rolsuper','rolcreatedb','rolcreaterole','rolreplication','rolbypassrls','inherited']
      .every(key => role.rows[0][key] === false);
  const directory = privateMail ? null : await createDirectory(pool,{migrate:env.CA_AUTH_BOOTSTRAP!=='false'});
  if(env.CA_TICKETING_SYNTHETIC==='true'&&(privateMail||env.NODE_ENV==='production'||!directory)) { await pool.end(); throw new Error('Synthetic ticketing cannot run in private/production mode.'); }
  const ticketing=env.CA_TICKETING_SYNTHETIC==='true'?createTicketing(pool,syntheticPretixClient(env.CA_PRETIX_ORIGIN,env.CA_PRETIX_TOKEN,{native:env.CA_NATIVE_PRETIX_TEST==='true'}),{salesEnabled:env.CA_TICKET_SALES_ENABLED!=='false',privateTicketsEnabled:env.CA_PRIVATE_TICKETS_ENABLED!=='false'}):null;
  return { ...agePolicy, privateCommunitiesEnabled:env.CA_PRIVATE_COMMUNITIES_ENABLED!=='false',ticketing, directory, auth, pool, mailbox, dashboardEnabled, consumeLink, acceptsEmail, privateMail, databaseRestricted,
    mailBudgetEnabled:!!deliver,runAuthRequest,
    apiOrigin:authOrigin,uiOrigin:applicationOrigin,social:createSocialGateway(auth,socialConfig,pool) };
}
