// src/modules/profile/profile.routes.js
const express = require('express');
const router = express.Router();
const profileController = require('./profile.controller');
const { verifyToken } = require('../../middleware/auth');

router.use(verifyToken);

// ===== PROFILE =====
router.get('/users/:id/profile', profileController.getProfile);

// ===== MY STATS =====
router.get('/me/stats', profileController.getMyStats);

module.exports = router;