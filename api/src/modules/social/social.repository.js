// src/modules/social/social.repository.js
const pool = require('../../config/db');

// ============================================
// FOLLOW
// ============================================

async function createFollow(followerId, followingId) {
  const result = await pool.query(
    `INSERT INTO follows (follower_id, following_id)
     VALUES ($1, $2)
     RETURNING *`,
    [followerId, followingId]
  );
  return result.rows[0];
}

async function deleteFollow(followerId, followingId) {
  const result = await pool.query(
    `DELETE FROM follows 
     WHERE follower_id = $1 AND following_id = $2
     RETURNING *`,
    [followerId, followingId]
  );
  return result.rows[0];
}

async function isFollowing(followerId, followingId) {
  const result = await pool.query(
    `SELECT 1 FROM follows 
     WHERE follower_id = $1 AND following_id = $2`,
    [followerId, followingId]
  );
  return result.rows.length > 0;
}

async function getFollowersCount(userId) {
  const result = await pool.query(
    `SELECT COUNT(*) FROM follows WHERE following_id = $1`,
    [userId]
  );
  return parseInt(result.rows[0].count);
}

async function getFollowingCount(userId) {
  const result = await pool.query(
    `SELECT COUNT(*) FROM follows WHERE follower_id = $1`,
    [userId]
  );
  return parseInt(result.rows[0].count);
}

async function getFollowers(userId) {
  const result = await pool.query(
    `SELECT u.id, u.username, u.full_name, u.avatar_url, u.bio
     FROM follows f
     JOIN users u ON u.id = f.follower_id
     WHERE f.following_id = $1
     ORDER BY f.created_at DESC`,
    [userId]
  );
  return result.rows;
}

async function getFollowing(userId) {
  const result = await pool.query(
    `SELECT u.id, u.username, u.full_name, u.avatar_url, u.bio
     FROM follows f
     JOIN users u ON u.id = f.following_id
     WHERE f.follower_id = $1
     ORDER BY f.created_at DESC`,
    [userId]
  );
  return result.rows;
}

// ============================================
// FEED
// ============================================

