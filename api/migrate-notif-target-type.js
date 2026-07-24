require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrateNotifTargetType() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Idempotent: only updates rows that still have 'visit'
    const result = await client.query(
      `UPDATE notifications SET target_type = 'review' WHERE target_type = 'visit'`
    );

    await client.query('COMMIT');
    console.log(`✅ Migrated ${result.rowCount} notification rows: target_type 'visit' → 'review'`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    pool.end();
  }
}

migrateNotifTargetType();
