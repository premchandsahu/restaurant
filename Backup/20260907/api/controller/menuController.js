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

        const [variants] = await db.query(
            `
            SELECT
                variant_id,
                variant_uuid,
                menu_item_id,
                variant_code,
                variant_name,
                rate,
                tax_group_id,
                display_order,
                is_default
            FROM menu_item_variant
            WHERE menu_item_id = ?
              AND is_active = TRUE
            ORDER BY
                display_order,
                variant_name
            `,
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