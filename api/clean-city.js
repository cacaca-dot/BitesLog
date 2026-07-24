require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function cleanCity() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    console.log('Fetching cafes...');
    const result = await client.query('SELECT id, city, area FROM cafes');
    let updatedCount = 0;
    
    for (const row of result.rows) {
      let currentCity = row.city || '';
      let currentArea = row.area || '';
      
      let newCity = 'Bandung';
      let newArea = currentArea;
      
      // If city != 'Bandung' and area is empty, move it to area
      if (currentCity.toLowerCase() !== 'bandung' && !currentArea) {
        newArea = currentCity;
      }
      
      // Clean up area (trim and remove "Kecamatan " prefix case-insensitively)
      if (newArea) {
        newArea = newArea.trim();
        newArea = newArea.replace(/^Kecamatan\s+/i, '');
      }
      
      // Update if changed
      if (currentCity !== newCity || currentArea !== newArea) {
        await client.query(
          'UPDATE cafes SET city = $1, area = $2 WHERE id = $3',
          [newCity, newArea || null, row.id]
        );
        updatedCount++;
      }
    }
    
    await client.query('COMMIT');
    console.log(`✅ Successfully updated ${updatedCount} cafes.`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error cleaning city:', error);
  } finally {
    client.release();
    pool.end();
  }
}

cleanCity();
