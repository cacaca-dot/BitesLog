// src/modules/discovery/discovery.repository.js
const pool = require('../../config/db');

// ============================================
// SEARCH
// ============================================

async function searchCafes(keyword) {
  const result = await pool.query(
    `SELECT id, name, categories, city, price_range, avg_rating, image_url,
            'cafe' as type
     FROM cafes
     WHERE name ILIKE '%' || $1 || '%' OR city ILIKE '%' || $1 || '%'
     ORDER BY (CASE WHEN name ILIKE $1 || '%' THEN 0 ELSE 1 END), visit_count DESC, avg_rating DESC NULLS LAST
     LIMIT 20`,
    [keyword]
  );
  return result.rows;
}

async function searchUsers(keyword, userId) {
  const result = await pool.query(
    `SELECT id, username, full_name, bio, avatar_url,
            'user' as type,
            EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = users.id) as is_following
     FROM users
     WHERE (username ILIKE '%' || $1 || '%' OR full_name ILIKE '%' || $1 || '%') AND id != $2
     ORDER BY (CASE WHEN username ILIKE $1 || '%' OR full_name ILIKE $1 || '%' THEN 0 ELSE 1 END), created_at DESC
     LIMIT 20`,
    [keyword, userId]
  );
  return result.rows;
}

async function searchLists(keyword, userId) {
  const result = await pool.query(
    `SELECT l.id, l.title, l.description, l.is_public,
            u.username as owner_username, u.full_name,
            (SELECT COUNT(*) FROM list_items WHERE list_id = l.id) as cafe_count,
            COALESCE((
              SELECT array_agg(c.image_url)
              FROM (
                SELECT c2.image_url 
                FROM list_items li 
                JOIN cafes c2 ON li.cafe_id = c2.id 
                WHERE li.list_id = l.id 
                ORDER BY li.position ASC
                LIMIT 4
              ) c
            ), '{}'::text[]) as covers,
            'list' as type
     FROM lists l
     JOIN users u ON u.id = l.user_id
     WHERE (l.is_public = true OR l.user_id = $2) AND (l.title ILIKE '%' || $1 || '%')
     ORDER BY (CASE WHEN l.title ILIKE $1 || '%' THEN 0 ELSE 1 END), l.created_at DESC
     LIMIT 20`,
    [keyword, userId]
  );
  return result.rows;
}

// ============================================
// DISCOVER (Popular & Rekomendasi)
// ============================================

async function getPopularCafes(limit = 10) {
  const result = await pool.query(
    `SELECT id, name, categories, city, price_range, avg_rating, visit_count
     FROM cafes
     ORDER BY visit_count DESC, avg_rating DESC NULLS LAST
     LIMIT $1`,
    [limit]
  );
  return result.rows;
}

async function getTopRatedCafes(limit = 10) {
  const result = await pool.query(
    `SELECT id, name, categories, city, price_range, avg_rating, visit_count
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
    `SELECT id, name, categories, city, price_range, avg_rating, visit_count
     FROM cafes
     WHERE EXISTS (SELECT 1 FROM unnest(categories) cat WHERE cat ILIKE $1)
     ORDER BY avg_rating DESC NULLS LAST, visit_count DESC
     LIMIT $2`,
    [`%${category}%`, limit]
  );
  return result.rows;
}

async function getUserFavoriteCategories(userId) {
  const result = await pool.query(
    `SELECT unnest(c.categories) as category, COUNT(*) as count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1 AND array_length(c.categories, 1) > 0
     GROUP BY unnest(c.categories)
     ORDER BY count DESC
     LIMIT 3`,
    [userId]
  );
  return result.rows;
}

async function getCafesVisitedByFollowing(userId, limit = 10) {
  const result = await pool.query(
    `SELECT DISTINCT c.id, c.name, c.categories, c.city, c.price_range, c.avg_rating, c.visit_count,
            COUNT(*) as visit_count_by_following
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id IN (
       SELECT following_id FROM follows WHERE follower_id = $1
     )
     GROUP BY c.id, c.name, c.categories, c.city, c.price_range, c.avg_rating, c.visit_count
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