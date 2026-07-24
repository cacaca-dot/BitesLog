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
    const { target_type, target_id, comment_text, parent_comment_id } = req.body;

    // Jika parent_comment_id ada, kita abaikan validasi target_type dan target_id 
    // karena mereka akan diwariskan dari induk.
    if (!parent_comment_id) {
      if (!target_type || !target_id || !comment_text) {
        return res.status(400).json({
          error: { code: 'INVALID_REQUEST', message: 'target_type, target_id, dan comment_text wajib diisi' }
        });
      }
      if (!['review', 'list'].includes(target_type)) {
        return res.status(400).json({
          error: { code: 'INVALID_REQUEST', message: 'target_type harus review atau list' }
        });
      }
    } else if (!comment_text) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'comment_text wajib diisi' }
      });
    }

    const comment = await socialService.addComment(userId, target_type, target_id, comment_text, parent_comment_id);
    res.status(201).json({
      data: comment,
      message: 'Komentar berhasil ditambahkan'
    });
  } catch (err) {
    const status = err.status === 403 ? 403 : 400;
    res.status(status).json({
      error: { code: status === 403 ? 'FORBIDDEN' : 'COMMENT_ERROR', message: err.message }
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
    const status = err.status === 403 ? 403 : 400;
    res.status(status).json({
      error: { code: status === 403 ? 'FORBIDDEN' : 'DELETE_COMMENT_ERROR', message: err.message }
    });
  }
}

async function getComments(req, res) {
  try {
    const userId = req.user.id;
    const { target_type, target_id } = req.query;
    if (!target_type || !target_id) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'target_type dan target_id wajib diisi' }
      });
    }

    const comments = await socialService.getComments(target_type, target_id, userId);
    res.json({
      data: comments,
      count: comments.length
    });
  } catch (err) {
    const status = err.status === 403 ? 403 : 400;
    res.status(status).json({
      error: { code: status === 403 ? 'FORBIDDEN' : 'GET_COMMENTS_ERROR', message: err.message }
    });
  }
}

module.exports = {
  followUser,
  unfollowUser,
  getFeed,
  toggleLike,
  addComment,
  deleteComment,
  getComments
};