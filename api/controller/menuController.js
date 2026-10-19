const conn = require('../database');


/*
 * GET /api/menu/categories?outletId=1
 *
 * Returns active menu categories for an outlet.
 */





exports.getCategories = async (req, res) => {
    const db=await conn.getConnection();

    try {

        const outletId = Number(
            req.query.outletId
        );

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        // Verify user has access to this outlet.
        const [access] = await db.query(
            `
            SELECT 1
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE
            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        const [categories] = await db.query(
            `
            SELECT
                menu_category_id,
                outlet_id,
                category_code,
                category_name,
                parent_category_id,
                display_order
            FROM menu_category
            WHERE outlet_id = ?
              AND is_active = TRUE
            ORDER BY
                display_order,
                category_name
            `,
            [outletId]
        );

        return res.json({
            success: true,
            categories
        });

    } catch (error) {

        console.error(
            'Get menu categories error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get menu categories'
        });
    }
};


/*
 * GET /api/menu/items?outletId=1
 */
/*
exports.getItems = async (req, res) => {
const db=await conn.getConnection();
    try {

        const outletId = Number(
            req.query.outletId
        );

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const [access] = await db.query(
            `
            SELECT 1
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE
            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        const [items] = await db.query(
            `
            SELECT
                mi.menu_item_id,
                mi.menu_item_uuid,
                mi.outlet_id,
                mi.menu_category_id,

                mc.category_code,
                mc.category_name,

                mi.item_code,
                mi.item_name,
                mi.description,
                mi.item_type,
                mi.base_rate,

                mi.tax_group_id,

                mi.is_veg,
                mi.is_egg,
                mi.is_spicy,

                mi.image_url,
                mi.barcode,

                mi.preparation_time_minutes,

                mi.allow_discount,
                mi.is_available,
                mi.is_active

            FROM menu_item mi

            INNER JOIN menu_category mc
                ON mc.menu_category_id =
                   mi.menu_category_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE

            ORDER BY
                mc.display_order,
                mc.category_name,
                mi.item_name
            `,
            [outletId]
        );

        return res.json({
            success: true,
            items
        });

    } catch (error) {

        console.error(
            'Get menu items error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get menu items'
        });
    }
};
*/

/*
 * GET /api/menu/items?outletId=1
 *
 * Returns active menu items + active variants.
 */
