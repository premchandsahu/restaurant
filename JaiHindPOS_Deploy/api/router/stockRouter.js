const express = require('express');
const router = express.Router();

const stockController = require('../controller/stockController');
const authenticate = require('../middleware/authMiddleware');

// Inventory Phase 2C - dynamic stock reports
router.get('/summary', authenticate, stockController.getStockSummary);
router.get('/ledger', authenticate, stockController.getStockLedger);

module.exports = router;
