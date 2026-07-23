// src/modules/profile/profile.controller.js
const profileService = require('./profile.service');

// ============================================
// PROFILE PUBLIK
// ============================================

async function getProfile(req, res) {
  try {
    const userId = req.params.id;
    const viewerId = req.user.id;

    const profile = await profileService.getProfile(userId, viewerId);
    res.json({ data: profile });
  } catch (err) {
    const status = err.message === 'User tidak ditemukan' ? 404 : 500;
    res.status(status).json({
      error: { code: 'PROFILE_ERROR', message: err.message }
    });
  }
}

// ============================================
// STATISTIK SENDIRI
// ============================================

async function getMyStats(req, res) {
  try {
    const userId = req.user.id;
    const stats = await profileService.getMyStats(userId);
    res.json({ data: stats });
  } catch (err) {
    res.status(500).json({
      error: { code: 'STATS_ERROR', message: err.message }
    });
  }
}
// ============================================
// DIARY (S-11)
// ============================================

async function getMyVisits(req, res) {
  try {
    const userId = req.user.id;
    const data = await profileService.getMyVisits(userId);
    res.json({ data });
  } catch (err) {
    res.status(500).json({
      error: { code: 'DIARY_ERROR', message: err.message }
    });
  }
}

// ============================================
// S-18 PROFILE
// ============================================

async function getMeProfile(req, res) {
  try {
    const userId = req.user.id;
    const data = await profileService.getMeProfile(userId);
    res.json({ data });
  } catch (err) {
    const status = err.message === 'User tidak ditemukan' ? 404 : 500;
    res.status(status).json({
      error: { code: 'PROFILE_ERROR', message: err.message }
    });
  }
}

async function updateMeProfile(req, res) {
  try {
    const userId = req.user.id;
    const data = await profileService.updateMeProfile(userId, req.body);
    res.json({ data });
  } catch (err) {
    res.status(500).json({
      error: { code: 'PROFILE_UPDATE_ERROR', message: err.message }
    });
  }
}

// ============================================
// S-19 FOLLOW / UNFOLLOW
// ============================================

async function followUser(req, res) {
  try {
    const followerId = req.user.id;
    const followingId = req.params.id;
    const data = await profileService.followUser(followerId, followingId);
    res.json({ data });
  } catch (err) {
    const status = err.message === 'Tidak bisa follow diri sendiri' ? 400
                 : err.message === 'User tidak ditemukan' ? 404 : 500;
    res.status(status).json({
      error: { code: 'FOLLOW_ERROR', message: err.message }
    });
  }
}

async function unfollowUser(req, res) {
  try {
    const followerId = req.user.id;
    const followingId = req.params.id;
    const data = await profileService.unfollowUser(followerId, followingId);
    res.json({ data });
  } catch (err) {
    res.status(500).json({
      error: { code: 'UNFOLLOW_ERROR', message: err.message }
    });
  }
}

// ============================================
// S-20 FOLLOWERS / FOLLOWING
// ============================================

async function getFollowers(req, res) {
  try {
    const userId = req.params.id;
    const currentUserId = req.user.id;
    const data = await profileService.getFollowers(userId, currentUserId);
    res.json({ data });
  } catch (err) {
    res.status(500).json({
      error: { code: 'FOLLOWERS_ERROR', message: err.message }
    });
  }
}

async function getFollowing(req, res) {
  try {
    const userId = req.params.id;
    const currentUserId = req.user.id;
    const data = await profileService.getFollowing(userId, currentUserId);
    res.json({ data });
  } catch (err) {
    res.status(500).json({
      error: { code: 'FOLLOWING_ERROR', message: err.message }
    });
  }
}

// ============================================
// S-19 USER VISITS & LISTS (privacy-aware)
// ============================================

async function getUserVisits(req, res) {
  try {
    const targetId = req.params.id;
    const viewerId = req.user.id;
    const data = await profileService.getUserVisits(targetId, viewerId);
    res.json({ data });
  } catch (err) {
    const status = err.message === 'User tidak ditemukan' ? 404 : 500;
    res.status(status).json({
      error: { code: 'USER_VISITS_ERROR', message: err.message }
    });
  }
}

async function getUserLists(req, res) {
  try {
    const targetId = req.params.id;
    const viewerId = req.user.id;
    const data = await profileService.getUserLists(targetId, viewerId);
    res.json({ data });
  } catch (err) {
    const status = err.message === 'User tidak ditemukan' ? 404 : 500;
    res.status(status).json({
      error: { code: 'USER_LISTS_ERROR', message: err.message }
    });
  }
}

module.exports = {
  getProfile,
  getMyStats,
  getMyVisits,
  getMeProfile,
  updateMeProfile,
  followUser,
  unfollowUser,
  getFollowers,
  getFollowing,
  getUserVisits,
  getUserLists
};