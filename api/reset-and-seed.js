const { Pool } = require('pg');
const bcrypt = require('bcrypt');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const CAFES_DATA = [
  ['Common Grounds', 'Setiabudi', ['Kopi', 'Brunch', 'Makanan Berat'], '$$', -6.8620, 107.5980],
  ['Saturdays Coffee', 'Setiabudi', ['Kopi', 'Non-Kopi'], '$$', -6.8600, 107.5950],
  ['Trace Coffee & Space', 'Setiabudi', ['Kopi', 'Dessert'], '$$', -6.8580, 107.5870],
  ['Kozi Coffee', 'Dago', ['Kopi', 'Makanan Berat'], '$$', -6.8760, 107.6150],
  ['Kopi Selasar Sunaryo', 'Dago', ['Kopi', 'Non-Kopi'], '$$', -6.8530, 107.6360],
  ['Monday Coffee', 'Dago', ['Kopi', 'Brunch'], '$$', -6.8850, 107.6130],
  ['De.u Coffee', 'Dipatiukur', ['Kopi', 'Makanan Berat'], '$', -6.8880, 107.6170],
  ['Yellow Truck Coffee', 'Citarum', ['Kopi', 'Non-Kopi'], '$', -6.9010, 107.6130],
  ['Sejiwa Coffee', 'Citarum', ['Kopi', 'Brunch'], '$$', -6.9050, 107.6180],
  ['Kopikalyan', 'Lengkong', ['Kopi', 'Makanan Berat'], '$$', -6.9120, 107.6220],
  ['Blue Doors Coffee', 'Lengkong', ['Kopi', 'Dessert'], '$$', -6.9080, 107.6200],
  ['Noah\'s Barn Coffeenery', 'Riau', ['Kopi', 'Brunch'], '$$', -6.9040, 107.6250],
  ['Two Hands Full', 'Sukajadi', ['Kopi', 'Makanan Berat', 'Brunch'], '$$', -6.8880, 107.5960],
  ['Warung Kopi Purnama', 'Sumur Bandung', ['Kopi', 'Roti'], '$', -6.9200, 107.6060],
  ['Maison Wilhelmina', 'Braga', ['Kopi', 'Roti', 'Kue'], '$$', -6.9170, 107.6090],
  ['Umbira Coffee', 'Braga', ['Kopi', 'Non-Kopi'], '$$', -6.9180, 107.6095],
  ['Coffee Eiji', 'Sumur Bandung', ['Kopi', 'Dessert'], '$$', -6.9150, 107.6100],
  ['Inspira Roasters', 'Pasirkaliki', ['Kopi', 'Makanan Berat'], '$$', -6.9130, 107.5900],
  ['Noughts & Crosses', 'Pasirkaliki', ['Kopi', 'Makanan Berat', 'Brunch'], '$$', -6.9135, 107.5905],
  ['Wanderlust Coffee', 'Buahbatu', ['Kopi', 'Non-Kopi'], '$', -6.9440, 107.6350]
];

const FLAGSHIP_REVIEWS = {
  'Common Grounds': [
    { username: 'rani', rating: 4.5, review: 'Kopinya mantap, tempat cozy buat kerja', price: '$$' },
    { username: 'dimas', rating: 4.0, review: 'Brunch enak tapi rada rame weekend', price: '$$' }
  ],
  'Kopi Selasar Sunaryo': [
    { username: 'sasa', rating: 5.0, review: 'View-nya juara, wajib ke sini', price: '$$' },
    { username: 'rani', rating: 4.5, review: 'Adem, cocok buat santai', price: '$$' }
  ],
  'Kopikalyan': [
    { username: 'dimas', rating: 4.0, review: 'Menu makanan lengkap', price: '$$' },
    { username: 'sasa', rating: 4.5, review: 'Signature drink-nya enak, harga oke', price: '$$' }
  ]
};

const RANDOM_DRINKS = ['Latte', 'Americano', 'Cappuccino', 'Mocha', 'Matcha', 'Espresso'];

async function getOrCreateUser(client, email, username, fullName) {
  const res = await client.query('SELECT id FROM users WHERE email = $1 OR username = $2', [email, username]);
  if (res.rows.length > 0) return res.rows[0].id;

  const passwordHash = await bcrypt.hash('password123', 10);
  const insertRes = await client.query(
    `INSERT INTO users (email, username, full_name, password_hash, is_private) 
     VALUES ($1, $2, $3, $4, false) RETURNING id`,
    [email, username, fullName, passwordHash]
  );
  return insertRes.rows[0].id;
}

