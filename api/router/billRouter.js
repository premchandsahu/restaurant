const express = require('express');

const router = express.Router();

const billController =
    require('../controller/billController');


const authenticate =     require('../middleware/authMiddleware'); 


// ============================================================
// Create normal bill
// ============================================================

router.post(
    '/',
    authenticate,
    billController.createBill
);

router.get(
    '/pending',
    authenticate,
    billController.getPendingBills
);



// ============================================================
// Bill History
// ============================================================

router.get(
    '/history',
    authenticate,
    billController.getBillHistory
);



// ============================================================
// Get bill
// ============================================================

router.get(
    '/:billId',
    authenticate,
    billController.getBill
);


router.post(
  '/:billId/payments',
  authenticate,
  billController.addPayment
);


module.exports = router;