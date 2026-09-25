const express = require('express');

const router = express.Router();

const menuController =
    require('../controller/menuController');

const authenticate =
    require('../middleware/authMiddleware');


/*
 * Categories
 *
 * GET /api/menu/categories?outletId=1
 */




router.get(
    '/categories',
    authenticate,
    menuController.getCategories
);


/*
 * All menu items
 *
 * GET /api/menu/items?outletId=1
 */
router.get(
    '/items',
    authenticate,
    menuController.getItems
);


/*
 * Items belonging to a category
 *
 * GET /api/menu/categories/1/items?outletId=1
 */
router.get(
    '/categories/:categoryId/items',
    authenticate,
    menuController.getItemsByCategory
);


/*
 * Complete item information
 *
 * GET /api/menu/items/1?outletId=1
 */
router.get(
    '/items/:itemId',
    authenticate,
    menuController.getItem
);


module.exports = router;