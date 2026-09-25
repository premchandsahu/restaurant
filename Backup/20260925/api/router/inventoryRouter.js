const express = require('express');

const router = express.Router();

const inventoryController =
    require('../controller/inventoryController');

const stockRegisterController =
    require('../controller/inventoryStockRegisterController');

const stockLedgerController =
    require('../controller/inventoryStockLedgerController');

const stockReconciliationController =
    require('../controller/inventoryStockReconciliationController');

const recipeCoverageController =
    require('../controller/inventoryRecipeCoverageController');

const authenticate =
    require('../middleware/authMiddleware');




// ============================================================
// UNITS
// ============================================================

router.get(
    '/units',
    authenticate,
    inventoryController.getUnits
);


// ============================================================
// INVENTORY CATEGORIES
// ============================================================

router.get(
    '/categories',
    authenticate,
    inventoryController.getCategories
);


// ============================================================
// SUPPLIERS
// ============================================================

router.get(
    '/suppliers',
    authenticate,
    inventoryController.getSuppliers
);

router.post(
    '/suppliers',
    authenticate,
    inventoryController.createSupplier
);

router.put(
    '/suppliers/:supplierId',
    authenticate,
    inventoryController.updateSupplier
);


// ============================================================
// RAW MATERIALS
// ============================================================

router.get(
    '/raw-materials',
    authenticate,
    inventoryController.getRawMaterials
);

router.get(
    '/raw-materials/:rawMaterialId',
    authenticate,
    inventoryController.getRawMaterial
);

router.post(
    '/raw-materials',
    authenticate,
    inventoryController.createRawMaterial
);

router.put(
    '/raw-materials/:rawMaterialId',
    authenticate,
    inventoryController.updateRawMaterial
);


router.get(
    '/stock/register',
    authenticate,
    stockRegisterController.getStockRegister
);

router.get(
    '/stock/ledger',
    authenticate,
    stockLedgerController.getStockItemLedger
);

router.get(
    '/stock/reconciliation',
    authenticate,
    stockReconciliationController.getStockReconciliation
);


router.get(
    '/recipes/coverage',
    authenticate,
    recipeCoverageController.getRecipeCoverage
);

module.exports = router;
