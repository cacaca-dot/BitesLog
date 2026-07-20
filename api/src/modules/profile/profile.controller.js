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

module.exports = {
  getProfile,
  getMyStats
};