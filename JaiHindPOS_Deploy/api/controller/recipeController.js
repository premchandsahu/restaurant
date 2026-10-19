const db = require('../database');
const crypto = require('crypto');

function toBool(value, defaultValue = true) {
    if (value === undefined || value === null || value === '') {
        return defaultValue;
    }

    return ['true', '1', 'yes'].includes(String(value).toLowerCase());
}

function numberOrZero(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
}

function validatePositiveNumber(value, fieldName, allowZero = false) {
    const n = Number(value);

    if (!Number.isFinite(n) || (allowZero ? n < 0 : n <= 0)) {
        throw new Error(`${fieldName} must be ${allowZero ? 'zero or greater' : 'greater than zero'}`);
    }

    return n;
}

async function getAuthorizedMenuItem(connection, outletId, menuItemId, req) {
    const [rows] = await connection.query(
        `
        SELECT
            mi.menu_item_id,
            mi.item_code,
            mi.item_name,
            mi.outlet_id
        FROM menu_item mi
        INNER JOIN outlet o
            ON o.outlet_id = mi.outlet_id
        INNER JOIN user_outlet uo
            ON uo.outlet_id = mi.outlet_id
        WHERE mi.menu_item_id = ?
          AND mi.outlet_id = ?
          AND mi.is_active = 1
          AND o.company_id = ?
          AND o.is_active = 1
          AND uo.user_id = ?
        LIMIT 1
        `,
        [menuItemId, outletId, req.user.companyId, req.user.userId]
    );

    return rows[0] || null;
}

async function validateVariant(connection, menuItemId, variantId) {
    if (variantId === null || variantId === undefined || variantId === '') {
        return null;
    }

    const [rows] = await connection.query(
        `
        SELECT
            variant_id,
            menu_item_id,
            variant_code,
            variant_name,
            rate,
            is_active
        FROM menu_item_variant
        WHERE variant_id = ?
          AND menu_item_id = ?
        LIMIT 1
        `,
        [variantId, menuItemId]
    );

    if (!rows.length || !rows[0].is_active) {
        throw new Error('Invalid or inactive variant for the selected menu item');
    }

    return rows[0];
}

async function validateUnit(connection, unitId) {
    const [rows] = await connection.query(
        `
        SELECT
            unit_id,
            unit_code,
            unit_name,
            decimal_places
        FROM unit
        WHERE unit_id = ?
        LIMIT 1
        `,
        [unitId]
    );

    if (!rows.length) {
        throw new Error(`Invalid unitId: ${unitId}`);
    }

    return rows[0];
}

