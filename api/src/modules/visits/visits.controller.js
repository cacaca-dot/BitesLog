const visitService = require('./visits.service');

async function getVisits(req, res) {
  try {
    const userId = req.user.id;
    const visits = await visitService.getUserDiary(userId);
    
    res.json({
      data: visits,
      count: visits.length
    });
  } catch (err) {
    console.error('❌ Error getVisits:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getVisitById(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user ? req.user.id : null;
    const visit = await visitService.getVisitDetail(id, userId);
    
    if (!visit) {
      return res.status(404).json({
        error: { code: 'NOT_FOUND', message: 'Kunjungan tidak ditemukan' }
      });
    }
    
    res.json({ data: visit });
  } catch (err) {
    console.error('❌ Error getVisitById:', err.message);
    if (err.code === 'FORBIDDEN') {
      return res.status(403).json({
        error: { code: 'FORBIDDEN', message: err.message }
      });
    }
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function createVisit(req, res) {
  try {
    const userId = req.user.id;
    
    // Validasi maksimal 4 foto
    if (req.body.photos && Array.isArray(req.body.photos)) {
      if (req.body.photos.length > 4) {
        throw new Error('Maksimal 4 foto yang diperbolehkan');
      }
    }

    const visit = await visitService.logVisit(req.body, userId);
    
    res.status(201).json({
      data: visit,
      message: 'Kunjungan berhasil dicatat! ☕'
    });
  } catch (err) {
    console.error('❌ Error createVisit:', err.message);
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function updateVisit(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    
    // Validasi maksimal 4 foto
    if (req.body.photos && Array.isArray(req.body.photos)) {
      if (req.body.photos.length > 4) {
        throw new Error('Maksimal 4 foto yang diperbolehkan');
      }
    }

    const updated = await visitService.editVisit(id, userId, req.body);
    
    res.json({
      data: updated,
      message: 'Kunjungan berhasil diperbarui'
    });
  } catch (err) {
    console.error('❌ Error updateVisit:', err.message);
    const status = err.message.includes('akses') ? 403 : 400;
    res.status(status).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function deleteVisit(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    await visitService.removeVisit(id, userId);
    
    res.json({
      message: 'Kunjungan berhasil dihapus'
    });
  } catch (err) {
    console.error('❌ Error deleteVisit:', err.message);
    const status = err.message.includes('akses') ? 403 : 404;
    res.status(status).json({
      error: { code: 'NOT_FOUND', message: err.message }
    });
  }
}

module.exports = {
  getVisits,
  getVisitById,
  createVisit,
  updateVisit,
  deleteVisit
};