exports.getItems = async (req, res) => {

    const db = await conn.getConnection();

    try {

        const outletId = Number(
            req.query.outletId
        );

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        // ------------------------------------------------------
        // Verify user access to outlet
        // ------------------------------------------------------

        const [access] = await db.query(
            `
            SELECT 1

            FROM user_outlet uo

            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id

            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE

            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message:
                    'You are not authorized for this outlet'
            });
        }

        // ------------------------------------------------------
        // Load menu items
        // ------------------------------------------------------

        const [items] = await db.query(
            `
            SELECT
                mi.menu_item_id,
                mi.menu_item_uuid,
                mi.outlet_id,
                mi.menu_category_id,

                mc.category_code,
                mc.category_name,

                mi.item_code,
                mi.item_name,
                mi.description,
                mi.item_type,
                mi.base_rate,

                mi.tax_group_id,

                mi.is_veg,
                mi.is_egg,
                mi.is_spicy,

                mi.image_url,
                mi.barcode,

                mi.preparation_time_minutes,

                mi.allow_discount,
                mi.is_available,
                mi.is_active

            FROM menu_item mi

            INNER JOIN menu_category mc
                ON mc.menu_category_id =
                   mi.menu_category_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE

            ORDER BY
                mc.display_order,
                mc.category_name,
                mi.item_name
            `,
            [
                outletId
            ]
        );

        // ------------------------------------------------------
        // Load ALL active variants in one query
        // ------------------------------------------------------

        const [variants] = await db.query(
            `
            SELECT
                v.variant_id,
                v.variant_uuid,
                v.menu_item_id,
                v.variant_code,
                v.variant_name,
                v.rate,
                v.tax_group_id,
                v.display_order,
                v.is_default

            FROM menu_item_variant v

            INNER JOIN menu_item mi
                ON mi.menu_item_id =
                   v.menu_item_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE
              AND v.is_active = TRUE

            ORDER BY
                v.menu_item_id,
                v.display_order,
                v.variant_name
            `,
            [
                outletId
            ]
        );

        // ------------------------------------------------------
        // Group variants by menu_item_id
        // ------------------------------------------------------

        const variantsByItemId = new Map();

        for (const variant of variants) {

            const menuItemId =
                Number(variant.menu_item_id);

            if (!variantsByItemId.has(menuItemId)) {
                variantsByItemId.set(
                    menuItemId,
                    []
                );
            }

            variantsByItemId
                .get(menuItemId)
                .push({
                    variant_id:
                        variant.variant_id,

                    variant_uuid:
                        variant.variant_uuid,

                    menu_item_id:
                        variant.menu_item_id,

                    variant_code:
                        variant.variant_code,

                    variant_name:
                        variant.variant_name,

                    rate:
                        variant.rate,

                    tax_group_id:
                        variant.tax_group_id,

                    display_order:
                        variant.display_order,

                    is_default:
                        variant.is_default
                });
        }

        // ------------------------------------------------------
        // Attach variants to each item
        // ------------------------------------------------------

        const result = items.map(item => ({
            ...item,

            variants:
                variantsByItemId.get(
                    Number(item.menu_item_id)
                ) || []
        }));

        return res.json({
            success: true,
            items: result
        });

    } catch (error) {

        console.error(
            'Get menu items error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get menu items'
        });

    } finally {

        // IMPORTANT:
        // The old getItems implementation did not release
        // its connection.
        db.release();
    }
};

/*
 * GET
 * /api/menu/categories/:categoryId/items?outletId=1
 */
exports.getItemsByCategory = async (
    req,
    res
) => {
const db=await conn.getConnection();
    try {

        const outletId = Number(
            req.query.outletId
        );

        const categoryId = Number(
            req.params.categoryId
        );

        if (!outletId || !categoryId) {
            return res.status(400).json({
                success: false,
                message:
                    'outletId and categoryId are required'
            });
        }

        const [access] = await db.query(
            `
            SELECT 1
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE
            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        const [items] = await db.query(
            `
            SELECT
                mi.menu_item_id,
                mi.menu_item_uuid,
                mi.menu_category_id,

                mi.item_code,
                mi.item_name,
                mi.description,
                mi.item_type,
                mi.base_rate,

                mi.tax_group_id,

                mi.is_veg,
                mi.is_egg,
                mi.is_spicy,

                mi.image_url,
                mi.barcode,

                mi.preparation_time_minutes,

                mi.allow_discount,
                mi.is_available,
                mi.is_active

            FROM menu_item mi

            WHERE mi.outlet_id = ?
              AND mi.menu_category_id = ?
              AND mi.is_active = TRUE

            ORDER BY mi.item_name
            `,
            [
                outletId,
                categoryId
            ]
        );

        return res.json({
            success: true,
            items
        });

    } catch (error) {

        console.error(
            'Get items by category error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get menu items'
        });
    }
};


/*
 * GET /api/menu/items/:itemId?outletId=1
 *
 * Returns item + variants + modifier groups/options.
 *
 * This will be useful when we build the
 * item-selection popup.
 */
