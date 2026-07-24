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
    `SELECT c.id, c.name, c.categories, c.city, c.price_range, c.avg_rating,
            COUNT(v.id) as visit_count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     GROUP BY c.id, c.name, c.categories, c.city, c.price_range, c.avg_rating
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
    return { tag: 'Belum ada taste tag', emoji: '🌱' };
  }

  // Cari kategori favorit
  const categoryResult = await pool.query(
    `SELECT unnest(c.categories) as category, COUNT(*) as count
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1 AND array_length(c.categories, 1) > 0
     GROUP BY unnest(c.categories)
     ORDER BY count DESC, category ASC
     LIMIT 1`,
    [userId]
  );

  // Cari minuman favorit
  const drinkResult = await pool.query(
    `SELECT favorite_drink, COUNT(*) as count
     FROM visits
     WHERE user_id = $1 AND favorite_drink IS NOT NULL AND favorite_drink <> ''
     GROUP BY favorite_drink
     ORDER BY count DESC
     LIMIT 1`,
    [userId]
  );

  // T1 FIX: tagMap pakai nama kategori bahasa Indonesia sesuai data DB
  // Kategori valid: 'Kopi','Non-Kopi','Dessert','Roti','Kue','Makanan Berat','Brunch','Lainnya'
  const tagMap = {
    'Kopi':          { tag: 'Coffee Lover',        emoji: '☕' },
    'Non-Kopi':      { tag: 'Non-Coffee Explorer', emoji: '🧃' },
    'Dessert':       { tag: 'Dessert Hunter',       emoji: '🍰' },
    'Roti':          { tag: 'Pastry Lover',         emoji: '🥐' },
    'Kue':           { tag: 'Sweet Tooth',          emoji: '🍮' },
    'Makanan Berat': { tag: 'Food & Cafe Hopper',   emoji: '🍽️' },
    'Brunch':        { tag: 'Brunch Enthusiast',    emoji: '🥞' },
    'Lainnya':       { tag: 'Cafe Explorer',        emoji: '🗺️' },
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
    // T2 FIX: cek minuman dengan keyword bahasa Indonesia & Inggris
    const drink = topDrink.toLowerCase();
    if (drink.includes('matcha')) {
      tag = 'Matcha Lover';
      emoji = '🍵';
    } else if (
      drink.includes('kopi') ||
      drink.includes('coffee') ||
      drink.includes('latte') ||
      drink.includes('espresso') ||
      drink.includes('americano') ||
      drink.includes('cappuccino') ||
      drink.includes('long black')
    ) {
      tag = 'Coffee Connoisseur';
      emoji = '☕';
    } else if (
      drink.includes('teh') ||
      drink.includes('tea') ||
      drink.includes('chai')
    ) {
      tag = 'Tea Lover';
      emoji = '🫖';
    } else if (
      drink.includes('susu') ||
      drink.includes('milk') ||
      drink.includes('coklat') ||
      drink.includes('chocolate')
    ) {
      tag = 'Milk Bar Fan';
      emoji = '🥛';
    }
  }

  return { tag, emoji, totalVisits };
}

// ============================================
// DIARY (S-11)
// ============================================

async function getMyVisits(userId) {
  const result = await pool.query(
    `SELECT 
       v.id as visit_id,
       v.visit_date,
       v.rating,
       v.favorite_drink,
       v.photo_path,
       c.name as cafe_name,
       c.city as cafe_city,
       c.image_url as cafe_image
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     ORDER BY v.visit_date DESC, v.created_at DESC`,
    [userId]
  );
  return result.rows;
}

// ============================================
// S-18 PROFILE
// ============================================

async function getUserTasteProfile(userId) {
  return await getUserTasteTag(userId);
}

async function updateUserProfile(userId, data) {
  const result = await pool.query(
    `UPDATE users 
     SET 
       full_name = COALESCE($1, full_name),
       bio = COALESCE($2, bio),
       avatar_url = COALESCE($3, avatar_url),
       is_private = CASE WHEN $4::text IS NULL THEN is_private ELSE $4::boolean END,
       updated_at = NOW()
     WHERE id = $5
     RETURNING id, username, full_name, email, bio, avatar_url, is_private, created_at`,
    [
      data.full_name !== undefined ? data.full_name : null,
      data.bio !== undefined ? data.bio : null,
      data.avatar_url !== undefined ? data.avatar_url : null,
      data.is_private !== undefined ? String(data.is_private) : null,
      userId
    ]
  );
  return result.rows[0];
}

// ============================================
// S-19 FOLLOW / UNFOLLOW
// ============================================

async function checkIsFollowing(followerId, followingId) {
  const result = await pool.query(
    `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
    [followerId, followingId]
  );
  return result.rows.length > 0;
}

async function followUser(followerId, followingId) {
  // ON CONFLICT = idempotent (follow 2x jangan error)
  const result = await pool.query(
    `INSERT INTO follows (follower_id, following_id)
     VALUES ($1, $2)
     ON CONFLICT (follower_id, following_id) DO NOTHING
     RETURNING *`,
    [followerId, followingId]
  );
  return result.rows[0];
}

async function unfollowUser(followerId, followingId) {
  await pool.query(
    `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
    [followerId, followingId]
  );
}

async function getFollowersList(userId, currentUserId) {
  const result = await pool.query(
    `SELECT u.id, u.username, u.full_name, u.avatar_url,
            EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) as is_following
     FROM follows f
     JOIN users u ON u.id = f.follower_id
     WHERE f.following_id = $1
     ORDER BY f.created_at DESC`,
    [userId, currentUserId]
  );
  return result.rows;
}

async function getFollowingList(userId, currentUserId) {
  const result = await pool.query(
    `SELECT u.id, u.username, u.full_name, u.avatar_url,
            EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) as is_following
     FROM follows f
     JOIN users u ON u.id = f.following_id
     WHERE f.follower_id = $1
     ORDER BY f.created_at DESC`,
    [userId, currentUserId]
  );
  return result.rows;
}

// ============================================
// S-19 USER VISITS & LISTS (privacy-aware)
// ============================================

async function getUserVisits(userId) {
  const result = await pool.query(
    `SELECT 
       v.id as visit_id,
       v.visit_date,
       v.rating,
       v.favorite_drink,
       v.photo_path,
       c.name as cafe_name,
       c.city as cafe_city,
       c.image_url as cafe_image
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     ORDER BY v.visit_date DESC, v.created_at DESC`,
    [userId]
  );
  return result.rows;
}

async function getUserPublicLists(userId) {
  const result = await pool.query(
    `SELECT l.id, l.title, l.description, l.is_public, l.user_id, l.created_at, l.updated_at,
            (SELECT COUNT(*)::int FROM list_items li WHERE li.list_id = l.id) as cafe_count,
            COALESCE((
              SELECT array_agg(c.image_url)
              FROM (
                SELECT c2.image_url 
                FROM list_items li2 
                JOIN cafes c2 ON li2.cafe_id = c2.id 
                WHERE li2.list_id = l.id 
                ORDER BY li2.position ASC 
                LIMIT 4
              ) c
            ), '{}'::text[]) AS covers
     FROM lists l
     WHERE l.user_id = $1 AND l.is_public = true
     ORDER BY l.updated_at DESC`,
    [userId]
  );
  return result.rows;
}

module.exports = {
  getUserProfile,
  getUserStats,
  getFavoriteCafes,
  getUserTasteTag,
  getMyVisits,
  getUserTasteProfile,
  updateUserProfile,
  checkIsFollowing,
  followUser,
  unfollowUser,
  getFollowersList,
  getFollowingList,
  getUserVisits,
  getUserPublicLists
};