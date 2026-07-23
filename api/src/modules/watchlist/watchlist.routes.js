const express = require('express');
const router = express.Router();
const watchlistController = require('./watchlist.controller');
const { verifyToken } = require('../../middleware/auth');

router.use(verifyToken);

router.get('/', watchlistController.getWatchlist);
router.post('/', watchlistController.addToWatchlist);
router.delete('/:cafeId', watchlistController.removeFromWatchlist);

module.exports = router;
