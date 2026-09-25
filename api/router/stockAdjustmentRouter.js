const express = require('express');
const router = express.Router();

const stockAdjustmentController = require('../controller/stockAdjustmentController');
const authenticate = require('../middleware/authMiddleware');

router.get(
    '/',
    authenticate,
    stockAdjustmentController.getStockAdjustments
);

router.get(
    '/:adjustmentId',
    authenticate,
    stockAdjustmentController.getStockAdjustment
);

router.post(
    '/',
    authenticate,
    stockAdjustmentController.createStockAdjustment
);

module.exports = router;
