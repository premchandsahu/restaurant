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

router.post(
    '/',
    customerOrderController.createCustomerOrder
);

router.get(
    '/my-orders/:token',
    customerOrderController.getMyOrders
);


router.post(
    '/add-items',
    customerOrderController.addItemsToCustomerOrder
);

router.get(
    '/order-status/:token',
    customerOrderController.getCustomerOrderStatus
);

router.post(
    '/request-bill',
    customerOrderController.requestBill
);


router.post(
    '/cancel-item',
    customerOrderController.cancelCustomerOrderItem
);



module.exports = router;