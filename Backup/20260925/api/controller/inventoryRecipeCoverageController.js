const db = require('../database');

// ============================================================
// HELPER: CHECK OUTLET ACCESS
// ============================================================

async function getAuthorizedOutlet(
    connection,
    outletId,
    req
) {
    const [rows] = await connection.query(
        `
        SELECT
            o.outlet_id,
            o.company_id,
            o.outlet_name
        FROM outlet o
        INNER JOIN user_outlet uo
            ON uo.outlet_id = o.outlet_id
        WHERE o.outlet_id = ?
          AND o.company_id = ?
          AND o.is_active = TRUE
          AND uo.user_id = ?
        LIMIT 1
        `,
        [
            outletId,
            req.user.companyId,
            req.user.userId
        ]
    );

    return rows.length > 0 ? rows[0] : null;
}


// ============================================================
// SERIALIZE MYSQL DATE
// ============================================================

function serializeDate(value) {
    if (value === null || value === undefined) {
        return null;
    }

    if (typeof value === 'string') {
        return value.slice(0, 10);
    }

    if (value instanceof Date && !Number.isNaN(value.getTime())) {
        const year = value.getFullYear();
        const month = String(value.getMonth() + 1).padStart(2, '0');
        const day = String(value.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    return null;
}


// ============================================================
// VALIDATE DATE
// ============================================================

function isValidDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
    }

    const date = new Date(`${value}T00:00:00Z`);

    if (Number.isNaN(date.getTime())) {
        return false;
    }

    return date.toISOString().slice(0, 10) === value;
}


// ============================================================
// GET RECIPE COVERAGE
//
// GET /inventory/recipes/coverage?outletId=1&asOfDate=2026-09-30
//
// Purpose:
//   Show recipe coverage for every active menu item and every
//   active variant as of a particular business date.
//
// Coverage states:
//   CONFIGURED_EXACT  -> target has its own effective recipe.
//   USING_DEFAULT     -> variant has no exact recipe but the
//                        menu item's default recipe will be used.
//   MISSING           -> neither exact nor default recipe exists.
//
// This endpoint is READ-ONLY.
// ============================================================

