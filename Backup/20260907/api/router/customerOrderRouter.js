const express = require('express');

const router = express.Router();

const customerOrderController =
    require("../controller/customerOrderController");

const authenticate =
    require('../middleware/authMiddleware');

    router.post(
    '/table-session',
    authenticate,
    customerOrderController.createTableSession
);

router.get(
    '/table/:token',
    customerOrderController.getTableByToken
);

router.post(
    '/customer-session',
    customerOrderController.createCustomerSession
);

router.get(
    '/menu/:token',
    customerOrderController.getCustomerMenu
);
module.exports = router;