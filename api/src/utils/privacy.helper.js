const pool = require('../config/db');

/**
 * Cek apakah viewerId bisa melihat konten milik targetUserId.
 * 
 * Aturan:
 * 1. Jika viewer == target -> BISA
 * 2. Jika target tidak private -> BISA
 * 3. Jika target private, tapi viewer sudah follow -> BISA
 * 4. Selain itu -> TIDAK BISA
 */
async function canViewContent(viewerId, targetUserId) {
  if (String(viewerId) === String(targetUserId)) return true;

  // Cek apakah user target private
  const targetRes = await pool.query('SELECT is_private FROM users WHERE id = $1', [targetUserId]);
  if (targetRes.rows.length === 0) return false; // User tidak ditemukan

  const isPrivate = targetRes.rows[0].is_private;
  if (!isPrivate) return true;

  // Jika private dan belum login, pasti gak bisa lihat
  if (!viewerId) return false;

  // Jika private, cek apakah viewer follow target
  const followRes = await pool.query(
    'SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2',
    [viewerId, targetUserId]
  );
  return followRes.rows.length > 0;
}

module.exports = {
  canViewContent
};
