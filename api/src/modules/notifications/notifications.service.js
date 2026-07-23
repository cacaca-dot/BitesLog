// src/modules/notifications/notifications.service.js
const repo = require('./notifications.repository');

async function addNotification(userId, actorId, type, targetType, targetId) {
  if (userId === actorId) return null;
  return await repo.createNotification(userId, actorId, type, targetType, targetId);
}

async function removeNotification(userId, actorId, type, targetType, targetId) {
  return await repo.deleteNotification(userId, actorId, type, targetType, targetId);
}

async function getUserNotifications(userId) {
  return await repo.getUserNotifications(userId);
}

async function getUnreadCount(userId) {
  return await repo.getUnreadCount(userId);
}

async function markAllAsRead(userId) {
  return await repo.markAllAsRead(userId);
}

async function getVisitOwner(visitId) {
  return await repo.getVisitOwner(visitId);
}

async function getListOwner(listId) {
  return await repo.getListOwner(listId);
}

async function getCommentOwner(commentId) {
  return await repo.getCommentOwner(commentId);
}

module.exports = {
  addNotification,
  removeNotification,
  getUserNotifications,
  getUnreadCount,
  markAllAsRead,
  getVisitOwner,
  getListOwner,
  getCommentOwner
};
