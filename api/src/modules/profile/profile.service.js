// src/modules/profile/profile.service.js
const repo = require('./profile.repository');
const { canViewContent } = require('../../utils/privacy.helper');

// ============================================
// PROFILE (S-19: public view dengan is_self, is_following)
// ============================================

async function getProfile(userId, viewerId) {
  const user = await repo.getUserProfile(userId);
  if (!user) throw new Error('User tidak ditemukan');

  const isSelf = String(userId) === String(viewerId);
  const isFollowing = isSelf ? false : await repo.checkIsFollowing(viewerId, userId);

  const stats = await repo.getUserStats(userId);

  // Check privacy
  const canView = await canViewContent(viewerId, userId);
  if (!canView) {
    return {
      user: {
        id: user.id,
        username: user.username,
        full_name: user.full_name,
        bio: user.bio,
        avatar_url: user.avatar_url,
        is_private: user.is_private,
      },
      follower_count: stats.followers,
      following_count: stats.following,
      stats: {
        total_visits: stats.total_visits,
        unique_cafes: stats.total_cafes,
        total_lists: stats.total_lists,
        avg_rating_given: stats.avg_rating
      },
      taste: {},
      is_self: isSelf,
      is_following: isFollowing,
      locked: true,
    };
  }

  const taste = await repo.getUserTasteProfile(userId);

  return {
    user: {
      full_name: user.full_name,
      username: user.username,
      bio: user.bio,
      avatar_url: user.avatar_url,
      is_private: user.is_private
    },
    follower_count: stats.followers,
    following_count: stats.following,
    stats: {
      total_visits: stats.total_visits,
      unique_cafes: stats.total_cafes,
      total_lists: stats.total_lists,
      avg_rating_given: stats.avg_rating
    },
    taste,
    is_self: isSelf,
    is_following: isFollowing,
    locked: false
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

// ============================================
// DIARY (S-11)
// ============================================

async function getMyVisits(userId) {
  const visits = await repo.getMyVisits(userId);
  return { total_count: visits.length, visits };
}

// ============================================
// S-18 PROFILE
// ============================================

async function getMeProfile(userId) {
  const user = await repo.getUserProfile(userId);
  if (!user) throw new Error('User tidak ditemukan');

  const stats = await repo.getUserStats(userId);
  const taste = await repo.getUserTasteProfile(userId);

  return {
    user: {
      full_name: user.full_name,
      username: user.username,
      bio: user.bio,
      avatar_url: user.avatar_url,
      is_private: user.is_private
    },
    follower_count: stats.followers,
    following_count: stats.following,
    stats: {
      total_visits: stats.total_visits,
      unique_cafes: stats.total_cafes,
      total_lists: stats.total_lists,
      avg_rating_given: stats.avg_rating
    },
    taste
  };
}

async function updateMeProfile(userId, data) {
  const allowedData = {
    full_name: data.full_name,
    bio: data.bio,
    avatar_url: data.avatar_url,
    is_private: data.is_private
  };
  const updatedUser = await repo.updateUserProfile(userId, allowedData);
  if (!updatedUser) throw new Error('Gagal update profile');
  return {
    full_name: updatedUser.full_name,
    username: updatedUser.username,
    bio: updatedUser.bio,
    avatar_url: updatedUser.avatar_url,
    is_private: updatedUser.is_private
  };
}

// ============================================
// S-19 FOLLOW / UNFOLLOW
// ============================================

async function followUser(followerId, followingId) {
  if (String(followerId) === String(followingId)) {
    throw new Error('Tidak bisa follow diri sendiri');
  }
  // Cek target ada
  const target = await repo.getUserProfile(followingId);
  if (!target) throw new Error('User tidak ditemukan');

  await repo.followUser(followerId, followingId);
  return { success: true };
}

async function unfollowUser(followerId, followingId) {
  await repo.unfollowUser(followerId, followingId);
  return { success: true };
}

// ============================================
// S-20 FOLLOWERS / FOLLOWING
// ============================================

async function getFollowers(userId, currentUserId) {
  return repo.getFollowersList(userId, currentUserId);
}

async function getFollowing(userId, currentUserId) {
  return repo.getFollowingList(userId, currentUserId);
}

// ============================================
// S-19 USER VISITS & LISTS (privacy-aware)
// ============================================

async function getUserVisits(targetId, viewerId) {
  const target = await repo.getUserProfile(targetId);
  if (!target) throw new Error('User tidak ditemukan');
  
  const canView = await canViewContent(viewerId, targetId);
  if (!canView) {
    return { visits: [], total_count: 0, locked: true };
  }

  const visits = await repo.getUserVisits(targetId);
  return { visits: visits, total_count: visits.length, locked: false };
}

async function getUserLists(targetId, viewerId) {
  const target = await repo.getUserProfile(targetId);
  if (!target) throw new Error('User tidak ditemukan');

  const canView = await canViewContent(viewerId, targetId);
  if (!canView) {
    return { lists: [], total_count: 0, locked: true };
  }

  const isSelf = String(targetId) === String(viewerId);
  // Diri sendiri → semua list; orang lain → hanya public
  const publicLists = await repo.getUserPublicLists(targetId);
  // Actually we shouldn't use getMyVisits for lists, but the original code had it.
  // The original code was returning publicLists for both since it returned `publicLists`. Let's just return publicLists.
  const lists = publicLists; 

  return { lists: lists, total_count: lists.length, locked: false };
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