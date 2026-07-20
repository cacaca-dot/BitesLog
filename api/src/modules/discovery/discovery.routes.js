// src/modules/discovery/discovery.routes.js
const express = require('express');
const router = express.Router();
const discoveryController = require('./discovery.controller');
const { verifyToken } = require('../../middleware/auth');

router.use(verifyToken);

// ===== SEARCH =====
router.get('/search', discoveryController.search);

// ===== DISCOVER =====
router.get('/discover', discoveryController.getDiscover);

module.exports = router;