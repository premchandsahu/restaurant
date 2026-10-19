const express = require('express');
const router = express.Router();

const purchaseController = require('../controller/purchaseController');
const authenticate = require('../middleware/authMiddleware');

// Purchase Phase 2A
router.get('/', authenticate, purchaseController.getPurchases);
router.get('/:purchaseId', authenticate, purchaseController.getPurchase);
router.post('/', authenticate, purchaseController.createPurchase);
router.put('/:purchaseId', authenticate, purchaseController.updatePurchase);
router.post('/:purchaseId/post', authenticate, purchaseController.postPurchase);
router.delete(
    '/:purchaseId',
    authenticate,
    purchaseController.deletePurchase
);
module.exports = router;