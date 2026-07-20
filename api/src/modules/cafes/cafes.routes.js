const express = require('express');
const router = express.Router();
const cafeController = require('./cafes.controller');
const { verifyToken } = require('../../middleware/auth');

// Semua route cafe butuh autentikasi
router.use(verifyToken);

router.get('/', cafeController.getCafes);
router.post('/', cafeController.createCafe);
router.get('/:id', cafeController.getCafeById);

module.exports = router;