async function validateRawMaterial(connection, outletId, rawMaterialId) {
    const [rows] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
            rm.material_code,
            rm.material_name,
            rm.outlet_id,
            rm.unit_id AS stock_unit_id,
            u.unit_code AS stock_unit_code,
            u.unit_name AS stock_unit_name
        FROM raw_material rm
        INNER JOIN unit u
            ON u.unit_id = rm.unit_id
        WHERE rm.raw_material_id = ?
          AND rm.outlet_id = ?
          AND rm.is_active = 1
        LIMIT 1
        `,
        [rawMaterialId, outletId]
    );

    if (!rows.length) {
        throw new Error(`Invalid or inactive rawMaterialId: ${rawMaterialId}`);
    }

    return rows[0];
}

async function validateModifierOption(connection, modifierOptionId) {
    const [rows] = await connection.query(
        `
        SELECT
            mo.modifier_option_id,
            mo.modifier_group_id,
            mo.option_name,
            mo.is_active,
            mg.outlet_id,
            mg.group_name
        FROM modifier_option mo
        INNER JOIN modifier_group mg
            ON mg.modifier_group_id = mo.modifier_group_id
        WHERE mo.modifier_option_id = ?
        LIMIT 1
        `,
        [modifierOptionId]
    );

    if (!rows.length || !rows[0].is_active) {
        throw new Error(`Invalid or inactive modifierOptionId: ${modifierOptionId}`);
    }

    return rows[0];
}

function mapRecipe(row, items) {
    return {
        recipeId: row.recipe_id,
        recipeUuid: row.recipe_uuid,
        menuItemId: row.menu_item_id,
        itemCode: row.item_code,
        itemName: row.item_name,
        variantId: row.variant_id,
        variantCode: row.variant_code,
        variantName: row.variant_name,
        recipeName: row.recipe_name,
        versionNo: Number(row.version_no || 1),
        effectiveFrom: row.effective_from,
        effectiveTo: row.effective_to,
        yieldQty: Number(row.yield_qty || 0),
        yieldUnitId: row.yield_unit_id,
        yieldUnitCode: row.yield_unit_code,
        yieldUnitName: row.yield_unit_name,
        isActive: Boolean(row.is_active),
        items: items.map(item => ({
            recipeItemId: item.recipe_item_id,
            rawMaterialId: item.raw_material_id,
            materialCode: item.material_code,
            materialName: item.material_name,
            qty: Number(item.qty || 0),
            unitId: item.unit_id,
            unitCode: item.unit_code,
            unitName: item.unit_name,
            stockUnitId: item.stock_unit_id,
            stockUnitCode: item.stock_unit_code,
            stockUnitName: item.stock_unit_name,
            wastagePercent: Number(item.wastage_percent || 0)
        })),
    };
}

async function loadRecipe(connection, recipeId, outletId, req) {
    const [rows] = await connection.query(
        `
        SELECT
            r.recipe_id,
            r.recipe_uuid,
            r.menu_item_id,
            mi.item_code,
            mi.item_name,
            r.variant_id,
            miv.variant_code,
            miv.variant_name,
            r.recipe_name,
            r.version_no,
            DATE_FORMAT(r.effective_from, '%Y-%m-%d') AS effective_from,
            DATE_FORMAT(r.effective_to, '%Y-%m-%d') AS effective_to,
            r.yield_qty,
            r.yield_unit_id,
            yu.unit_code AS yield_unit_code,
            yu.unit_name AS yield_unit_name,
            r.is_active
        FROM recipe r
        INNER JOIN menu_item mi
            ON mi.menu_item_id = r.menu_item_id
        INNER JOIN outlet o
            ON o.outlet_id = mi.outlet_id
        INNER JOIN user_outlet uo
            ON uo.outlet_id = mi.outlet_id
        LEFT JOIN menu_item_variant miv
            ON miv.variant_id = r.variant_id
        LEFT JOIN unit yu
            ON yu.unit_id = r.yield_unit_id
        WHERE r.recipe_id = ?
          AND mi.outlet_id = ?
          AND o.company_id = ?
          AND o.is_active = 1
          AND uo.user_id = ?
        LIMIT 1
        `,
        [recipeId, outletId, req.user.companyId, req.user.userId]
    );

    if (!rows.length) {
        return null;
    }

    const [items] = await connection.query(
        `
        SELECT
            ri.recipe_item_id,
            ri.raw_material_id,
            rm.material_code,
            rm.material_name,
            ri.qty,
            ri.unit_id,
            u.unit_code,
            u.unit_name,
            rm.unit_id AS stock_unit_id,
            su.unit_code AS stock_unit_code,
            su.unit_name AS stock_unit_name,
            ri.wastage_percent
        FROM recipe_item ri
        INNER JOIN raw_material rm
            ON rm.raw_material_id = ri.raw_material_id
        INNER JOIN unit u
            ON u.unit_id = ri.unit_id
        INNER JOIN unit su
            ON su.unit_id = rm.unit_id
        WHERE ri.recipe_id = ?
        ORDER BY ri.recipe_item_id
        `,
        [recipeId]
    );

    // Modifier recipes are maintained separately in the next inventory phase.

    return mapRecipe(rows[0], items);
}

async function validateItems(connection, outletId, items, req) {
    if (!Array.isArray(items) || items.length === 0) {
        throw new Error('At least one recipe item is required');
    }

    const seen = new Set();
    const result = [];

    for (const item of items) {
        const rawMaterialId = Number(item.rawMaterialId);
        const unitId = Number(item.unitId);
        const key = `${rawMaterialId}`;

        if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
            throw new Error('Valid rawMaterialId is required for every recipe item');
        }

        if (!Number.isInteger(unitId) || unitId <= 0) {
            throw new Error('Valid unitId is required for every recipe item');
        }

        if (seen.has(key)) {
            throw new Error(`Duplicate rawMaterialId in recipe: ${rawMaterialId}`);
        }
        seen.add(key);

        const rawMaterial = await validateRawMaterial(connection, outletId, rawMaterialId);
        const unit = await validateUnit(connection, unitId);
        const qty = validatePositiveNumber(item.qty, 'Recipe item qty');
        const wastagePercent = numberOrZero(item.wastagePercent);

        if (wastagePercent < 0 || wastagePercent > 100) {
            throw new Error('wastagePercent must be between 0 and 100');
        }

        result.push({
            rawMaterial,
            unit,
            qty,
            wastagePercent
        });
    }

    return result;
}

// ============================================================
// GET RECIPES
// GET /inventory/recipes?outletId=1
// Optional: menuItemId, variantId, active, search, history=true
//
// Default behavior returns the recipe version effective today.
// history=true returns all versions.
// ============================================================
exports.getRecipes = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        const params = [outletId, req.user.companyId, req.user.userId];
        let conditions = '';

        if (req.query.menuItemId) {
            const menuItemId = Number(req.query.menuItemId);
            if (!Number.isInteger(menuItemId) || menuItemId <= 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid menuItemId'
                });
            }
            conditions += ' AND r.menu_item_id = ? ';
            params.push(menuItemId);
        }

        if (req.query.variantId !== undefined && req.query.variantId !== '') {
            if (String(req.query.variantId).toLowerCase() === 'null') {
                conditions += ' AND r.variant_id IS NULL ';
            } else {
                const variantId = Number(req.query.variantId);
                if (!Number.isInteger(variantId) || variantId <= 0) {
                    return res.status(400).json({
                        success: false,
                        message: 'Invalid variantId'
                    });
                }
                conditions += ' AND r.variant_id = ? ';
                params.push(variantId);
            }
        }

        if (req.query.active !== undefined && req.query.active !== '') {
            conditions += ' AND r.is_active = ? ';
            params.push(toBool(req.query.active) ? 1 : 0);
        }

        if (req.query.search) {
            conditions += ' AND (r.recipe_name LIKE ? OR mi.item_name LIKE ? OR mi.item_code LIKE ?) ';
            const search = `%${String(req.query.search).trim()}%`;
            params.push(search, search, search);
        }

        const history = toBool(req.query.history, false);
        if (!history) {
            // Show only the recipe version effective today.
            conditions += `
                AND r.effective_from <= CURDATE()
                AND (r.effective_to IS NULL OR CURDATE() < r.effective_to)
            `;
        }

        const [rows] = await connection.query(
            `
            SELECT
                r.recipe_id,
                r.recipe_uuid,
                r.menu_item_id,
                mi.item_code,
                mi.item_name,
                r.variant_id,
                miv.variant_code,
                miv.variant_name,
                r.recipe_name,
                r.version_no,
                DATE_FORMAT(r.effective_from, '%Y-%m-%d') AS effective_from,
                DATE_FORMAT(r.effective_to, '%Y-%m-%d') AS effective_to,
                r.yield_qty,
                r.yield_unit_id,
                yu.unit_code AS yield_unit_code,
                yu.unit_name AS yield_unit_name,
                r.is_active
            FROM recipe r
            INNER JOIN menu_item mi
                ON mi.menu_item_id = r.menu_item_id
            INNER JOIN outlet o
                ON o.outlet_id = mi.outlet_id
            INNER JOIN user_outlet uo
                ON uo.outlet_id = mi.outlet_id
            LEFT JOIN menu_item_variant miv
                ON miv.variant_id = r.variant_id
            LEFT JOIN unit yu
                ON yu.unit_id = r.yield_unit_id
            WHERE mi.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = 1
              AND uo.user_id = ?
              ${conditions}
            ORDER BY
                mi.item_name,
                COALESCE(miv.display_order, 999999),
                r.version_no DESC,
                r.recipe_name
            `,
            params
        );

        return res.json({
            success: true,
            recipes: rows.map(row => ({
                recipeId: row.recipe_id,
                recipeUuid: row.recipe_uuid,
                menuItemId: row.menu_item_id,
                itemCode: row.item_code,
                itemName: row.item_name,
                variantId: row.variant_id,
                variantCode: row.variant_code,
                variantName: row.variant_name,
                recipeName: row.recipe_name,
                versionNo: Number(row.version_no || 1),
                effectiveFrom: row.effective_from,
                effectiveTo: row.effective_to,
                yieldQty: Number(row.yield_qty || 0),
                yieldUnitId: row.yield_unit_id,
                yieldUnitCode: row.yield_unit_code,
                yieldUnitName: row.yield_unit_name,
                isActive: Boolean(row.is_active)
            }))
        });
    } catch (error) {
        console.error('Get recipes error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to get recipes'
        });
    } finally {
        connection.release();
    }
};

// ============================================================
// GET RECIPE DETAIL
// GET /inventory/recipes/:recipeId?outletId=1
// ============================================================
exports.getRecipe = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const recipeId = Number(req.params.recipeId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid outletId is required' });
        }

        if (!Number.isInteger(recipeId) || recipeId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid recipeId is required' });
        }

        const recipe = await loadRecipe(connection, recipeId, outletId, req);

        if (!recipe) {
            return res.status(404).json({
                success: false,
                message: 'Recipe not found'
            });
        }

        return res.json({ success: true, recipe });
    } catch (error) {
        console.error('Get recipe error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to get recipe'
        });
    } finally {
        connection.release();
    }
};

function parseDateOnly(value, fieldName) {
    const text = String(value || '').trim();

    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
        throw new Error(`${fieldName} must be in YYYY-MM-DD format`);
    }

    const date = new Date(`${text}T00:00:00Z`);

    if (
        Number.isNaN(date.getTime()) ||
        date.toISOString().slice(0, 10) !== text
    ) {
        throw new Error(`Invalid ${fieldName}`);
    }

    return text;
}

async function getDatabaseToday(connection) {
    const [rows] = await connection.query(
        `SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS today`
    );

    return rows[0].today;
}

async function insertRecipeItems(connection, recipeId, validatedItems) {
    for (const item of validatedItems) {
        await connection.query(
            `
            INSERT INTO recipe_item (
                recipe_id,
                raw_material_id,
                qty,
                unit_id,
                wastage_percent
            ) VALUES (?, ?, ?, ?, ?)
            `,
            [
                recipeId,
                item.rawMaterial.raw_material_id,
                item.qty,
                item.unit.unit_id,
                item.wastagePercent
            ]
        );
    }
}

async function getRecipeVersionsForUpdate(connection, menuItemId, variantId) {
    const [rows] = await connection.query(
        `
        SELECT
            recipe_id,
            recipe_uuid,
            menu_item_id,
            variant_id,
            recipe_name,
            version_no,
            effective_from,
            effective_to,
            yield_qty,
            yield_unit_id,
            is_active
        FROM recipe
        WHERE menu_item_id = ?
          AND (
              (variant_id = ?)
              OR (variant_id IS NULL AND ? IS NULL)
          )
        ORDER BY version_no DESC, recipe_id DESC
        FOR UPDATE
        `,
        [menuItemId, variantId, variantId]
    );

    return rows;
}

// ============================================================
// CREATE RECIPE
// POST /inventory/recipes
//
// New field:
//   effectiveFrom (optional; defaults to today)
// ============================================================
exports.createRecipe = async (req, res) => {
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        const outletId = Number(req.body.outletId);
        const menuItemId = Number(req.body.menuItemId);
        const variantId = req.body.variantId === null || req.body.variantId === undefined || req.body.variantId === ''
            ? null
            : Number(req.body.variantId);
        const recipeName = String(req.body.recipeName || '').trim();
        const yieldQty = validatePositiveNumber(req.body.yieldQty, 'yieldQty');
        const yieldUnitId = req.body.yieldUnitId === null || req.body.yieldUnitId === undefined || req.body.yieldUnitId === ''
            ? null
            : Number(req.body.yieldUnitId);
        const isActive = toBool(req.body.isActive, true);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            throw new Error('Valid outletId is required');
        }
        if (!Number.isInteger(menuItemId) || menuItemId <= 0) {
            throw new Error('Valid menuItemId is required');
        }
        if (!recipeName) {
            throw new Error('recipeName is required');
        }
        if (yieldUnitId !== null) {
            await validateUnit(connection, yieldUnitId);
        }

        const menuItem = await getAuthorizedMenuItem(connection, outletId, menuItemId, req);
        if (!menuItem) {
            throw new Error('Menu item not found or not authorized for the selected outlet');
        }

        await validateVariant(connection, menuItemId, variantId);

        const effectiveFrom = req.body.effectiveFrom
            ? parseDateOnly(req.body.effectiveFrom, 'effectiveFrom')
            : await getDatabaseToday(connection);

        const versions = await getRecipeVersionsForUpdate(
            connection,
            menuItemId,
            variantId
        );

        if (versions.length) {
            const error = new Error(
                'A recipe history already exists for the selected menu item and variant. Use PUT to create a new recipe version.'
            );
            error.statusCode = 409;
            throw error;
        }

        const validatedItems = await validateItems(
            connection,
            outletId,
            req.body.items,
            req
        );

        const recipeUuid = crypto.randomUUID();

        const [recipeResult] = await connection.query(
            `
            INSERT INTO recipe (
                recipe_uuid,
                menu_item_id,
                variant_id,
                version_no,
                effective_from,
                effective_to,
                recipe_name,
                yield_qty,
                yield_unit_id,
                is_active
            ) VALUES (?, ?, ?, 1, ?, NULL, ?, ?, ?, ?)
            `,
            [
                recipeUuid,
                menuItemId,
                variantId,
                effectiveFrom,
                recipeName,
                yieldQty,
                yieldUnitId,
                isActive ? 1 : 0
            ]
        );

        const recipeId = recipeResult.insertId;

        await insertRecipeItems(connection, recipeId, validatedItems);

        await connection.commit();

        const recipe = await loadRecipe(connection, recipeId, outletId, req);

        return res.status(201).json({
            success: true,
            message: 'Recipe created successfully',
            recipe
        });
    } catch (error) {
        await connection.rollback();
        console.error('Create recipe error:', error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || 'Unable to create recipe'
        });
    } finally {
        connection.release();
    }
};

// ============================================================
// UPDATE RECIPE
// PUT /inventory/recipes/:recipeId
//
// SCD Type 2 behavior:
//   - Historical/closed versions are read-only.
//   - Updating the latest version creates a new version when
//     effectiveFrom is later than the current effective_from.
//   - When the latest version itself starts today, an update on
//     the same effective date amends that current version in place.
// ============================================================
exports.updateRecipe = async (req, res) => {
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        const outletId = Number(req.body.outletId);
        const recipeId = Number(req.params.recipeId);
        const menuItemId = Number(req.body.menuItemId);
        const variantId = req.body.variantId === null || req.body.variantId === undefined || req.body.variantId === ''
            ? null
            : Number(req.body.variantId);
        const recipeName = String(req.body.recipeName || '').trim();
        const yieldQty = validatePositiveNumber(req.body.yieldQty, 'yieldQty');
        const yieldUnitId = req.body.yieldUnitId === null || req.body.yieldUnitId === undefined || req.body.yieldUnitId === ''
            ? null
            : Number(req.body.yieldUnitId);
        const isActive = toBool(req.body.isActive, true);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            throw new Error('Valid outletId is required');
        }
        if (!Number.isInteger(recipeId) || recipeId <= 0) {
            throw new Error('Valid recipeId is required');
        }
        if (!Number.isInteger(menuItemId) || menuItemId <= 0) {
            throw new Error('Valid menuItemId is required');
        }
        if (!recipeName) {
            throw new Error('recipeName is required');
        }
        if (yieldUnitId !== null) {
            await validateUnit(connection, yieldUnitId);
        }

        const [currentRows] = await connection.query(
            `
            SELECT
                r.recipe_id,
                r.recipe_uuid,
                r.menu_item_id,
                r.variant_id,
                r.recipe_name,
                r.version_no,
                DATE_FORMAT(r.effective_from, '%Y-%m-%d') AS effective_from,
                DATE_FORMAT(r.effective_to, '%Y-%m-%d') AS effective_to,
                r.yield_qty,
                r.yield_unit_id,
                r.is_active
            FROM recipe r
            INNER JOIN menu_item mi
                ON mi.menu_item_id = r.menu_item_id
            INNER JOIN outlet o
                ON o.outlet_id = mi.outlet_id
            INNER JOIN user_outlet uo
                ON uo.outlet_id = mi.outlet_id
            WHERE r.recipe_id = ?
              AND mi.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = 1
              AND uo.user_id = ?
            FOR UPDATE
            `,
            [recipeId, outletId, req.user.companyId, req.user.userId]
        );

        if (!currentRows.length) {
            const error = new Error('Recipe not found or not authorized');
            error.statusCode = 404;
            throw error;
        }

        const current = currentRows[0];

        if (current.effective_to !== null) {
            const error = new Error(
                'Historical recipe versions are read-only. Update the latest recipe version instead.'
            );
            error.statusCode = 409;
            throw error;
        }

        if (
            current.menu_item_id !== menuItemId ||
            !(
                (current.variant_id === variantId) ||
                (current.variant_id === null && variantId === null)
            )
        ) {
            throw new Error(
                'menuItemId and variantId cannot be changed when creating a new recipe version. Create a separate recipe instead.'
            );
        }

        const menuItem = await getAuthorizedMenuItem(connection, outletId, menuItemId, req);
        if (!menuItem) {
            throw new Error('Menu item not found or not authorized for the selected outlet');
        }

        await validateVariant(connection, menuItemId, variantId);

        const effectiveFrom = req.body.effectiveFrom
            ? parseDateOnly(req.body.effectiveFrom, 'effectiveFrom')
            : await getDatabaseToday(connection);

        const today = await getDatabaseToday(connection);

        const validatedItems = await validateItems(
            connection,
            outletId,
            req.body.items,
            req
        );

        // Same-day edit of a recipe that itself starts today is safe to
        // amend in place: there is no earlier effective date in this version.
        if (
            effectiveFrom === current.effective_from &&
            effectiveFrom === today
        ) {
            await connection.query(
                `
                UPDATE recipe
                SET
                    recipe_name = ?,
                    yield_qty = ?,
                    yield_unit_id = ?,
                    is_active = ?
                WHERE recipe_id = ?
                `,
                [
                    recipeName,
                    yieldQty,
                    yieldUnitId,
                    isActive ? 1 : 0,
                    recipeId
                ]
            );

            await connection.query(
                `DELETE FROM recipe_item WHERE recipe_id = ?`,
                [recipeId]
            );

            await insertRecipeItems(connection, recipeId, validatedItems);

            await connection.commit();

            const recipe = await loadRecipe(connection, recipeId, outletId, req);

            return res.json({
                success: true,
                message: 'Recipe updated successfully',
                recipe
            });
        }

        if (effectiveFrom <= current.effective_from) {
            throw new Error(
                `effectiveFrom must be after the current version start date ${current.effective_from}`
            );
        }

        const newVersionNo = Number(current.version_no || 1) + 1;

        // Close the current version at the new version start date.
        await connection.query(
            `
            UPDATE recipe
            SET effective_to = ?
            WHERE recipe_id = ?
              AND effective_to IS NULL
            `,
            [effectiveFrom, recipeId]
        );

        const recipeUuid = crypto.randomUUID();

        const [recipeResult] = await connection.query(
            `
            INSERT INTO recipe (
                recipe_uuid,
                menu_item_id,
                variant_id,
                version_no,
                effective_from,
                effective_to,
                recipe_name,
                yield_qty,
                yield_unit_id,
                is_active
            ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?)
            `,
            [
                recipeUuid,
                menuItemId,
                variantId,
                newVersionNo,
                effectiveFrom,
                recipeName,
                yieldQty,
                yieldUnitId,
                isActive ? 1 : 0
            ]
        );

        const newRecipeId = recipeResult.insertId;

        await insertRecipeItems(connection, newRecipeId, validatedItems);

        await connection.commit();

        const recipe = await loadRecipe(connection, newRecipeId, outletId, req);

        return res.json({
            success: true,
            message: 'Recipe version created successfully',
            recipe
        });
    } catch (error) {
        await connection.rollback();
        console.error('Update recipe error:', error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || 'Unable to update recipe'
        });
    } finally {
        connection.release();
    }
};

// ============================================================
// ACTIVATE / DEACTIVATE RECIPE
// PATCH /inventory/recipes/:recipeId/status
// Body: { outletId, isActive }
//
// Only the latest/open version can have its operational status
// changed. Historical versions remain usable for historical
// bill-date recipe lookups.
// ============================================================
exports.updateRecipeStatus = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.body.outletId);
        const recipeId = Number(req.params.recipeId);
        const isActive = toBool(req.body.isActive, true);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid outletId is required' });
        }
        if (!Number.isInteger(recipeId) || recipeId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid recipeId is required' });
        }

        const [result] = await connection.query(
            `
            UPDATE recipe r
            INNER JOIN menu_item mi
                ON mi.menu_item_id = r.menu_item_id
            INNER JOIN outlet o
                ON o.outlet_id = mi.outlet_id
            INNER JOIN user_outlet uo
                ON uo.outlet_id = mi.outlet_id
            SET r.is_active = ?
            WHERE r.recipe_id = ?
              AND r.effective_to IS NULL
              AND mi.outlet_id = ?
              AND o.company_id = ?
              AND uo.user_id = ?
            `,
            [isActive ? 1 : 0, recipeId, outletId, req.user.companyId, req.user.userId]
        );

        if (!result.affectedRows) {
            return res.status(404).json({
                success: false,
                message: 'Latest recipe version not found or not authorized'
            });
        }

        return res.json({
            success: true,
            message: isActive ? 'Recipe activated successfully' : 'Recipe deactivated successfully'
        });
    } catch (error) {
        console.error('Update recipe status error:', error);
        return res.status(500).json({ success: false, message: 'Unable to update recipe status' });
    } finally {
        connection.release();
    }
};
