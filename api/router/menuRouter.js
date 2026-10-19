const express = require('express');

const router = express.Router();

const menuController =
    require('../controller/menuController');

const authenticate =
    require('../middleware/authMiddleware');

const menuModifierController =
    require('../controller/menuModifierController');


const menuCategoryController =
    require('../controller/menuCategoryController');    
/*
 * Categories
 *
 * GET /api/menu/categories?outletId=1
 */
// Modifier Group Master
router.get(
    '/modifier-groups',
    authenticate,
    menuModifierController.getModifierGroups
);

router.post(
    '/modifier-groups',
    authenticate,
    menuModifierController.createModifierGroup
);

router.put(
    '/modifier-groups/:groupId',
    authenticate,
    menuModifierController.updateModifierGroup
);

// Modifier Option Master
router.post(
    '/modifier-groups/:groupId/options',
    authenticate,
    menuModifierController.createModifierOption
);

router.put(
    '/modifier-groups/:groupId/options/:optionId',
    authenticate,
    menuModifierController.updateModifierOption
);

// Assign groups to a menu item
router.put(
    '/items/:menuItemId/modifier-groups',
    authenticate,
    menuModifierController.setMenuItemModifierGroups
);

router.post(
    '/items',
    authenticate,
    menuController.createItem
);

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


router.put(
    '/items/:menuItemId',
    authenticate,
    menuController.updateItem
);


// Menu item variants
router.post(
    '/items/:menuItemId/variants',
    authenticate,
    menuController.createVariant
);

router.put(
    '/items/:menuItemId/variants/:variantId',
    authenticate,
    menuController.updateVariant
);


// Menu Category Master
router.get(
    '/category-master',
    authenticate,
    menuCategoryController.getCategories
);

router.post(
    '/category-master',
    authenticate,
    menuCategoryController.createCategory
);

router.put(
    '/category-master/:categoryId',
    authenticate,
    menuCategoryController.updateCategory
);

module.exports = router;