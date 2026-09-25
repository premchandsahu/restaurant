const express = require('express');

const router = express.Router();

const outletController = require('../controller/outletController');

const authenticate =
    require('../middleware/authMiddleware');


/*
 * Get all outlets available to logged-in user
 */
router.get(
    '/',
    authenticate,
    outletController.getOutlets
);


/*
 * Get complete POS layout
 */
router.get(
    '/:outletId/pos-layout',
    authenticate,
    outletController.getPosLayout
);


module.exports = router;