exports.getItem = async (req, res) => {
const db=await conn.getConnection();
    try {

        const outletId = Number(
            req.query.outletId
        );

        const itemId = Number(
            req.params.itemId
        );

        if (!outletId || !itemId) {
            return res.status(400).json({
                success: false,
                message:
                    'outletId and itemId are required'
            });
        }

        const [items] = await db.query(
            `
            SELECT
                mi.menu_item_id,
                mi.menu_item_uuid,
                mi.outlet_id,
                mi.menu_category_id,

                mc.category_name,

                mi.item_code,
                mi.item_name,
                mi.description,
                mi.item_type,
                mi.base_rate,

                mi.tax_group_id,

                mi.is_veg,
                mi.is_egg,
                mi.is_spicy,

                mi.image_url,
                mi.barcode,

                mi.preparation_time_minutes,

                mi.allow_discount,
                mi.is_available,
                mi.is_active

            FROM menu_item mi

            INNER JOIN menu_category mc
                ON mc.menu_category_id =
                   mi.menu_category_id

            WHERE mi.menu_item_id = ?
              AND mi.outlet_id = ?
              AND mi.is_active = TRUE

            LIMIT 1
            `,
            [
                itemId,
                outletId
            ]
        );

        if (items.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Menu item not found'
            });
        }

        const item = items[0];


        // ------------------------------------------
        // VARIANTS
        // ------------------------------------------

        const includeInactiveVariants =
        String(req.query.includeInactive || '') === '1';

        const activeFilter = includeInactiveVariants
          ? ''
          : ' AND is_active = TRUE';

        const [variants] = await db.query(
          `SELECT
              variant_id,
              variant_uuid,
              menu_item_id,
              variant_code,
              variant_name,
              rate,
              tax_group_id,
              display_order,
              is_default,
              is_active
           FROM menu_item_variant
           WHERE menu_item_id = ?${activeFilter}
           ORDER BY display_order, variant_name`,
          [itemId]
        );


        // ------------------------------------------
        // MODIFIER GROUPS
        // ------------------------------------------

        const [modifierGroups] = await db.query(
            `
            SELECT
                mg.modifier_group_id,
                mg.group_name,
                mg.selection_type,
                mg.min_selection,
                mg.max_selection,
                mg.display_order

            FROM menu_item_modifier mim

            INNER JOIN modifier_group mg
                ON mg.modifier_group_id =
                   mim.modifier_group_id

            WHERE mim.menu_item_id = ?
              AND mg.is_active = TRUE

            ORDER BY
                mg.display_order,
                mg.group_name
            `,
            [itemId]
        );


        // ------------------------------------------
        // MODIFIER OPTIONS
        // ------------------------------------------

        for (const group of modifierGroups) {

            const [options] = await db.query(
                `
                SELECT
                    modifier_option_id,
                    modifier_group_id,
                    option_name,
                    extra_rate,
                    tax_group_id,
                    display_order
                FROM modifier_option
                WHERE modifier_group_id = ?
                  AND is_active = TRUE
                ORDER BY
                    display_order,
                    option_name
                `,
                [group.modifier_group_id]
            );

            group.options = options;
        }


        return res.json({
            success: true,

            item: item,

            variants: variants,

            modifierGroups: modifierGroups
        });

    } catch (error) {

        console.error(
            'Get menu item error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get menu item'
        });
    }
};


// ============================================================
// UPDATE MENU ITEM
// PUT /menu/items/:menuItemId
// ============================================================

