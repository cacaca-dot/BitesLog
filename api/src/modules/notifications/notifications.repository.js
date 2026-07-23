// src/modules/notifications/notifications.repository.js
const pool = require('../../config/db');

async function createNotification(userId, actorId, type, targetType, targetId) {
  if (userId === actorId) return null; // Guard against self-action at DB layer
  
  const result = await pool.query(
    `INSERT INTO notifications (user_id, actor_id, type, target_type, target_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, actorId, type, targetType, targetId]
  );
  return result.rows[0];
}

async function deleteNotification(userId, actorId, type, targetType, targetId) {
  let query = `DELETE FROM notifications WHERE user_id = $1 AND actor_id = $2 AND type = $3`;
  const params = [userId, actorId, type];
  
  if (targetType) {
    query += ` AND target_type = $4`;
    params.push(targetType);
  }
  if (targetId) {
    query += ` AND target_id = $5`;
    params.push(targetId);
  }
  
  const result = await pool.query(query, params);
  return result.rowCount > 0;
}

async function getUserNotifications(userId) {
  const result = await pool.query(
    `SELECT n.*, u.username, u.avatar_url, u.full_name
     FROM notifications n
     JOIN users u ON n.actor_id = u.id
     WHERE n.user_id = $1
     ORDER BY n.created_at DESC
     LIMIT 50`,
    [userId]
  );
  return result.rows;
}

async function getUnreadCount(userId) {
  const result = await pool.query(
    `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`,
    [userId]
  );
  return parseInt(result.rows[0].count);
}

async function markAllAsRead(userId) {
  const result = await pool.query(
    `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
    [userId]
  );
  return result.rowCount;
}

// Helpers untuk cari owner
async function getVisitOwner(visitId) {
  const result = await pool.query(`SELECT user_id FROM visits WHERE id = $1`, [visitId]);
  return result.rows[0]?.user_id;
}

async function getListOwner(listId) {
  const result = await pool.query(`SELECT user_id FROM lists WHERE id = $1`, [listId]);
  return result.rows[0]?.user_id;
}

async function getCommentOwner(commentId) {
  const result = await pool.query(`SELECT user_id FROM comments WHERE id = $1`, [commentId]);
  return result.rows[0]?.user_id;
}

module.exports = {
  createNotification,
  deleteNotification,
  getUserNotifications,
  getUnreadCount,
  markAllAsRead,
  getVisitOwner,
  getListOwner,
  getCommentOwner
};
