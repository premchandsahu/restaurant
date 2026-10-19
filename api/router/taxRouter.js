const express = require('express');

const router = express.Router();

const taxController =
    require('../controller/taxController');





// ==================================================
// TAX GROUP AND RATE MASTER APIs
// ==================================================

router.get(
    '/groups/master',
    taxController.getTaxGroupsForMaster
);

router.post(
    '/groups',
    taxController.createTaxGroup
);

router.put(
    '/groups/:taxGroupId',
    taxController.updateTaxGroup
);

router.post(
    '/groups/:taxGroupId/rates',
    taxController.createTaxRate
);

router.put(
    '/rates/:taxRateId',
    taxController.updateTaxRate
);


// GET all tax groups
router.get(
    '/groups',
    taxController.getTaxGroups
);


// GET one tax group
router.get(
    '/groups/:taxGroupId',
    taxController.getTaxGroup
);


// GET rates belonging to tax group
router.get(
    '/groups/:taxGroupId/rates',
    taxController.getTaxRates
);



module.exports = router;