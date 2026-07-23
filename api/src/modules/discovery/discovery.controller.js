// src/modules/discovery/discovery.controller.js
const discoveryService = require('./discovery.service');

// ============================================
// SEARCH
// ============================================

async function search(req, res) {
  try {
    let { q, type } = req.query;
    
    if (!q || q.trim().length < 2) {
      return res.json({
        data: [],
        message: 'Masukkan minimal 2 karakter'
      });
    }
    
    type = type || 'user';
    if (!['user', 'cafe', 'list'].includes(type)) {
      return res.status(400).json({ error: { code: 'INVALID_TYPE', message: 'Tipe pencarian tidak valid' }});
    }

    let results = [];
    if (type === 'user') {
      results = await discoveryService.searchUsers(q, req.user.id);
    } else if (type === 'cafe') {
      results = await discoveryService.searchCafes(q);
    } else if (type === 'list') {
      results = await discoveryService.searchLists(q, req.user.id);
    }

    res.json({
      data: results
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