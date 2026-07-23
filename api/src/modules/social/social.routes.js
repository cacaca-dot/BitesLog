// src/modules/social/social.routes.js
const express = require('express');
const router = express.Router();
const socialController = require('./social.controller');
const { verifyToken } = require('../../middleware/auth');

// Semua route sosial butuh autentikasi
router.use(verifyToken);

// ===== FOLLOW =====
router.post('/users/:id/follow', socialController.followUser);
router.delete('/users/:id/follow', socialController.unfollowUser);

// ===== FEED =====
router.get('/feed', socialController.getFeed);

// ===== LIKES =====
router.post('/likes', socialController.toggleLike);
router.delete('/likes', socialController.toggleLike);

// ===== COMMENTS =====
router.get('/comments', socialController.getComments);
router.post('/comments', socialController.addComment);
router.delete('/comments/:id', socialController.deleteComment);

module.exports = router;