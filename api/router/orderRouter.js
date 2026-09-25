const express = require('express'); 
const router = express.Router(); 


const orderController =     
require('../controller/orderController'); 

const authenticate =     require('../middleware/authMiddleware'); 


router.post(
    '/:sourceOrderId/merge',
    authenticate,
    orderController.mergeOrders
);

router.post(     '/:orderId/discount',     authenticate,     orderController.applyOrderDiscount ); 

router.post(     '/',     authenticate,     orderController.createOrder ); 

router.get(
    '/table/:tableId/orders',
    authenticate,
    orderController.getTableOrders
);

router.post(
    '/:orderId/transfer-table',
    authenticate,
    orderController.transferOrderTable
);

router.get(     '/table/:tableId',     authenticate,     orderController.getTableOrder ); 

router.get(     '/:orderId',     authenticate,     orderController.getOrder ); 

router.post(     '/:orderId/items',     authenticate,     orderController.addOrderItem ); 

router.put(     '/:orderId',     authenticate,     orderController.updateOrder ); 

module.exports = router;