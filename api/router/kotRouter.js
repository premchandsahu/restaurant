const express = require('express');

const router = express.Router();

const kotController =
    require('../controller/kotController');

const authenticate =
    require('../middleware/authMiddleware');


// Create KOT(s) for an order
//
// POST /api/orders/:orderId/kot

router.post(
    '/orders/:orderId/kot',
    authenticate,
    kotController.createKOT
);


// Get KOTs for an order
//
// GET /api/orders/:orderId/kot

router.get(
    '/orders/:orderId/kot',
    authenticate,
    kotController.getOrderKOTs
);


// Update KOT status
//
// PUT /api/kot/:kotId/status

router.put(
    '/kot/:kotId/status',
    authenticate,
    kotController.updateKOTStatus
);

// ----------------------------------------------------
// Get active KOTs for kitchen station
//
// GET /kot/station/:stationId
// ----------------------------------------------------

router.get(
    '/station/:stationId',
    authenticate,
    kotController.getStationKOTs
);
// ----------------------------------------------------
// Get kitchen stations
//
// GET /kot/stations
// ----------------------------------------------------

router.get(
    '/stations',
    authenticate,
    kotController.getKitchenStations
);


router.post('/stations', authenticate, kotController.createKitchenStation);
router.put('/stations/:stationId', authenticate, kotController.updateKitchenStation);
router.get('/menu-item-stations', authenticate, kotController.getMenuItemStationMappings);
router.put('/menu-item-stations/:menuItemId', authenticate, kotController.saveMenuItemStationMappings);

module.exports = router;