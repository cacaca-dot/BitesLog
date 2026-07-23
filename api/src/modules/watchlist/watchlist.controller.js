const watchlistService = require('./watchlist.service');

async function getWatchlist(req, res) {
  try {
    const userId = req.user.id;
    const watchlist = await watchlistService.getWatchlist(userId);
    res.json({ data: watchlist, count: watchlist.length });
  } catch (err) {
    console.error('❌ Error getWatchlist controller:', err);
    res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
  }
}

  async function addToWatchlist(req, res) {
    try {
      const userId = req.user.id;
      const { cafe_id } = req.body;
      
      if (!cafe_id) {
        return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'cafe_id wajib diisi' } });
      }

      const item = await watchlistService.addToWatchlist(userId, cafe_id);
      res.status(201).json({ data: item });
    } catch (err) {
      res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
    }
  }

  async function removeFromWatchlist(req, res) {
    try {
      const userId = req.user.id;
      const cafeId = req.params.cafeId;
      
      await watchlistService.removeFromWatchlist(userId, cafeId);
      res.json({ message: 'Berhasil dihapus dari watchlist' });
    } catch (err) {
      if (err.message === 'Cafe tidak ditemukan di watchlist') {
        return res.status(404).json({ error: { code: 'NOT_FOUND', message: err.message } });
      }
      res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
    }
  }

  module.exports = {
    getWatchlist,
    addToWatchlist,
    removeFromWatchlist
  };
