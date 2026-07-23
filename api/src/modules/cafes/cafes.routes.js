const express = require('express');
const router = express.Router();
const cafeController = require('./cafes.controller');
const { verifyToken } = require('../../middleware/auth');

// Semua route cafe butuh autentikasi
router.use(verifyToken);

router.get('/', cafeController.getCafes);
router.post('/', cafeController.createCafe);
router.get('/filters', cafeController.getFilters);
router.get('/:id/photos', cafeController.getCafePhotos);
router.get('/:id', cafeController.getCafeById);
router.get('/:id/reviews', cafeController.getCafeReviews);

module.exports = router;