exports.updateItem = async (req, res) => {
    const db = await conn.getConnection();

    try {
        const menuItemId = Number(req.params.menuItemId);
        const outletId = Number(req.body.outletId);
        const menuCategoryId = Number(req.body.menuCategoryId);

        const itemCode = String(req.body.itemCode || '').trim();
        const itemName = String(req.body.itemName || '').trim();
        const itemType = String(req.body.itemType || 'FOOD')
            .trim()
            .toUpperCase();

        const baseRate = Number(req.body.baseRate);

        const taxGroupId =
            req.body.taxGroupId === null ||
            req.body.taxGroupId === undefined ||
            req.body.taxGroupId === ''
                ? null
                : Number(req.body.taxGroupId);

        const preparationTimeMinutes =
            Number(req.body.preparationTimeMinutes ?? 0);

        const toBool = (value) =>
            value === true || value === 1 || value === '1' ? 1 : 0;

        const description =
            String(req.body.description ?? '').trim() || null;

        const imageUrl =
            String(req.body.imageUrl ?? '').trim() || null;

        const barcode =
            String(req.body.barcode ?? '').trim() || null;

        // Basic validation
        if (
            !Number.isInteger(menuItemId) ||
            menuItemId <= 0 ||
            !Number.isInteger(outletId) ||
            outletId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid menuItemId and outletId are required'
            });
        }

        if (!Number.isInteger(menuCategoryId) || menuCategoryId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid menu category is required'
            });
        }

        if (!itemCode || !itemName) {
            return res.status(400).json({
                success: false,
                message: 'Item code and item name are required'
            });
        }

        if (!['FOOD', 'BEVERAGE',  'LIQUOR','SERVICE', 'OTHER'].includes(itemType)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid item type'
            });
        }

        if (!Number.isFinite(baseRate) || baseRate < 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid base rate is required'
            });
        }

        if (
            !Number.isInteger(preparationTimeMinutes) ||
            preparationTimeMinutes < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid preparation time'
            });
        }

        if (
            taxGroupId !== null &&
            (!Number.isInteger(taxGroupId) || taxGroupId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid tax group'
            });
        }

        // Verify user access to the outlet
        const [access] = await db.query(
            `
            SELECT 1
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE
            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        // Confirm the menu item belongs to this outlet
        const [existing] = await db.query(
            `
            SELECT menu_item_id
            FROM menu_item
            WHERE menu_item_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [menuItemId, outletId]
        );

        if (existing.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Menu item not found'
            });
        }

        // Validate category belongs to this outlet
        const [categories] = await db.query(
            `
            SELECT menu_category_id
            FROM menu_category
            WHERE menu_category_id = ?
              AND outlet_id = ?
              AND is_active = TRUE
            LIMIT 1
            `,
            [menuCategoryId, outletId]
        );

        if (categories.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid or inactive menu category'
            });
        }

        // Check duplicate item code, excluding the current item
        const [duplicates] = await db.query(
            `
            SELECT menu_item_id
            FROM menu_item
            WHERE outlet_id = ?
              AND item_code = ?
              AND menu_item_id <> ?
            LIMIT 1
            `,
            [outletId, itemCode, menuItemId]
        );

        if (duplicates.length > 0) {
            return res.status(409).json({
                success: false,
                message: 'This item code already exists'
            });
        }

        // Update the menu item
        await db.query(
            `
            UPDATE menu_item
            SET
                menu_category_id = ?,
                item_code = ?,
                item_name = ?,
                description = ?,
                item_type = ?,
                base_rate = ?,
                tax_group_id = ?,
                is_veg = ?,
                is_egg = ?,
                is_spicy = ?,
                image_url = ?,
                barcode = ?,
                preparation_time_minutes = ?,
                allow_discount = ?,
                is_available = ?,
                is_active = ?
            WHERE menu_item_id = ?
              AND outlet_id = ?
            `,
            [
                menuCategoryId,
                itemCode,
                itemName,
                description,
                itemType,
                baseRate,
                taxGroupId,
                toBool(req.body.isVeg),
                toBool(req.body.isEgg),
                toBool(req.body.isSpicy),
                imageUrl,
                barcode,
                preparationTimeMinutes,
                toBool(req.body.allowDiscount),
                toBool(req.body.isAvailable),
                toBool(req.body.isActive),
                menuItemId,
                outletId
            ]
        );

        return res.json({
            success: true,
            message: 'Menu item updated successfully'
        });

    } catch (error) {
        console.error('Update menu item error:', error);

        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message: 'This item code already exists'
            });
        }

        return res.status(500).json({
            success: false,
            message: 'Unable to update menu item'
        });

    } finally {
        db.release();
    }
};


// ============================================================
// CREATE MENU ITEM
// POST /menu/items
// ============================================================

