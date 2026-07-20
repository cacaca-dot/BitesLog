// src/modules/discovery/discovery.controller.js
const discoveryService = require('./discovery.service');

// ============================================
// SEARCH
// ============================================

async function search(req, res) {
  try {
    const { q } = req.query;
    
    if (!q || q.trim().length === 0) {
      return res.json({
        data: { cafes: [], users: [], lists: [] },
        message: 'Masukkan keyword pencarian'
      });
    }

    const results = await discoveryService.searchAll(q);
    res.json({
      data: results,
      total: results.cafes.length + results.users.length + results.lists.length
    });
  } catch (err) {
    res.status(500).json({
      error: { code: 'SEARCH_ERROR', message: err.message }
    });
  }
}

// ============================================
// DISCOVER
// ============================================

async function getDiscover(req, res) {
  try {
    const userId = req.user.id;
    const discover = await discoveryService.getDiscover(userId);
    
    res.json({
      data: discover
    });
  } catch (err) {
    res.status(500).json({
      error: { code: 'DISCOVER_ERROR', message: err.message }
    });
  }
}

module.exports = {
  search,
  getDiscover
};