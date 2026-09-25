const express = require('express');

const router = express.Router();

const authenticate = require('../middleware/authMiddleware');
const appMenuController = require('../controller/appMenuController');

router.get(
    '/',
    authenticate,
    appMenuController.getMyMenus
);

module.exports = router;