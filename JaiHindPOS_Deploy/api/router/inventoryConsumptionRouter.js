const express = require('express');

const router = express.Router();

const consumptionController =
    require('../controller/inventoryConsumptionController');

const authenticate =
    require('../middleware/authMiddleware');

// ============================================================
// DYNAMIC RECIPE-BASED CONSUMPTION
// ============================================================

router.get(
    '/bills/:billId/preview',
    authenticate,
    consumptionController.getBillConsumptionPreview
);

router.get(
    '/report',
    authenticate,
    consumptionController.getConsumptionReport
);

module.exports = router;