exports.getRecipeCoverage = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const asOfDate =
            req.query.asOfDate
                ? String(req.query.asOfDate).trim()
                : new Date().toISOString().slice(0, 10);

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!isValidDate(asOfDate)) {
            return res.status(400).json({
                success: false,
                message: 'asOfDate must be YYYY-MM-DD'
            });
        }

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outletId,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message: 'You do not have access to this outlet'
            });
        }

        // ------------------------------------------------------
        // 1. Get active menu items.
        // ------------------------------------------------------

        const [menuItems] = await connection.query(
            `
            SELECT
                mi.menu_item_id,
                mi.item_code,
                mi.item_name,
                mi.item_type,
                mi.is_available
            FROM menu_item mi
            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE
            ORDER BY
                mi.item_name
            `,
            [outletId]
        );

        if (menuItems.length === 0) {
            return res.json({
                success: true,
                outletId,
                asOfDate,
                summary: {
                    menuItemCount: 0,
                    defaultRecipeTargets: 0,
                    variantRecipeTargets: 0,
                    configuredExactCount: 0,
                    fallbackToDefaultCount: 0,
                    missingCount: 0,
                    coverageComplete: true
                },
                rows: [],
                missingRecipes: []
            });
        }

        const menuItemIds = menuItems.map(
            item => item.menu_item_id
        );

        // ------------------------------------------------------
        // 2. Get active variants for these menu items.
        // ------------------------------------------------------

        const placeholders =
            menuItemIds.map(() => '?').join(', ');

        const [variants] = await connection.query(
            `
            SELECT
                v.variant_id,
                v.menu_item_id,
                v.variant_code,
                v.variant_name,
                v.is_default
            FROM menu_item_variant v
            WHERE v.menu_item_id IN (${placeholders})
              AND v.is_active = TRUE
            ORDER BY
                v.menu_item_id,
                v.display_order,
                v.variant_name
            `,
            menuItemIds
        );

        // ------------------------------------------------------
        // 3. Get every current recipe version for the date.
        //    We keep default and exact-variant recipes separate.
        // ------------------------------------------------------

        const [recipes] = await connection.query(
            `
            SELECT
                r.recipe_id,
                r.menu_item_id,
                r.variant_id,
                r.recipe_name,
                r.version_no,
                r.effective_from,
                r.effective_to,
                r.yield_qty,
                r.yield_unit_id,
                u.unit_code AS yield_unit_code,
                r.is_active,
                COUNT(ri.recipe_item_id) AS ingredient_count
            FROM recipe r
            LEFT JOIN recipe_item ri
                ON ri.recipe_id = r.recipe_id
            LEFT JOIN unit u
                ON u.unit_id = r.yield_unit_id
            WHERE r.menu_item_id IN (${placeholders})
              AND r.effective_from <= ?
              AND (
                    r.effective_to IS NULL
                    OR ? < r.effective_to
              )
            GROUP BY
                r.recipe_id,
                r.menu_item_id,
                r.variant_id,
                r.recipe_name,
                r.version_no,
                r.effective_from,
                r.effective_to,
                r.yield_qty,
                r.yield_unit_id,
                u.unit_code,
                r.is_active
            ORDER BY
                r.menu_item_id,
                r.variant_id,
                r.version_no DESC,
                r.recipe_id DESC
            `,
            [
                ...menuItemIds,
                asOfDate,
                asOfDate
            ]
        );

        const recipeMap = new Map();

        for (const recipe of recipes) {
            if (!recipe.is_active) {
                continue;
            }

            const key =
                `${recipe.menu_item_id}|${recipe.variant_id === null ? 'NULL' : recipe.variant_id}`;

            if (!recipeMap.has(key)) {
                recipeMap.set(key, recipe);
            }
        }

        const variantsByMenuItem = new Map();

        for (const variant of variants) {
            if (!variantsByMenuItem.has(variant.menu_item_id)) {
                variantsByMenuItem.set(
                    variant.menu_item_id,
                    []
                );
            }

            variantsByMenuItem
                .get(variant.menu_item_id)
                .push(variant);
        }

        const rows = [];
        const missingRecipes = [];

        let defaultRecipeTargets = 0;
        let variantRecipeTargets = 0;
        let configuredExactCount = 0;
        let fallbackToDefaultCount = 0;
        let missingCount = 0;

        for (const menuItem of menuItems) {
            // --------------------------------------------------
            // DEFAULT / BASE RECIPE TARGET
            // --------------------------------------------------

            defaultRecipeTargets++;

            const defaultKey =
                `${menuItem.menu_item_id}|NULL`;

            const defaultRecipe =
                recipeMap.get(defaultKey) || null;

            if (defaultRecipe) {
                configuredExactCount++;

                rows.push({
                    menuItemId:
                        menuItem.menu_item_id,
                    itemCode:
                        menuItem.item_code,
                    itemName:
                        menuItem.item_name,
                    itemType:
                        menuItem.item_type,
                    isAvailable:
                        Boolean(menuItem.is_available),
                    variantId: null,
                    variantCode: null,
                    variantName: null,
                    coverageType: 'DEFAULT',
                    coverageStatus: 'CONFIGURED_EXACT',
                    recipe: {
                        recipeId:
                            defaultRecipe.recipe_id,
                        recipeName:
                            defaultRecipe.recipe_name,
                        versionNo:
                            Number(defaultRecipe.version_no || 0),
                        effectiveFrom:
                            serializeDate(defaultRecipe.effective_from),
                        effectiveTo:
                            serializeDate(defaultRecipe.effective_to),
                        yieldQty:
                            Number(defaultRecipe.yield_qty || 0),
                        yieldUnitId:
                            defaultRecipe.yield_unit_id,
                        yieldUnitCode:
                            defaultRecipe.yield_unit_code,
                        ingredientCount:
                            Number(defaultRecipe.ingredient_count || 0)
                    }
                });
            } else {
                missingCount++;

                const row = {
                    menuItemId:
                        menuItem.menu_item_id,
                    itemCode:
                        menuItem.item_code,
                    itemName:
                        menuItem.item_name,
                    itemType:
                        menuItem.item_type,
                    isAvailable:
                        Boolean(menuItem.is_available),
                    variantId: null,
                    variantCode: null,
                    variantName: null,
                    coverageType: 'DEFAULT',
                    coverageStatus: 'MISSING',
                    recipe: null
                };

                rows.push(row);

                missingRecipes.push({
                    menuItemId:
                        menuItem.menu_item_id,
                    itemCode:
                        menuItem.item_code,
                    itemName:
                        menuItem.item_name,
                    variantId: null,
                    variantName: null,
                    reason: 'DEFAULT_RECIPE_MISSING'
                });
            }

            // --------------------------------------------------
            // VARIANT RECIPE TARGETS
            // --------------------------------------------------

            const itemVariants =
                variantsByMenuItem.get(
                    menuItem.menu_item_id
                ) || [];

            for (const variant of itemVariants) {
                variantRecipeTargets++;

                const exactKey =
                    `${menuItem.menu_item_id}|${variant.variant_id}`;

                const exactRecipe =
                    recipeMap.get(exactKey) || null;

                if (exactRecipe) {
                    configuredExactCount++;

                    rows.push({
                        menuItemId:
                            menuItem.menu_item_id,
                        itemCode:
                            menuItem.item_code,
                        itemName:
                            menuItem.item_name,
                        itemType:
                            menuItem.item_type,
                        isAvailable:
                            Boolean(menuItem.is_available),
                        variantId:
                            variant.variant_id,
                        variantCode:
                            variant.variant_code,
                        variantName:
                            variant.variant_name,
                        coverageType: 'VARIANT',
                        coverageStatus: 'CONFIGURED_EXACT',
                        recipe: {
                            recipeId:
                                exactRecipe.recipe_id,
                            recipeName:
                                exactRecipe.recipe_name,
                            versionNo:
                                Number(exactRecipe.version_no || 0),
                            effectiveFrom:
                                serializeDate(exactRecipe.effective_from),
                            effectiveTo:
                                serializeDate(exactRecipe.effective_to),
                            yieldQty:
                                Number(exactRecipe.yield_qty || 0),
                            yieldUnitId:
                                exactRecipe.yield_unit_id,
                            yieldUnitCode:
                                exactRecipe.yield_unit_code,
                            ingredientCount:
                                Number(exactRecipe.ingredient_count || 0)
                        }
                    });

                    continue;
                }

                if (defaultRecipe) {
                    fallbackToDefaultCount++;

                    rows.push({
                        menuItemId:
                            menuItem.menu_item_id,
                        itemCode:
                            menuItem.item_code,
                        itemName:
                            menuItem.item_name,
                        itemType:
                            menuItem.item_type,
                        isAvailable:
                            Boolean(menuItem.is_available),
                        variantId:
                            variant.variant_id,
                        variantCode:
                            variant.variant_code,
                        variantName:
                            variant.variant_name,
                        coverageType: 'VARIANT',
                        coverageStatus: 'USING_DEFAULT',
                        recipe: {
                            recipeId:
                                defaultRecipe.recipe_id,
                            recipeName:
                                defaultRecipe.recipe_name,
                            versionNo:
                                Number(defaultRecipe.version_no || 0),
                            effectiveFrom:
                                serializeDate(defaultRecipe.effective_from),
                            effectiveTo:
                                serializeDate(defaultRecipe.effective_to),
                            yieldQty:
                                Number(defaultRecipe.yield_qty || 0),
                            yieldUnitId:
                                defaultRecipe.yield_unit_id,
                            yieldUnitCode:
                                defaultRecipe.yield_unit_code,
                            ingredientCount:
                                Number(defaultRecipe.ingredient_count || 0)
                        },
                        fallbackReason:
                            'VARIANT_RECIPE_MISSING_USING_DEFAULT'
                    });

                    continue;
                }

                missingCount++;

                rows.push({
                    menuItemId:
                        menuItem.menu_item_id,
                    itemCode:
                        menuItem.item_code,
                    itemName:
                        menuItem.item_name,
                    itemType:
                        menuItem.item_type,
                    isAvailable:
                        Boolean(menuItem.is_available),
                    variantId:
                        variant.variant_id,
                    variantCode:
                        variant.variant_code,
                    variantName:
                        variant.variant_name,
                    coverageType: 'VARIANT',
                    coverageStatus: 'MISSING',
                    recipe: null
                });

                missingRecipes.push({
                    menuItemId:
                        menuItem.menu_item_id,
                    itemCode:
                        menuItem.item_code,
                    itemName:
                        menuItem.item_name,
                    variantId:
                        variant.variant_id,
                    variantCode:
                        variant.variant_code,
                    variantName:
                        variant.variant_name,
                    reason:
                        'VARIANT_AND_DEFAULT_RECIPE_MISSING'
                });
            }
        }

        return res.json({
            success: true,
            outletId,
            asOfDate,
            summary: {
                menuItemCount: menuItems.length,
                defaultRecipeTargets,
                variantRecipeTargets,
                configuredExactCount,
                fallbackToDefaultCount,
                missingCount,
                coverageComplete: missingCount === 0
            },
            rows,
            missingRecipes
        });

    } catch (error) {
        console.error(
            'Get recipe coverage error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get recipe coverage'
        });

    } finally {
        connection.release();
    }
};
