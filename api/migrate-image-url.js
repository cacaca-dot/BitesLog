require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runMigration() {
  try {
    console.log('Menjalankan migrasi: menambahkan image_url ke tabel cafes...');
    await pool.query(`ALTER TABLE cafes ADD COLUMN IF NOT EXISTS image_url TEXT;`);
    console.log('✅ Migrasi berhasil.');
  } catch (err) {
    console.error('❌ Migrasi gagal:', err);
  } finally {
    pool.end();
  }
}

runMigration();
