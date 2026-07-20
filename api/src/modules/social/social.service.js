// src/modules/social/social.service.js
const repo = require('./social.repository');

// ============================================
// FOLLOW
// ============================================

async function followUser(followerId, followingId) {
  if (followerId === followingId) {
    throw new Error('Tidak bisa follow diri sendiri');
  }

  const alreadyFollowing = await repo.isFollowing(followerId, followingId);
  if (alreadyFollowing) {
    throw new Error('Sudah mengikuti user ini');
  }

  const user = await repo.getUserById(followingId);
  if (!user) {
    throw new Error('User tidak ditemukan');
  }

  const follow = await repo.createFollow(followerId, followingId);
  return follow;
}

async function unfollowUser(followerId, followingId) {
  const alreadyFollowing = await repo.isFollowing(followerId, followingId);
  if (!alreadyFollowing) {
    throw new Error('Tidak mengikuti user ini');
  }

  const unfollow = await repo.deleteFollow(followerId, followingId);
  return unfollow;
}

async function checkFollowStatus(followerId, followingId) {
  return await repo.isFollowing(followerId, followingId);
}

// ============================================
// FEED
// ============================================

async function getActivityFeed(userId) {
  const feed = await repo.getFeed(userId);
  
  // Jika feed kosong, ambil popular feed
  if (feed.length === 0) {
    return await repo.getPopularFeed();
  }
  
  return feed;
}

// ============================================
// LIKES
// ============================================

async function toggleLike(userId, targetType, targetId) {
  // Validasi target type
  if (!['review', 'list'].includes(targetType)) {
    throw new Error('Target type harus "review" atau "list"');
  }

  const alreadyLiked = await repo.isLiked(userId, targetType, targetId);

  if (alreadyLiked) {
    await repo.deleteLike(userId, targetType, targetId);
    const count = await repo.getLikeCount(targetType, targetId);
    return { liked: false, count };
  } else {
    await repo.createLike(userId, targetType, targetId);
    const count = await repo.getLikeCount(targetType, targetId);
    return { liked: true, count };
  }
}

// ============================================
// COMMENTS
// ============================================

async function addComment(userId, targetType, targetId, commentText) {
  if (!commentText || commentText.trim().length === 0) {
    throw new Error('Komentar tidak boleh kosong');
  }

  if (!['review', 'list'].includes(targetType)) {
    throw new Error('Target type harus "review" atau "list"');
  }

  const comment = await repo.createComment(userId, targetType, targetId, commentText.trim());
  return comment;
}

async function removeComment(commentId, userId) {
  const deleted = await repo.deleteComment(commentId, userId);
  if (!deleted) {
    throw new Error('Komentar tidak ditemukan atau bukan milik Anda');
  }
  return deleted;
}

// ============================================
// SOCIAL STATS
// ============================================

async function getSocialStats(userId) {
  const [followers, following] = await Promise.all([
    repo.getFollowersCount(userId),
    repo.getFollowingCount(userId)
  ]);

  return { followers, following };
}

module.exports = {
  followUser,
  unfollowUser,
  checkFollowStatus,
  getActivityFeed,
  toggleLike,
  addComment,
  removeComment,
  getSocialStats
};