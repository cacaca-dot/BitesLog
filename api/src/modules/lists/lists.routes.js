const express = require('express');
const router = express.Router();
const listController = require('./lists.controller');
const { verifyToken } = require('../../middleware/auth');

// Semua route lists butuh autentikasi
router.use(verifyToken);

router.get('/me', listController.getMyLists);
router.get('/saved', listController.getSavedLists);
router.get('/:id', listController.getListDetail);
router.post('/', listController.createList);
router.put('/:id', listController.updateList);
router.delete('/:id', listController.deleteList);
router.post('/:id/items', listController.addCafeToList);
router.delete('/:id/items/:cafeId', listController.removeCafeFromList);
router.put('/:id/items/reorder', listController.reorderItems);
router.put('/:id/items/:cafeId', listController.updateItemNote);
router.post('/:id/save', listController.saveList);
router.delete('/:id/save', listController.unsaveList);

module.exports = router;
