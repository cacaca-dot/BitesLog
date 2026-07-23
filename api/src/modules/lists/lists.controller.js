const listService = require('./lists.service');

async function getMyLists(req, res) {
  try {
    const userId = req.user.id;
    const lists = await listService.getMyLists(userId);
    
    res.json({
      data: lists,
      count: lists.length
    });
  } catch (err) {
    console.error('❌ Error getMyLists:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getSavedLists(req, res) {
  try {
    const userId = req.user.id;
    const lists = await listService.getSavedLists(userId);
    
    res.json({
      data: lists,
      count: lists.length
    });
  } catch (err) {
    console.error('❌ Error getSavedLists:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function getListDetail(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const list = await listService.getListDetail(id, userId);
    
    res.json({ data: list });
  } catch (err) {
    console.error('❌ Error getListDetail:', err.message);
    if (err.message === 'LIST_NOT_FOUND') {
      return res.status(404).json({ error: { code: 'LIST_NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'List ini private' } });
    }
    console.error('❌ Error getListDetail:', err.message);
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function createList(req, res) {
  try {
    const userId = req.user.id;
    const list = await listService.createList(userId, req.body);
    
    res.status(201).json({
      data: list,
      message: 'List berhasil dibuat'
    });
  } catch (err) {
    console.error('❌ Error createList:', err.message);
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function updateList(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const updated = await listService.updateList(id, userId, req.body);
    
    res.json({
      data: updated,
      message: 'List berhasil diperbarui'
    });
  } catch (err) {
    console.error('❌ Error updateList:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses untuk mengubah list ini' } });
    }
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function deleteList(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    await listService.deleteList(id, userId);
    
    res.json({
      message: 'List berhasil dihapus'
    });
  } catch (err) {
    console.error('❌ Error deleteList:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses untuk menghapus list ini' } });
    }
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function addCafeToList(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const item = await listService.addItemToList(id, userId, req.body);
    
    res.status(201).json({
      data: item,
      message: 'Cafe berhasil ditambahkan ke list'
    });
  } catch (err) {
    console.error('❌ Error addCafeToList:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses ke list ini' } });
    }
    if (err.message === 'DUPLICATE') {
      return res.status(409).json({ error: { code: 'DUPLICATE', message: 'Cafe sudah ada di list ini' } });
    }
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function removeCafeFromList(req, res) {
  try {
    const { id, cafeId } = req.params;
    const userId = req.user.id;
    await listService.removeItemFromList(id, userId, cafeId);
    
    res.json({
      message: 'Cafe berhasil dihapus dari list'
    });
  } catch (err) {
    console.error('❌ Error removeCafeFromList:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses ke list ini' } });
    }
    res.status(500).json({
      error: { code: 'SERVER_ERROR', message: err.message }
    });
  }
}

async function reorderItems(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const { order } = req.body; // array of cafe_ids
    
    const items = await listService.reorderItems(id, userId, order);
    
    res.json({
      data: items,
      message: 'Urutan cafe berhasil diperbarui'
    });
  } catch (err) {
    console.error('❌ Error reorderItems:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses ke list ini' } });
    }
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function updateItemNote(req, res) {
  try {
    const { id, cafeId } = req.params;
    const userId = req.user.id;
    const { note } = req.body;
    
    const updated = await listService.updateItemNote(id, userId, cafeId, note);
    
    res.json({
      data: updated,
      message: 'Catatan cafe berhasil diperbarui'
    });
  } catch (err) {
    console.error('❌ Error updateItemNote:', err.message);
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak memiliki akses ke list ini' } });
    }
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: err.message }
    });
  }
}

async function saveList(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    await listService.saveList(userId, id);
    res.json({ message: 'List berhasil disimpan' });
  } catch (err) {
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Tidak dapat menyimpan list milik sendiri' } });
    }
    res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
  }
}

async function unsaveList(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    await listService.unsaveList(userId, id);
    res.json({ message: 'List dihapus dari simpanan' });
  } catch (err) {
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'List tidak ditemukan' } });
    }
    res.status(500).json({ error: { code: 'SERVER_ERROR', message: err.message } });
  }
}

module.exports = {
  getMyLists,
  getSavedLists,
  getListDetail,
  createList,
  updateList,
  deleteList,
  addCafeToList,
  removeCafeFromList,
  reorderItems,
  updateItemNote,
  saveList,
  unsaveList
};
