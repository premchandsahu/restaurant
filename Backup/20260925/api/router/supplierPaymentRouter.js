const express = require('express');
const router = express.Router();
const supplierPaymentController = require('../controller/supplierPaymentController');
const authenticate = require('../middleware/authMiddleware');

router.post(
    '/:supplierId/payments',
    authenticate,
    supplierPaymentController.createSupplierPayment
);

router.get(
    '/:supplierId/payments',
    authenticate,
    supplierPaymentController.getSupplierPayments
);

router.get(
    '/:supplierId/payments/:paymentId',
    authenticate,
    supplierPaymentController.getSupplierPayment
);

router.post(
    '/:supplierId/payments/:paymentId/allocate',
    authenticate,
    supplierPaymentController.allocateSupplierPayment
);

router.post(
    '/:supplierId/payments/:paymentId/void',
    authenticate,
    supplierPaymentController.voidSupplierPayment
);

module.exports = router;
