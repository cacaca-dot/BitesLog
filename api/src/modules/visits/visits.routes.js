const express = require('express');
const router = express.Router();
const visitController = require('./visits.controller');
const { verifyToken } = require('../../middleware/auth');

router.use(verifyToken);

router.get('/', visitController.getVisits);
router.post('/', visitController.createVisit);
router.get('/:id', visitController.getVisitById);
router.put('/:id', visitController.updateVisit);
router.delete('/:id', visitController.deleteVisit);

module.exports = router;