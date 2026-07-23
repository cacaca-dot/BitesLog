const cafeService = require('./cafes.service');

async function getCafes(req, res) {
  try {
    const { search, categories, areas, city, min_rating, price_range } = req.query;
    const cafes = await cafeService.searchCafes({ search, categories, areas, city, min_rating, price_range });
    
    res.json({
      data: cafes,
      count: cafes.length
    });
  } catch (err) {
    console.error('❌ Error getCafes:', err);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getFilters(req, res) {
  try {
    const filters = await cafeService.getFilters();
    res.json({ data: filters });
  } catch (err) {
    console.error('❌ Error getFilters:', err.message);
    res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
  }
}

async function addCafe(req, res) {
  try {
    const { name, categories, area, address, city, price_range, latitude, longitude, image_url } = req.body;
    const userId = req.user.id;

    if (!name || !categories || !city) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: 'Name, categories, dan city wajib diisi' }
      });
    }

    const newCafe = await cafeService.addCafe({
      name, categories, area, address, city, price_range, latitude, longitude, image_url, created_by: userId
    });
    
    res.status(201).json({ data: newCafe });
  } catch (err) {
    console.error('❌ Error addCafe:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getCafeById(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const cafe = await cafeService.getCafeDetail(id, userId);
    
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
    const { force = false } = req.body;
    const result = await cafeService.addCafe(req.body, userId, force);

    res.status(201).json({
      data: result.cafe,
      message: 'Cafe berhasil ditambahkan'
    });
  } catch (err) {
    if (err.code === 'DUPLICATE_CAFE_CANDIDATES') {
      return res.status(409).json({
        error: { code: 'duplicate_cafe', message: err.message },
        data: err.candidates
      });
    }

    console.error('❌ Error createCafe:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getCafeReviews(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const reviews = await cafeService.getCafeReviews(id, userId);
    
    res.json({
      data: reviews,
      count: reviews.length
    });
  } catch (err) {
    console.error('❌ Error getCafeReviews:', err.message);
    if (err.message === 'Cafe tidak ditemukan') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: err.message } });
    }
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getCafePhotos(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const photos = await cafeService.getCafePhotos(id, userId);
    
    res.json({
      data: photos,
      count: photos.length
    });
  } catch (err) {
    console.error('❌ Error getCafePhotos:', err.message);
    if (err.message === 'Cafe tidak ditemukan') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: err.message } });
    }
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

module.exports = {
  getCafes,
  getFilters,
  getCafeById,
  createCafe,
  getCafeReviews,
  getCafePhotos
};