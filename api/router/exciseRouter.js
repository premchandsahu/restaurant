const express = require('express');

const router = express.Router();

const exciseController =
    require('../controller/exciseController');

const authenticate =
    require('../middleware/authMiddleware');


// ============================================================
// EXCISE LICENSE HOLDERS
// ============================================================

router.get(
    '/license-holders',
    authenticate,
    exciseController.getLicenseHolders
);

router.get(
    '/license-holders/:holderId',
    authenticate,
    exciseController.getLicenseHolder
);

router.post(
    '/license-holders',
    authenticate,
    exciseController.createLicenseHolder
);

router.put(
    '/license-holders/:holderId',
    authenticate,
    exciseController.updateLicenseHolder
);


// ============================================================
// EXCISE ITEMS
// ============================================================

router.get(
    '/items',
    authenticate,
    exciseController.getExciseItems
);

router.get(
    '/items/:itemId',
    authenticate,
    exciseController.getExciseItem
);

router.post(
    '/items',
    authenticate,
    exciseController.createExciseItem
);

router.put(
    '/items/:itemId',
    authenticate,
    exciseController.updateExciseItem
);


router.get(
    '/item-pos-mappings',
    authenticate,
    exciseController.getItemPosMappings
);

router.post(
    '/item-pos-mappings',
    authenticate,
    exciseController.createItemPosMapping
);

router.put(
    '/item-pos-mappings/:mappingId',
    authenticate,
    exciseController.updateItemPosMapping
);

module.exports = router;