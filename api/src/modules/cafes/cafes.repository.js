const pool = require('../../config/db');

async function findCafes(search, category, city) {
  let query = `
    SELECT id, name, category, city, price_range, avg_rating, visit_count
    FROM cafes
    WHERE 1=1
  `;
  const params = [];
  let paramIndex = 1;

  if (search) {
    query += ` AND name ILIKE $${paramIndex}`;
    params.push(`%${search}%`);
    paramIndex++;
  }

  if (category) {
    query += ` AND category = $${paramIndex}`;
    params.push(category);
    paramIndex++;
  }

  if (city) {
    query += ` AND city = $${paramIndex}`;
    params.push(city);
    paramIndex++;
  }

  query += ` ORDER BY visit_count DESC, avg_rating DESC NULLS LAST LIMIT 50`;

  const result = await pool.query(query, params);
  return result.rows;
}

async function findCafeById(cafeId) {
  const result = await pool.query(
    `SELECT id, name, category, address, city, price_range, 
            latitude, longitude, avg_rating, visit_count,
            created_by, created_at
     FROM cafes 
     WHERE id = $1`,
    [cafeId]
  );
  return result.rows[0];
}

async function createCafe({ name, category, address, city, price_range, latitude, longitude, created_by }) {
  const result = await pool.query(
    `INSERT INTO cafes (name, category, address, city, price_range, 
                        latitude, longitude, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, name, category, address, city, price_range, 
               latitude, longitude, avg_rating, visit_count`,
    [name, category, address, city, price_range, latitude, longitude, created_by]
  );
  return result.rows[0];
}

module.exports = {
  findCafes,
  findCafeById,
  createCafe
};