exports.createItem = async (req, res) => {
    let db;

    try {
        db = await conn.getConnection();

        const outletId = Number(req.body.outletId);
        const menuCategoryId = Number(req.body.menuCategoryId);

        const itemCode = String(req.body.itemCode || '').trim();
        const itemName = String(req.body.itemName || '').trim();

        const description =
            String(req.body.description ?? '').trim() || null;

        const itemType = String(req.body.itemType || 'FOOD')
            .trim()
            .toUpperCase();

        const baseRate = Number(req.body.baseRate);

        const taxGroupId =
            req.body.taxGroupId === null ||
            req.body.taxGroupId === undefined ||
            req.body.taxGroupId === ''
                ? null
                : Number(req.body.taxGroupId);

        const preparationTimeMinutes =
            Number(req.body.preparationTimeMinutes ?? 0);

        const toBool = (value) =>
            value === true || value === 1 || value === '1' ? 1 : 0;

        const imageUrl =
            String(req.body.imageUrl ?? '').trim() || null;

        const barcode =
            String(req.body.barcode ?? '').trim() || null;

        // --------------------------------------------------
        // VALIDATION
        // --------------------------------------------------

        if (
            !Number.isInteger(outletId) ||
            outletId <= 0 ||
            !Number.isInteger(menuCategoryId) ||
            menuCategoryId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid outlet and menu category are required'
            });
        }

        if (!itemCode || !itemName) {
            return res.status(400).json({
                success: false,
                message: 'Item code and item name are required'
            });
        }

        if (!['FOOD', 'BEVERAGE', 'LIQUOR', 'SERVICE', 'OTHER'].includes(itemType)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid item type'
            });
        }

        if (!Number.isFinite(baseRate) || baseRate < 0) {
            return res.status(400).json({
                success: false,
                message: 'Enter a valid base rate'
            });
        }

        if (
            !Number.isInteger(preparationTimeMinutes) ||
            preparationTimeMinutes < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid preparation time'
            });
        }

        if (
            taxGroupId !== null &&
            (!Number.isInteger(taxGroupId) || taxGroupId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid tax group'
            });
        }

        // --------------------------------------------------
        // VERIFY USER ACCESS TO OUTLET
        // --------------------------------------------------

        const [access] = await db.query(
            `
            SELECT 1
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE
            LIMIT 1
            `,
            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        // --------------------------------------------------
        // VERIFY CATEGORY BELONGS TO OUTLET
        // --------------------------------------------------

        const [categories] = await db.query(
            `
            SELECT menu_category_id
            FROM menu_category
            WHERE menu_category_id = ?
              AND outlet_id = ?
              AND is_active = TRUE
            LIMIT 1
            `,
            [menuCategoryId, outletId]
        );

        if (categories.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid or inactive menu category'
            });
        }

        // --------------------------------------------------
        // CHECK DUPLICATE ITEM CODE
        // --------------------------------------------------

        const [duplicates] = await db.query(
            `
            SELECT menu_item_id
            FROM menu_item
            WHERE outlet_id = ?
              AND item_code = ?
            LIMIT 1
            `,
            [outletId, itemCode]
        );

        if (duplicates.length > 0) {
            return res.status(409).json({
                success: false,
                message: 'This item code already exists'
            });
        }

        // --------------------------------------------------
        // INSERT MENU ITEM
        // --------------------------------------------------

        const menuItemUuid = require('crypto').randomUUID();

        const [result] = await db.query(
            `
            INSERT INTO menu_item (
                menu_item_uuid,
                outlet_id,
                menu_category_id,
                item_code,
                item_name,
                description,
                item_type,
                base_rate,
                tax_group_id,
                is_veg,
                is_egg,
                is_spicy,
                image_url,
                barcode,
                preparation_time_minutes,
                allow_discount,
                is_available,
                is_active
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `,
            [
                menuItemUuid,
                outletId,
                menuCategoryId,
                itemCode,
                itemName,
                description,
                itemType,
                baseRate,
                taxGroupId,
                toBool(req.body.isVeg),
                toBool(req.body.isEgg),
                toBool(req.body.isSpicy),
                imageUrl,
                barcode,
                preparationTimeMinutes,
                toBool(req.body.allowDiscount),
                toBool(req.body.isAvailable),
                toBool(req.body.isActive)
            ]
        );

        return res.status(201).json({
            success: true,
            message: 'Menu item created successfully',
            menuItemId: result.insertId,
            menuItemUuid
        });

    } catch (error) {
        console.error('Create menu item error:', error);

        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message: 'This item code already exists'
            });
        }

        return res.status(500).json({
            success: false,
            message: 'Unable to create menu item'
        });

    } finally {
        if (db) {
            db.release();
        }
    }
};


// ============================================================
// SHARED VALIDATION FOR MENU ITEM VARIANTS
// ============================================================

function menuVariantError(message, statusCode = 400) {
    const error = new Error(message);
    error.statusCode = statusCode;
    return error;
}

function menuVariantBool(value, defaultValue = false) {
    if (value === undefined || value === null) {
        return defaultValue;
    }

    if (typeof value === 'boolean') {
        return value;
    }

    return ['1', 'true', 'yes'].includes(
        String(value).trim().toLowerCase()
    );
}

