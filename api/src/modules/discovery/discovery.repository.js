// src/modules/discovery/discovery.repository.js
const pool = require('../../config/db');

// ============================================
// SEARCH
// ============================================

async function searchCafes(keyword) {
  const result = await pool.query(
    `SELECT id, name, category, city, price_range, avg_rating, visit_count,
            'cafe' as type
     FROM cafes
     WHERE name ILIKE $1 OR category ILIKE $1 OR city ILIKE $1
     ORDER BY visit_count DESC, avg_rating DESC NULLS LAST
     LIMIT 10`,
    [`%${keyword}%`]
  );
  return result.rows;
}

async function searchUsers(keyword) {
  const result = await pool.query(
    `SELECT id, username, full_name, bio, avatar_url,
            'user' as type
     FROM users
     WHERE username ILIKE $1 OR full_name ILIKE $1
     LIMIT 10`,
    [`%${keyword}%`]
  );
  return result.rows;
}

async function searchLists(keyword) {
  const result = await pool.query(
    `SELECT l.id, l.title, l.description, l.is_public,
            u.username, u.full_name,
            (SELECT COUNT(*) FROM list_items WHERE list_id = l.id) as item_count,
            'list' as type
     FROM lists l
     JOIN users u ON u.id = l.user_id
     WHERE l.is_public = true AND (l.title ILIKE $1 OR l.description ILIKE $1)
     LIMIT 10`,
    [`%${keyword}%`]
  );
  return result.rows;
}

// ============================================
// DISCOVER (Popular & Rekomendasi)
// ============================================

async function getPopularCafes(limit = 10) {
  const result = await pool.query(
    `SELECT id, name, category, city, price_range, avg_rating, visit_count
     FROM cafes
     ORDER BY visit_count DESC, avg_rating DESC NULLS LAST
     LIMIT $1`,
    [limit]
  );
  return result.rows;
}

async function getTopRatedCafes(limit = 10) {
  const result = await pool.query(
    `SELECT id, name, category, city, price_range, avg_rating, visit_count
     FROM cafes
     WHERE avg_rating IS NOT NULL
     ORDER BY avg_rating DESC, visit_count DESC
     LIMIT $1`,
    [limit]
  );
  return result.rows;
}

async function getCafesByCategory(category, userId, limit = 10) {
  const result = await pool.query(
    `SELECT id, name, category, city, price_range, avg_rating, visit_count
     FROM cafes
     WHERE category ILIKE $1
     ORDER BY avg_rating DESC NULLS LAST, visit_count DESC
     LIMIT $2`,
    [`%${category}%`, limit]
  );
  return result.rows;
}

async function getUserFavoriteCategories(userId) {
  const result = await pool.query(
    `SELECT category, COUNT(*) as count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1 AND c.category IS NOT NULL
     GROUP BY category
     ORDER BY count DESC
     LIMIT 3`,
    [userId]
  );
  return result.rows;
}

async function getCafesVisitedByFollowing(userId, limit = 10) {
  const result = await pool.query(
    `SELECT DISTINCT c.id, c.name, c.category, c.city, c.price_range, c.avg_rating, c.visit_count,
            COUNT(*) as visit_count_by_following
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id IN (
       SELECT following_id FROM follows WHERE follower_id = $1
     )
     GROUP BY c.id, c.name, c.category, c.city, c.price_range, c.avg_rating, c.visit_count
     ORDER BY visit_count_by_following DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

module.exports = {
  searchCafes,
  searchUsers,
  searchLists,
  getPopularCafes,
  getTopRatedCafes,
  getCafesByCategory,
  getUserFavoriteCategories,
  getCafesVisitedByFollowing
};