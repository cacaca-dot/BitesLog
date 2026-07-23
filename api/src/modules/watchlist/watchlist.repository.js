const pool = require('../../config/db');

async function getWatchlist(userId) {
  try {
    const result = await pool.query(
      `SELECT c.id AS id, c.name, c.city, c.categories, c.price_range,
              c.avg_rating, c.image_url, w.created_at AS added_at
       FROM watchlist w
       JOIN cafes c ON c.id = w.cafe_id
       WHERE w.user_id = $1
       ORDER BY w.created_at DESC`,
      [userId]
    );
    return result.rows;
  } catch (err) {
    console.error('❌ Error di repo getWatchlist:', err.message);
    throw err;
  }
}

async function addToWatchlist(userId, cafeId) {
  const result = await pool.query(
    `INSERT INTO watchlist (user_id, cafe_id)
     VALUES ($1, $2)
     ON CONFLICT (user_id, cafe_id) DO NOTHING
     RETURNING cafe_id, created_at`,
    [userId, cafeId]
  );
  return result.rows[0];
}

async function removeFromWatchlist(userId, cafeId) {
  const result = await pool.query(
    `DELETE FROM watchlist
     WHERE user_id = $1 AND cafe_id = $2
     RETURNING cafe_id`,
    [userId, cafeId]
  );
  return result.rows[0];
}

module.exports = {
  getWatchlist,
  addToWatchlist,
  removeFromWatchlist
};
