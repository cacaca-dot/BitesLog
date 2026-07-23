require('dotenv').config();
const db = require('./src/config/db');

async function main() {
  try {
    console.log('Menjalankan pembersihan nama kota (City/Regency)...');
    
    // Using Postgres syntax to update cities ending with City or Regency
    const result = await db.query(`
      UPDATE cafes
      SET city = TRIM(REGEXP_REPLACE(city, '\\s+(City|Regency)$', '', 'i'))
      WHERE city ~* '\\s+(City|Regency)$'
      RETURNING id, name, city;
    `);
    
    console.log(`✅ Berhasil membersihkan ${result.rowCount} record(s).`);
    if (result.rowCount > 0) {
      console.log('Record yang diubah:', result.rows);
    }
  } catch (error) {
    console.error('❌ Gagal membersihkan nama kota:', error);
  } finally {
    process.exit(0);
  }
}

main();