async function validateMenuVariantInput(
    db,
    req,
    menuItemId,
    variantId = null
) {
    const outletId = Number(req.body.outletId);

    const variantCode = String(
        req.body.variantCode || ''
    ).trim();

    const variantName = String(
        req.body.variantName || ''
    ).trim();

    const rate = Number(req.body.rate);

    const taxGroupId =
        req.body.taxGroupId === null ||
        req.body.taxGroupId === undefined ||
        req.body.taxGroupId === ''
            ? null
            : Number(req.body.taxGroupId);

    const displayOrder = Number(
        req.body.displayOrder ?? 0
    );

    const isActive = menuVariantBool(
        req.body.isActive,
        true
    );

    const isDefault =
        isActive &&
        menuVariantBool(req.body.isDefault, false);

    if (
        !Number.isInteger(menuItemId) ||
        menuItemId <= 0 ||
        !Number.isInteger(outletId) ||
        outletId <= 0
    ) {
        throw menuVariantError(
            'Valid menuItemId and outletId are required'
        );
    }

    if (!variantCode || !variantName) {
        throw menuVariantError(
            'Variant code and variant name are required'
        );
    }

    if (
        req.body.rate === undefined ||
        String(req.body.rate).trim() === '' ||
        !Number.isFinite(rate) ||
        rate < 0
    ) {
        throw menuVariantError('Enter a valid variant rate');
    }

    if (
        !Number.isInteger(displayOrder) ||
        displayOrder < 0
    ) {
        throw menuVariantError('Invalid display order');
    }

    if (
        taxGroupId !== null &&
        (!Number.isInteger(taxGroupId) || taxGroupId <= 0)
    ) {
        throw menuVariantError('Invalid tax group');
    }

    // Verify user access to the outlet.
    const [access] = await db.query(
        `
        SELECT 1
        FROM user_outlet uo
        INNER JOIN outlet o
            ON o.outlet_id = uo.outlet_id
        WHERE uo.user_id = ?
          AND uo.outlet_id = ?
          AND o.company_id = ?
          AND o.is_active = TRUE
        LIMIT 1
        `,
        [
            req.user.userId,
            outletId,
            req.user.companyId
        ]
    );

    if (access.length === 0) {
        throw menuVariantError(
            'You are not authorized for this outlet',
            403
        );
    }

    // Ensure the parent item belongs to this outlet.
    const [items] = await db.query(
        `
        SELECT menu_item_id
        FROM menu_item
        WHERE menu_item_id = ?
          AND outlet_id = ?
        LIMIT 1
        `,
        [menuItemId, outletId]
    );

    if (items.length === 0) {
        throw menuVariantError(
            'Menu item not found for this outlet',
            404
        );
    }

    // On update, ensure the variant belongs to the item.
    if (variantId !== null) {
        const [variants] = await db.query(
            `
            SELECT variant_id
            FROM menu_item_variant
            WHERE variant_id = ?
              AND menu_item_id = ?
            LIMIT 1
            `,
            [variantId, menuItemId]
        );

        if (variants.length === 0) {
            throw menuVariantError(
                'Variant not found for this menu item',
                404
            );
        }
    }

    // Validate optional tax group.
    if (taxGroupId !== null) {
        const [taxGroups] = await db.query(
            `
            SELECT tax_group_id
            FROM tax_group
            WHERE tax_group_id = ?
              AND is_active = TRUE
            LIMIT 1
            `,
            [taxGroupId]
        );

        if (taxGroups.length === 0) {
            throw menuVariantError(
                'Tax group not found or inactive'
            );
        }
    }

    // Check duplicate variant code for this menu item.
    let duplicateSql = `
        SELECT variant_id
        FROM menu_item_variant
        WHERE menu_item_id = ?
          AND variant_code = ?
    `;

    const duplicateParams = [
        menuItemId,
        variantCode
    ];

    if (variantId !== null) {
        duplicateSql += ' AND variant_id <> ?';
        duplicateParams.push(variantId);
    }

    duplicateSql += ' LIMIT 1';

    const [duplicates] = await db.query(
        duplicateSql,
        duplicateParams
    );

    if (duplicates.length > 0) {
        throw menuVariantError(
            'This variant code already exists for the menu item',
            409
        );
    }

    return {
        outletId,
        variantCode,
        variantName,
        rate,
        taxGroupId,
        displayOrder,
        isDefault,
        isActive
    };
}


