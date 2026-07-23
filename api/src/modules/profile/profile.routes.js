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

// ===== MY VISITS (DIARY S-11) =====
router.get('/me/visits', profileController.getMyVisits);

// ===== ME PROFILE (S-18) =====
router.get('/me/profile', profileController.getMeProfile);
router.put('/me/profile', profileController.updateMeProfile);

// ===== S-19 FOLLOW / UNFOLLOW =====
router.post('/users/:id/follow', profileController.followUser);
router.delete('/users/:id/follow', profileController.unfollowUser);

// ===== S-20 FOLLOWERS / FOLLOWING =====
router.get('/users/:id/followers', profileController.getFollowers);
router.get('/users/:id/following', profileController.getFollowing);

// ===== S-19 USER VISITS & LISTS (privacy-aware) =====
router.get('/users/:id/visits', profileController.getUserVisits);
router.get('/users/:id/lists', profileController.getUserLists);

module.exports = router;