import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
export async function migrateAccess(pool) {
  const db = await pool.connect();
  try {
    await db.query('BEGIN');
    await db.query('SELECT pg_advisory_xact_lock(73100525)');
    await db.query('CREATE TABLE IF NOT EXISTS ca_access_migration (version text PRIMARY KEY,digest text NOT NULL)');
    for (const version of ['0001-access-flow','0002-ticketing','0003-private-access','0004-native-categories','0005-community-governance','0006-publisher-permissions','0007-organizer-members','0008-organizer-link-issuers','0009-legal-ticketing']) {
      const sql = await readFile(new URL(`./migrations/${version}.sql`, import.meta.url), 'utf8');
      const digest = createHash('sha256').update(sql).digest('hex');
      const row = (await db.query('SELECT digest FROM ca_access_migration WHERE version=$1', [version])).rows[0];
      if (row && row.digest !== digest) throw new Error('Applied access migration changed.');
      if (!row) {
        await db.query(sql);
        await db.query('INSERT INTO ca_access_migration VALUES($1,$2)', [version, digest]);
      }
    }
    await db.query('COMMIT');
  } catch (error) { await db.query('ROLLBACK'); throw error; }
  finally { db.release(); }
}
