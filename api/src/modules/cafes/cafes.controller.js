const cafeService = require('./cafes.service');

async function getCafes(req, res) {
  try {
    const { search, category, city } = req.query;
    const cafes = await cafeService.searchCafes({ search, category, city });
    
    res.json({
      data: cafes,
      count: cafes.length
    });
  } catch (err) {
    console.error('❌ Error getCafes:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getCafeById(req, res) {
  try {
    const { id } = req.params;
    const cafe = await cafeService.getCafeDetail(id);
    
    if (!cafe) {
      return res.status(404).json({
        error: { code: 'NOT_FOUND', message: 'Cafe tidak ditemukan' }
      });
    }
    
    res.json({ data: cafe });
  } catch (err) {
    console.error('❌ Error getCafeById:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function createCafe(req, res) {
  try {
    const userId = req.user.id;
    const result = await cafeService.addCafe(req.body, userId);

    if (result.duplicate) {
      return res.status(409).json({
        error: {
          code: 'DUPLICATE_CAFE',
          message: 'Cafe dengan nama mirip sudah ada',
          similar: result.similar
        }
      });
    }

    res.status(201).json({
      data: result.cafe,
      message: 'Cafe berhasil ditambahkan'
    });
  } catch (err) {
    console.error('❌ Error createCafe:', err.message);
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

module.exports = {
  getCafes,
  getCafeById,
  createCafe
};