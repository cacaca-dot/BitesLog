// src/modules/profile/profile.repository.js
const pool = require('../../config/db');

// ============================================
// PROFILE
// ============================================

async function getUserProfile(userId) {
  const result = await pool.query(
    `SELECT id, username, full_name, email, bio, avatar_url, is_private, created_at
     FROM users WHERE id = $1`,
    [userId]
  );
  return result.rows[0];
}

async function getUserStats(userId) {
  const result = await pool.query(
    `SELECT 
       (SELECT COUNT(*) FROM visits WHERE user_id = $1) as total_visits,
       (SELECT COUNT(DISTINCT cafe_id) FROM visits WHERE user_id = $1) as total_cafes,
       (SELECT COUNT(*) FROM lists WHERE user_id = $1) as total_lists,
       (SELECT COUNT(*) FROM reviews WHERE user_id = $1) as total_reviews,
       (SELECT COUNT(*) FROM follows WHERE following_id = $1) as followers,
       (SELECT COUNT(*) FROM follows WHERE follower_id = $1) as following,
       (SELECT COALESCE(AVG(rating), 0) FROM visits WHERE user_id = $1 AND rating IS NOT NULL) as avg_rating
     FROM users WHERE id = $1`,
    [userId]
  );
  return result.rows[0];
}

async function getFavoriteCafes(userId, limit = 4) {
  const result = await pool.query(
    `SELECT c.id, c.name, c.category, c.city, c.price_range, c.avg_rating,
            COUNT(v.id) as visit_count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     GROUP BY c.id, c.name, c.category, c.city, c.price_range, c.avg_rating
     ORDER BY visit_count DESC, c.avg_rating DESC NULLS LAST
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

// ============================================
// TASTE TAG
// ============================================

async function getUserTasteTag(userId) {
  // Cek total visits
  const visitCount = await pool.query(
    `SELECT COUNT(*) FROM visits WHERE user_id = $1`,
    [userId]
  );
  
  const totalVisits = parseInt(visitCount.rows[0].count);
  
  // Jika kurang dari 3 visits, beri default
  if (totalVisits < 3) {
    return { tag: 'New Cafe-Hopper', emoji: '🌱' };
  }

  // Cari kategori favorit
  const categoryResult = await pool.query(
    `SELECT c.category, COUNT(*) as count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1 AND c.category IS NOT NULL
     GROUP BY c.category
     ORDER BY count DESC
     LIMIT 1`,
    [userId]
  );

  // Cari minuman favorit
  const drinkResult = await pool.query(
    `SELECT favorite_drink, COUNT(*) as count
     FROM visits
     WHERE user_id = $1 AND favorite_drink IS NOT NULL
     GROUP BY favorite_drink
     ORDER BY count DESC
     LIMIT 1`,
    [userId]
  );

  // Mapping tag
  const tagMap = {
    'Matcha': { tag: 'Matcha Lover', emoji: '🍵' },
    'Coffee': { tag: 'Coffee Enthusiast', emoji: '☕' },
    'Tea': { tag: 'Tea Lover', emoji: '🫖' },
    'Dessert': { tag: 'Dessert Hunter', emoji: '🍰' },
    'Specialty': { tag: 'Specialty Coffee Geek', emoji: '🔬' }
  };

  let tag = 'Cafe Hopper';
  let emoji = '☕';

  const topCategory = categoryResult.rows[0]?.category;
  const topDrink = drinkResult.rows[0]?.favorite_drink;

  // Prioritaskan kategori
  if (topCategory && tagMap[topCategory]) {
    tag = tagMap[topCategory].tag;
    emoji = tagMap[topCategory].emoji;
  } else if (topDrink) {
    // Cek berdasarkan minuman
    if (topDrink.toLowerCase().includes('matcha')) {
      tag = 'Matcha Lover';
      emoji = '🍵';
    } else if (topDrink.toLowerCase().includes('coffee') || topDrink.toLowerCase().includes('latte')) {
      tag = 'Coffee Connoisseur';
      emoji = '☕';
    }
  }

  return { tag, emoji, totalVisits };
}

module.exports = {
  getUserProfile,
  getUserStats,
  getFavoriteCafes,
  getUserTasteTag
};