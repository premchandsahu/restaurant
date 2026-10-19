const express = require('express');
const router = express.Router();
const supplierLedgerController = require('../controller/supplierLedgerController');
const authenticate = require('../middleware/authMiddleware');

router.get(
    '/:supplierId/ledger',
    authenticate,
    supplierLedgerController.getSupplierLedger
);

router.get(
    '/:supplierId/outstanding',
    authenticate,
    supplierLedgerController.getSupplierOutstanding
);

module.exports = router;
