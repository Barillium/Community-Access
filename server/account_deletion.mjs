import {DirectoryError} from './directory.mjs';

const fail = (status, code) => { throw new DirectoryError(status, code); };
const view = row => row ? {id: row.id, status: row.status, requested_at: row.requested_at} : null;

// Durable requests only. Financial/organizer data is never cascaded away here.
export function createAccountDeletion(pool, auth, {now = () => Date.now()} = {}) {
  return {
    async read(session) {
      if (!session?.user) fail(401, 'UNAUTHENTICATED');
      const row = (await pool.query('SELECT id,status,requested_at FROM ca_account_deletion_request WHERE user_id=$1', [session.user.id])).rows[0];
      return {request: view(row)};
    },
    async request(session, headers, body) {
      if (!session?.user) fail(401, 'UNAUTHENTICATED');
      if (Object.keys(body).some(k => !['confirmation','password'].includes(k)) || body.confirmation !== 'DELETE_ACCOUNT') fail(422, 'DELETION_CONFIRMATION_REQUIRED');
      const created = new Date(session.session?.createdAt).getTime();
      const fresh = Number.isFinite(created) && created <= now() && now() - created <= 300000;
      if (body.password !== undefined && body.password !== '') {
        if (typeof body.password !== 'string' || body.password.length > 72 || Buffer.byteLength(body.password) > 72) fail(422, 'INVALID_PASSWORD');
        try {
          const verified = await auth.api.verifyPassword({headers, body: {password: body.password}});
          if (verified?.status !== true) fail(403, 'REAUTHENTICATION_REQUIRED');
        } catch { fail(403, 'REAUTHENTICATION_REQUIRED'); }
      } else if (!fresh) fail(403, 'REAUTHENTICATION_REQUIRED');
      // The unique key and upsert make retries and concurrent requests idempotent.
      const row = (await pool.query(`INSERT INTO ca_account_deletion_request (user_id)
        VALUES ($1) ON CONFLICT(user_id) DO UPDATE SET user_id=EXCLUDED.user_id
        RETURNING id,status,requested_at`, [session.user.id])).rows[0];
      return {request: view(row), account_deleted: false};
    },
    async queue(session) {
      if (!session?.user) fail(401, 'UNAUTHENTICATED');
      if (!(await pool.query('SELECT 1 FROM ca_team WHERE user_id=$1', [session.user.id])).rowCount) fail(403, 'ACCESS_DENIED');
      return {items: (await pool.query('SELECT id,user_id,status,requested_at FROM ca_account_deletion_request ORDER BY requested_at LIMIT 100')).rows};
    },
  };
}
