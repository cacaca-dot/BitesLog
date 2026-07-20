const pool = require('../../config/db');

async function findVisitsByUser(userId) {
  const result = await pool.query(
    `SELECT v.id, v.visit_date, v.rating, v.review, v.favorite_drink, 
            v.price, v.photo_path, v.notes, v.created_at,
            c.id as cafe_id, c.name as cafe_name, c.city as cafe_city
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     ORDER BY v.visit_date DESC, v.created_at DESC`,
    [userId]
  );
  return result.rows;
}

async function findVisitById(visitId) {
  const result = await pool.query(
    `SELECT v.*, 
            c.id as cafe_id, c.name as cafe_name, c.city as cafe_city,
            u.username, u.full_name, u.avatar_url
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     JOIN users u ON u.id = v.user_id
     WHERE v.id = $1`,
    [visitId]
  );
  return result.rows[0];
}

async function createVisit({ user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes }) {
  const result = await pool.query(
    `INSERT INTO visits (user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes]
  );
  return result.rows[0];
}

async function updateVisit(visitId, { visit_date, rating, review, favorite_drink, price, photo_path, notes }) {
  const result = await pool.query(
    `UPDATE visits 
     SET visit_date = COALESCE($2, visit_date),
         rating = $3,
         review = $4,
         favorite_drink = $5,
         price = $6,
         photo_path = COALESCE($7, photo_path),
         notes = $8
     WHERE id = $1
     RETURNING *`,
    [visitId, visit_date, rating, review, favorite_drink, price, photo_path, notes]
  );
  return result.rows[0];
}

async function deleteVisit(visitId) {
  const result = await pool.query(
    `DELETE FROM visits WHERE id = $1 RETURNING id`,
    [visitId]
  );
  return result.rows[0];
}

async function isVisitOwner(visitId, userId) {
  const result = await pool.query(
    `SELECT id FROM visits WHERE id = $1 AND user_id = $2`,
    [visitId, userId]
  );
  return result.rows.length > 0;
}

module.exports = {
  findVisitsByUser,
  findVisitById,
  createVisit,
  updateVisit,
  deleteVisit,
  isVisitOwner
};