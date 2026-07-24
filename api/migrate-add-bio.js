require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrateAddBio() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Add bio column if it doesn't exist
    await client.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT`
    );

    await client.query('COMMIT');
    console.log(`✅ Migrated: users table now has bio column`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    pool.end();
  }
}

migrateAddBio();
