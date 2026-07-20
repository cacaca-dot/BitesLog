// src/modules/profile/profile.service.js
const repo = require('./profile.repository');

// ============================================
// PROFILE
// ============================================

async function getProfile(userId, viewerId = null) {
  const user = await repo.getUserProfile(userId);
  
  if (!user) {
    throw new Error('User tidak ditemukan');
  }

  // Cek privacy
  if (user.is_private && userId !== viewerId) {
    return {
      user: {
        id: user.id,
        username: user.username,
        full_name: user.full_name,
        avatar_url: user.avatar_url,
        bio: user.bio,
        is_private: true
      },
      isPrivate: true
    };
  }

  // Ambil stats
  const stats = await repo.getUserStats(userId);
  
  // Ambil favorite cafes
  const favoriteCafes = await repo.getFavoriteCafes(userId);

  // Ambil taste tag
  const tasteTag = await repo.getUserTasteTag(userId);

  return {
    user,
    stats,
    favoriteCafes,
    tasteTag,
    isPrivate: false
  };
}

// ============================================
// MY STATS
// ============================================

async function getMyStats(userId) {
  const stats = await repo.getUserStats(userId);
  const favoriteCafes = await repo.getFavoriteCafes(userId);
  const tasteTag = await repo.getUserTasteTag(userId);
  
  return { stats, favoriteCafes, tasteTag };
}

module.exports = {
  getProfile,
  getMyStats
};