// ============================================================
// CREATE MENU ITEM VARIANT
// POST /menu/items/:menuItemId/variants
// ============================================================

exports.createVariant = async (req, res) => {
    let db;
    let transactionStarted = false;

    try {
        db = await conn.getConnection();

        const menuItemId = Number(req.params.menuItemId);

        const data = await validateMenuVariantInput(
            db,
            req,
            menuItemId
        );

        await db.beginTransaction();
        transactionStarted = true;

        // Only one active default variant per menu item.
        if (data.isDefault) {
            await db.query(
                `
                UPDATE menu_item_variant
                SET is_default = FALSE
                WHERE menu_item_id = ?
                `,
                [menuItemId]
            );
        }

        const variantUuid = require('crypto').randomUUID();

        const [result] = await db.query(
            `
            INSERT INTO menu_item_variant (
                variant_uuid,
                menu_item_id,
                variant_code,
                variant_name,
                rate,
                tax_group_id,
                display_order,
                is_default,
                is_active
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            `,
            [
                variantUuid,
                menuItemId,
                data.variantCode,
                data.variantName,
                data.rate,
                data.taxGroupId,
                data.displayOrder,
                data.isDefault ? 1 : 0,
                data.isActive ? 1 : 0
            ]
        );

        await db.commit();
        transactionStarted = false;

        return res.status(201).json({
            success: true,
            message: 'Variant created successfully',
            variantId: result.insertId,
            variantUuid
        });

    } catch (error) {
        if (db && transactionStarted) {
            await db.rollback();
        }

        console.error('Create menu variant error:', error);

        return res.status(
            error.statusCode ||
            (error.code === 'ER_DUP_ENTRY' ? 409 : 500)
        ).json({
            success: false,
            message:
                error.code === 'ER_DUP_ENTRY'
                    ? 'This variant code already exists'
                    : error.message || 'Unable to create variant'
        });

    } finally {
        if (db) db.release();
    }
};


// ============================================================
// UPDATE MENU ITEM VARIANT
// PUT /menu/items/:menuItemId/variants/:variantId
// ============================================================

exports.updateVariant = async (req, res) => {
    let db;
    let transactionStarted = false;

    try {
        db = await conn.getConnection();

        const menuItemId = Number(req.params.menuItemId);
        const variantId = Number(req.params.variantId);

        if (
            !Number.isInteger(variantId) ||
            variantId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid variantId'
            });
        }

        const data = await validateMenuVariantInput(
            db,
            req,
            menuItemId,
            variantId
        );

        await db.beginTransaction();
        transactionStarted = true;

        if (data.isDefault) {
            await db.query(
                `
                UPDATE menu_item_variant
                SET is_default = FALSE
                WHERE menu_item_id = ?
                  AND variant_id <> ?
                `,
                [menuItemId, variantId]
            );
        }

        await db.query(
            `
            UPDATE menu_item_variant
            SET
                variant_code = ?,
                variant_name = ?,
                rate = ?,
                tax_group_id = ?,
                display_order = ?,
                is_default = ?,
                is_active = ?
            WHERE variant_id = ?
              AND menu_item_id = ?
            `,
            [
                data.variantCode,
                data.variantName,
                data.rate,
                data.taxGroupId,
                data.displayOrder,
                data.isDefault ? 1 : 0,
                data.isActive ? 1 : 0,
                variantId,
                menuItemId
            ]
        );

        await db.commit();
        transactionStarted = false;

        return res.json({
            success: true,
            message: 'Variant updated successfully'
        });

    } catch (error) {
        if (db && transactionStarted) {
            await db.rollback();
        }

        console.error('Update menu variant error:', error);

        return res.status(
            error.statusCode ||
            (error.code === 'ER_DUP_ENTRY' ? 409 : 500)
        ).json({
            success: false,
            message:
                error.code === 'ER_DUP_ENTRY'
                    ? 'This variant code already exists'
                    : error.message || 'Unable to update variant'
        });

    } finally {
        if (db) db.release();
    }
};