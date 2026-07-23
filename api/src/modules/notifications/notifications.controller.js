// src/modules/notifications/notifications.controller.js
const service = require('./notifications.service');

async function getNotifications(req, res) {
  try {
    const userId = req.user.id;
    const notifications = await service.getUserNotifications(userId);
    res.json({
      statusCode: 200,
      data: notifications
    });
  } catch (err) {
    res.status(500).json({ statusCode: 500, error: err.message });
  }
}

async function getUnreadCount(req, res) {
  try {
    const userId = req.user.id;
    const count = await service.getUnreadCount(userId);
    res.json({
      statusCode: 200,
      data: { count }
    });
  } catch (err) {
    res.status(500).json({ statusCode: 500, error: err.message });
  }
}

async function markAllAsRead(req, res) {
  try {
    const userId = req.user.id;
    await service.markAllAsRead(userId);
    res.json({
      statusCode: 200,
      message: 'All notifications marked as read'
    });
  } catch (err) {
    res.status(500).json({ statusCode: 500, error: err.message });
  }
}

module.exports = {
  getNotifications,
  getUnreadCount,
  markAllAsRead
};
