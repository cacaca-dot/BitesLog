// src/modules/social/social.controller.js
const socialService = require('./social.service');

// ============================================
// FOLLOW
// ============================================

async function followUser(req, res) {
  try {
    const followerId = req.user.id;
    const followingId = req.params.id;

    const result = await socialService.followUser(followerId, followingId);
    res.json({
      data: result,
      message: 'Berhasil mengikuti user'
    });
  } catch (err) {
    const status = err.message.includes('tidak ditemukan') ? 404 : 400;
    res.status(status).json({
      error: { code: 'FOLLOW_ERROR', message: err.message }
    });
  }
}

async function unfollowUser(req, res) {
  try {
    const followerId = req.user.id;
    const followingId = req.params.id;

    const result = await socialService.unfollowUser(followerId, followingId);
    res.json({
      data: result,
      message: 'Berhenti mengikuti user'
    });
  } catch (err) {
    res.status(400).json({
      error: { code: 'UNFOLLOW_ERROR', message: err.message }
    });
  }
}

// ============================================
// FEED
// ============================================

async function getFeed(req, res) {
  try {
    const userId = req.user.id;
    const feed = await socialService.getActivityFeed(userId);
    
    res.json({
      data: feed,
      count: feed.length
    });
  } catch (err) {
    res.status(500).json({
      error: { code: 'FEED_ERROR', message: err.message }
    });
  }
}

// ============================================
// LIKES
// ============================================

async function toggleLike(req, res) {
  try {
    const userId = req.user.id;
    const { target_type, target_id } = req.body;

    if (!target_type || !target_id) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'target_type dan target_id wajib diisi' }
      });
    }

    const result = await socialService.toggleLike(userId, target_type, target_id);
    res.json({
      data: result,
      message: result.liked ? 'Berhasil menyukai' : 'Berhasil membatalkan like'
    });
  } catch (err) {
    res.status(400).json({
      error: { code: 'LIKE_ERROR', message: err.message }
    });
  }
}

// ============================================
// COMMENTS
// ============================================

async function addComment(req, res) {
  try {
    const userId = req.user.id;
    const { target_type, target_id, comment_text } = req.body;

    if (!target_type || !target_id || !comment_text) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'target_type, target_id, dan comment_text wajib diisi' }
      });
    }

    const comment = await socialService.addComment(userId, target_type, target_id, comment_text);
    res.status(201).json({
      data: comment,
      message: 'Komentar berhasil ditambahkan'
    });
  } catch (err) {
    res.status(400).json({
      error: { code: 'COMMENT_ERROR', message: err.message }
    });
  }
}

async function deleteComment(req, res) {
  try {
    const userId = req.user.id;
    const commentId = req.params.id;

    await socialService.removeComment(commentId, userId);
    res.json({
      message: 'Komentar berhasil dihapus'
    });
  } catch (err) {
    res.status(400).json({
      error: { code: 'DELETE_COMMENT_ERROR', message: err.message }
    });
  }
}

module.exports = {
  followUser,
  unfollowUser,
  getFeed,
  toggleLike,
  addComment,
  deleteComment
};