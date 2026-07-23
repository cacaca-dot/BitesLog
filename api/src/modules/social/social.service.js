// src/modules/social/social.service.js
const repo = require('./social.repository');
const notifications = require('../notifications/notifications.service');

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
  await notifications.addNotification(followingId, followerId, 'follow', null, null);
  return follow;
}

async function unfollowUser(followerId, followingId) {
  const alreadyFollowing = await repo.isFollowing(followerId, followingId);
  if (!alreadyFollowing) {
    throw new Error('Tidak mengikuti user ini');
  }

  const unfollow = await repo.deleteFollow(followerId, followingId);
  await notifications.removeNotification(followingId, followerId, 'follow', null, null);
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
    
    // Hapus notif
    const notifTargetType = targetType === 'review' ? 'visit' : 'list';
    const ownerId = targetType === 'review' 
      ? await notifications.getVisitOwner(targetId)
      : await notifications.getListOwner(targetId);
      
    if (ownerId) {
      await notifications.removeNotification(ownerId, userId, 'like', notifTargetType, targetId);
    }
    
    const count = await repo.getLikeCount(targetType, targetId);
    return { liked: false, count };
  } else {
    await repo.createLike(userId, targetType, targetId);
    
    // Tambah notif
    const notifTargetType = targetType === 'review' ? 'visit' : 'list';
    const ownerId = targetType === 'review' 
      ? await notifications.getVisitOwner(targetId)
      : await notifications.getListOwner(targetId);
      
    if (ownerId) {
      await notifications.addNotification(ownerId, userId, 'like', notifTargetType, targetId);
    }
    
    const count = await repo.getLikeCount(targetType, targetId);
    return { liked: true, count };
  }
}

// ============================================
// COMMENTS
// ============================================

async function addComment(userId, targetType, targetId, commentText, parentCommentId = null) {
  if (!commentText || commentText.trim().length === 0) {
    throw new Error('Komentar tidak boleh kosong');
  }

  let finalTargetType = targetType;
  let finalTargetId = targetId;
  let finalParentId = parentCommentId;

  if (parentCommentId) {
    const parent = await repo.getCommentById(parentCommentId);
    if (!parent) {
      throw new Error('Komentar induk tidak ditemukan');
    }
    
    // Wariskan target dari induk
    finalTargetType = parent.target_type;
    finalTargetId = parent.target_id;
    
    // Flatten jika induk ternyata balasan (paksa max 1 level)
    if (parent.parent_comment_id) {
      finalParentId = parent.parent_comment_id;
    }
  }

  if (!['review', 'list'].includes(finalTargetType)) {
    throw new Error('Target type harus "review" atau "list"');
  }

  const comment = await repo.createComment(userId, finalTargetType, finalTargetId, commentText.trim(), finalParentId);
  
  // Handle notifications
  const notifTargetType = finalTargetType === 'review' ? 'visit' : 'list';
  
  if (parentCommentId) { // Ini adalah reply asli (berdasarkan input user, terlepas dari finalParentId yang di-flatten)
    // Notif ke pemilik komentar yang DIBALAS
    const parentOwnerId = await notifications.getCommentOwner(parentCommentId);
    if (parentOwnerId) {
      await notifications.addNotification(parentOwnerId, userId, 'reply', notifTargetType, finalTargetId);
    }
  } else {
    // Notif ke pemilik konten (visit/list)
    const contentOwnerId = finalTargetType === 'review'
      ? await notifications.getVisitOwner(finalTargetId)
      : await notifications.getListOwner(finalTargetId);
      
    if (contentOwnerId) {
      await notifications.addNotification(contentOwnerId, userId, 'comment', notifTargetType, finalTargetId);
    }
  }
  
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

async function getComments(targetType, targetId, limit = 20) {
  if (!['review', 'list'].includes(targetType)) {
    throw new Error('Target type harus "review" atau "list"');
  }
  return await repo.getComments(targetType, targetId, limit);
}

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
  getComments,
  getSocialStats
};