async function getFeed(userId, limit = 20) {
  const result = await pool.query(
    `WITH followed_visits AS (
       SELECT v.*,
         ROW_NUMBER() OVER (PARTITION BY v.user_id ORDER BY v.created_at DESC) AS user_rank
       FROM visits v
       JOIN follows f ON f.following_id = v.user_id
       WHERE f.follower_id = $1
     ),
     feed_visits AS (
       SELECT * FROM followed_visits WHERE user_rank <= 10
       UNION ALL
       SELECT v.*, 0 AS user_rank FROM visits v WHERE v.user_id = $1
     )
     SELECT 
       fv.id as visit_id,
       fv.visit_date,
       fv.rating,
       fv.review,
       fv.favorite_drink,
       fv.photo_path,
       fv.created_at,
       u.id as user_id,
       u.username,
       u.full_name,
       u.avatar_url,
       c.id as cafe_id,
       c.name as cafe_name,
       c.city as cafe_city,
       (
         SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
         FROM visit_photos vp
         WHERE vp.visit_id = fv.id
       ) as photos,
       (SELECT COUNT(*) FROM likes WHERE target_type = 'review' AND target_id = fv.id) as like_count,
       (SELECT COUNT(*) FROM comments WHERE target_type = 'review' AND target_id = fv.id) as comment_count,
       EXISTS(SELECT 1 FROM likes WHERE target_type = 'review' AND target_id = fv.id AND user_id = $1) as is_liked
     FROM feed_visits fv
     JOIN users u ON u.id = fv.user_id
     JOIN cafes c ON c.id = fv.cafe_id
     ORDER BY fv.created_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

async function getPopularFeed(userId, limit = 20) {
  const result = await pool.query(
    `SELECT 
       v.id as visit_id,
       v.visit_date,
       v.rating,
       v.review,
       v.favorite_drink,
       v.photo_path,
       v.created_at,
       u.id as user_id,
       u.username,
       u.full_name,
       u.avatar_url,
       c.id as cafe_id,
       c.name as cafe_name,
       c.city as cafe_city,
       (
         SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
         FROM visit_photos vp
         WHERE vp.visit_id = v.id
       ) as photos,
       (SELECT COUNT(*) FROM likes WHERE target_type = 'review' AND target_id = v.id) as like_count,
       (SELECT COUNT(*) FROM comments WHERE target_type = 'review' AND target_id = v.id) as comment_count,
       EXISTS(SELECT 1 FROM likes WHERE target_type = 'review' AND target_id = v.id AND user_id = $1) as is_liked
     FROM visits v
     JOIN users u ON u.id = v.user_id
     JOIN cafes c ON c.id = v.cafe_id
     ORDER BY v.created_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

// ============================================
// LIKES
// ============================================

async function createLike(userId, targetType, targetId) {
  const result = await pool.query(
    `INSERT INTO likes (user_id, target_type, target_id)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [userId, targetType, targetId]
  );
  return result.rows[0];
}

async function deleteLike(userId, targetType, targetId) {
  const result = await pool.query(
    `DELETE FROM likes 
     WHERE user_id = $1 AND target_type = $2 AND target_id = $3
     RETURNING *`,
    [userId, targetType, targetId]
  );
  return result.rows[0];
}

async function isLiked(userId, targetType, targetId) {
  const result = await pool.query(
    `SELECT 1 FROM likes 
     WHERE user_id = $1 AND target_type = $2 AND target_id = $3`,
    [userId, targetType, targetId]
  );
  return result.rows.length > 0;
}

async function getLikeCount(targetType, targetId) {
  const result = await pool.query(
    `SELECT COUNT(*) FROM likes WHERE target_type = $1 AND target_id = $2`,
    [targetType, targetId]
  );
  return parseInt(result.rows[0].count);
}

// ============================================
// COMMENTS
// ============================================

async function createComment(userId, targetType, targetId, commentText, parentCommentId = null) {
  const result = await pool.query(
    `INSERT INTO comments (user_id, target_type, target_id, comment_text, parent_comment_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, user_id, target_type, target_id, comment_text, parent_comment_id, created_at`,
    [userId, targetType, targetId, commentText, parentCommentId]
  );
  return result.rows[0];
}

async function getCommentById(commentId) {
  const result = await pool.query(
    `SELECT * FROM comments WHERE id = $1`,
    [commentId]
  );
  return result.rows[0];
}

async function deleteComment(commentId, userId) {
  const result = await pool.query(
    `DELETE FROM comments 
     WHERE id = $1 AND user_id = $2
     RETURNING *`,
    [commentId, userId]
  );
  return result.rows[0];
}

async function getComments(targetType, targetId, limit = 20) {
  const result = await pool.query(
    `SELECT c.id, c.comment_text, c.created_at, c.parent_comment_id,
            u.id as user_id, u.username, u.full_name, u.avatar_url
     FROM comments c
     JOIN users u ON u.id = c.user_id
     WHERE c.target_type = $1 AND c.target_id = $2
     ORDER BY c.created_at ASC
     LIMIT $3`,
    [targetType, targetId, limit]
  );
  return result.rows;
}

async function getCommentCount(targetType, targetId) {
  const result = await pool.query(
    `SELECT COUNT(*) FROM comments WHERE target_type = $1 AND target_id = $2`,
    [targetType, targetId]
  );
  return parseInt(result.rows[0].count);
}

// ============================================
// USER PROFILE (untuk social)
// ============================================

async function getUserById(userId) {
  const result = await pool.query(
    `SELECT id, username, full_name, email, bio, avatar_url, is_private, created_at
     FROM users WHERE id = $1`,
    [userId]
  );
  return result.rows[0];
}

module.exports = {
  // Follow
  createFollow,
  deleteFollow,
  isFollowing,
  getFollowersCount,
  getFollowingCount,
  getFollowers,
  getFollowing,
  // Feed
  getFeed,
  getPopularFeed,
  // Likes
  createLike,
  deleteLike,
  isLiked,
  getLikeCount,
  // Comments
  createComment,
  getCommentById,
  deleteComment,
  getComments,
  getCommentCount,
  // User
  getUserById
};