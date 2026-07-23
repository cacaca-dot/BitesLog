// src/modules/notifications/notifications.routes.js
const express = require('express');
const router = express.Router();
const controller = require('./notifications.controller');
const authenticateToken = require('../../middleware/auth');

router.use(authenticateToken);

router.get('/', controller.getNotifications);
router.get('/unread-count', controller.getUnreadCount);
router.put('/read', controller.markAllAsRead);

module.exports = router;
