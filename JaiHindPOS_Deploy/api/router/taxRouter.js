const express = require('express');

const router = express.Router();

const taxController =
    require('../controller/taxController');


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