async function run() {
  const client = await pool.connect();
  try {
    console.log('🔄 Memulai Reset & Seeding...');
    await client.query('BEGIN');

    // 1. Delete katalog & turunan
    console.log('🗑️  Menghapus data lama (likes, comments, photos, watchlist, lists, visits, cafes)...');
    let res;
    res = await client.query("DELETE FROM likes WHERE target_type='review'");
    console.log(`  - Deleted ${res.rowCount} likes`);
    res = await client.query("DELETE FROM comments WHERE target_type='review'");
    console.log(`  - Deleted ${res.rowCount} comments`);
    res = await client.query("DELETE FROM visit_photos");
    console.log(`  - Deleted ${res.rowCount} visit_photos`);
    res = await client.query("DELETE FROM watchlist");
    console.log(`  - Deleted ${res.rowCount} watchlist entries`);
    res = await client.query("DELETE FROM list_items");
    console.log(`  - Deleted ${res.rowCount} list_items`);
    res = await client.query("DELETE FROM visits");
    console.log(`  - Deleted ${res.rowCount} visits`);
    res = await client.query("DELETE FROM cafes");
    console.log(`  - Deleted ${res.rowCount} cafes`);

    // 2. Buat Curator
    console.log('👤 Mencari/membuat akun curator...');
    const curatorId = await getOrCreateUser(client, 'curator@biteslog.app', 'curator', 'BitesLog Curator');
    
    // 3. Buat Reviewers
    console.log('👤 Mencari/membuat akun reviewers dummy...');
    const reviewers = {};
    reviewers['rani'] = await getOrCreateUser(client, 'rani@biteslog.app', 'rani', 'Rani Putri');
    reviewers['dimas'] = await getOrCreateUser(client, 'dimas@biteslog.app', 'dimas', 'Dimas Anggara');
    reviewers['sasa'] = await getOrCreateUser(client, 'sasa@biteslog.app', 'sasa', 'Sasa Bila');

    // 4. Seed Cafes
    console.log('☕ Seeding 20 cafe Bandung...');
    const cafeIds = {};
    for (const data of CAFES_DATA) {
      const [name, area, categories, price_range, lat, lng] = data;
      
      const insertQ = `
        INSERT INTO cafes (name, city, area, categories, price_range, latitude, longitude, created_by)
        SELECT $1::varchar, 'Bandung', $2, $3::text[], $4, $5, $6, $7
        WHERE NOT EXISTS (
          SELECT 1 FROM cafes WHERE name = $1::varchar AND city = 'Bandung'
        )
        RETURNING id
      `;
      const inserted = await client.query(insertQ, [name, area, categories, price_range, lat, lng, curatorId]);
      
      let id;
      if (inserted.rowCount > 0) {
        id = inserted.rows[0].id;
      } else {
        const exist = await client.query('SELECT id FROM cafes WHERE name = $1 AND city = \'Bandung\'', [name]);
        id = exist.rows[0].id;
      }
      cafeIds[name] = id;
    }

    // 5. Seed Visits / Reviews
    console.log('📝 Seeding review dummy untuk flagship cafes...');
    for (const [cafeName, reviews] of Object.entries(FLAGSHIP_REVIEWS)) {
      const cafeId = cafeIds[cafeName];
      if (!cafeId) {
        console.warn(`Peringatan: Cafe ${cafeName} tidak ditemukan untuk diberi review!`);
        continue;
      }

      for (const rev of reviews) {
        const reviewerId = reviewers[rev.username];
        const daysAgo = Math.floor(Math.random() * 21) + 1; // 1-21 hari lalu
        const visitDate = new Date();
        visitDate.setDate(visitDate.getDate() - daysAgo);
        
        const drink = RANDOM_DRINKS[Math.floor(Math.random() * RANDOM_DRINKS.length)];

        await client.query(
          `INSERT INTO visits (user_id, cafe_id, visit_date, rating, review, favorite_drink, price)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [reviewerId, cafeId, visitDate.toISOString().split('T')[0], rev.rating, rev.review, drink, rev.price]
        );
      }
    }

    await client.query('COMMIT');
    console.log('✅ Seeding berhasil dan di-commit!');
    
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Terjadi kesalahan, transaksi di-rollback!', err);
  } finally {
    client.release();
    pool.end();
  }
}

run();
