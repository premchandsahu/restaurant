const db = require('../database');

// ============================================================
// Phase 4B
// Dynamic recipe-based inventory consumption using
// SCD Type 2 recipe history.
//
// IMPORTANT:
//   - No bill_inventory_consumption table is used.
//   - No stock_transaction row is created for bill consumption.
//   - Historical recipe is selected using bill.bill_date.
//   - This controller is read-only.
// ============================================================

function normalizeDate(value) {
    if (!value) return null;

    if (value instanceof Date) {
        const year = value.getFullYear();
        const month = String(value.getMonth() + 1).padStart(2, '0');
        const day = String(value.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    const text = String(value);

    if (text.length >= 10) {
        return text.substring(0, 10);
    }

    return text;
}

function convertQuantity(qty, fromUnitCode, toUnitCode) {
    const quantity = Number(qty || 0);

    if (fromUnitCode === toUnitCode) {
        return quantity;
    }

    const from = String(fromUnitCode || '').trim().toUpperCase();
    const to = String(toUnitCode || '').trim().toUpperCase();

    // Mass
    const massToGram = {
        GM: 1,
        G: 1,
        KG: 1000
    };

    // Volume
    const volumeToMl = {
        ML: 1,
        LTR: 1000,
        L: 1000
    };

    if (massToGram[from] && massToGram[to]) {
        return quantity * massToGram[from] / massToGram[to];
    }

    if (volumeToMl[from] && volumeToMl[to]) {
        return quantity * volumeToMl[from] / volumeToMl[to];
    }

    throw new Error(
        `Unit conversion is not supported from ${from || '-'} to ${to || '-'}`
    );
}

function getProductionFactor(soldQty, recipeYieldQty) {
    const qty = Number(soldQty || 0);
    const yieldQty = Number(recipeYieldQty || 0);

    if (qty <= 0) {
        return 0;
    }

    if (yieldQty <= 0) {
        throw new Error('Recipe yield quantity must be greater than zero');
    }

    return qty / yieldQty;
}

async function getAuthorizedBill(connection, billId, req) {
    const [rows] = await connection.query(
        `
        SELECT
            b.bill_id,
            b.bill_uuid,
            b.outlet_id,
            b.order_id,
            b.bill_no,
            b.bill_date,
            b.bill_time,
            b.bill_status,
            b.bill_type

        FROM bill b

        INNER JOIN outlet o
            ON o.outlet_id = b.outlet_id

        INNER JOIN user_outlet uo
            ON uo.outlet_id = b.outlet_id

        WHERE b.bill_id = ?
          AND o.company_id = ?
          AND o.is_active = TRUE
          AND uo.user_id = ?

        LIMIT 1
        `,
        [
            billId,
            req.user.companyId,
            req.user.userId
        ]
    );

    return rows.length > 0 ? rows[0] : null;
}

// ============================================================
// GET BILL CONSUMPTION PREVIEW
//
// GET /inventory/consumption/bills/:billId/preview
//
// Read-only calculation. Nothing is written to stock tables.
// ============================================================
exports.getBillConsumptionPreview = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const billId = Number(req.params.billId);

        if (!billId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid billId'
            });
        }

        const bill = await getAuthorizedBill(
            connection,
            billId,
            req
        );

        if (!bill) {
            return res.status(404).json({
                success: false,
                message: 'Bill not found'
            });
        }

        const acceptedStatuses = [
            'FINAL',
            'PARTIALLY_PAID',
            'PAID',
            'REFUNDED'
        ];

        if (!acceptedStatuses.includes(bill.bill_status)) {
            return res.status(400).json({
                success: false,
                message:
                    `Inventory consumption is not calculated for bill status ${bill.bill_status}`
            });
        }

        const [billItems] = await connection.query(
            `
            SELECT
                bi.bill_item_id,
                bi.menu_item_id,
                bi.variant_id,
                bi.item_name,
                bi.variant_name,
                bi.qty

            FROM bill_item bi

            WHERE bi.bill_id = ?

            ORDER BY bi.bill_item_id
            `,
            [billId]
        );

        const consumption = [];
        const missingRecipes = [];

        for (const billItem of billItems) {
            let recipe = null;

            // Exact variant recipe has priority.
            if (billItem.variant_id !== null) {
                const [exactRecipes] = await connection.query(
                    `
                    SELECT
                        r.recipe_id,
                        r.recipe_uuid,
                        r.menu_item_id,
                        r.variant_id,
                        r.recipe_name,
                        r.version_no,
                        r.effective_from,
                        r.effective_to,
                        r.yield_qty,
                        r.yield_unit_id,
                        uy.unit_code AS yield_unit_code,
                        uy.unit_name AS yield_unit_name

                    FROM recipe r

                    INNER JOIN unit uy
                        ON uy.unit_id = r.yield_unit_id

                    WHERE r.menu_item_id = ?
                      AND r.variant_id = ?
                      AND r.effective_from <= ?
                      AND (
                            r.effective_to IS NULL
                            OR ? < r.effective_to
                          )

                    ORDER BY
                        r.version_no DESC,
                        r.recipe_id DESC

                    LIMIT 1
                    `,
                    [
                        billItem.menu_item_id,
                        billItem.variant_id,
                        normalizeDate(bill.bill_date),
                        normalizeDate(bill.bill_date)
                    ]
                );

                if (exactRecipes.length > 0) {
                    recipe = exactRecipes[0];
                }
            }

            // Default recipe fallback.
            if (!recipe) {
                const [defaultRecipes] = await connection.query(
                    `
                    SELECT
                        r.recipe_id,
                        r.recipe_uuid,
                        r.menu_item_id,
                        r.variant_id,
                        r.recipe_name,
                        r.version_no,
                        r.effective_from,
                        r.effective_to,
                        r.yield_qty,
                        r.yield_unit_id,
                        uy.unit_code AS yield_unit_code,
                        uy.unit_name AS yield_unit_name

                    FROM recipe r

                    INNER JOIN unit uy
                        ON uy.unit_id = r.yield_unit_id

                    WHERE r.menu_item_id = ?
                      AND r.variant_id IS NULL
                      AND r.effective_from <= ?
                      AND (
                            r.effective_to IS NULL
                            OR ? < r.effective_to
                          )

                    ORDER BY
                        r.version_no DESC,
                        r.recipe_id DESC

                    LIMIT 1
                    `,
                    [
                        billItem.menu_item_id,
                        normalizeDate(bill.bill_date),
                        normalizeDate(bill.bill_date)
                    ]
                );

                if (defaultRecipes.length > 0) {
                    recipe = defaultRecipes[0];
                }
            }

            if (!recipe) {
                missingRecipes.push({
                    billItemId: billItem.bill_item_id,
                    menuItemId: billItem.menu_item_id,
                    itemName: billItem.item_name,
                    variantId: billItem.variant_id,
                    variantName: billItem.variant_name,
                    qty: Number(billItem.qty || 0)
                });

                continue;
            }

            const [recipeItems] = await connection.query(
                `
                SELECT
                    ri.recipe_item_id,
                    ri.raw_material_id,
                    ri.qty,
                    ri.unit_id,
                    ri.wastage_percent,

                    rm.material_code,
                    rm.material_name,
                    rm.unit_id AS raw_material_unit_id,

                    ur.unit_code AS recipe_unit_code,
                    ur.unit_name AS recipe_unit_name,

                    ub.unit_code AS raw_material_unit_code,
                    ub.unit_name AS raw_material_unit_name

                FROM recipe_item ri

                INNER JOIN raw_material rm
                    ON rm.raw_material_id = ri.raw_material_id

                INNER JOIN unit ur
                    ON ur.unit_id = ri.unit_id

                INNER JOIN unit ub
                    ON ub.unit_id = rm.unit_id

                WHERE ri.recipe_id = ?

                ORDER BY ri.recipe_item_id
                `,
                [recipe.recipe_id]
            );

            const productionFactor = getProductionFactor(
                billItem.qty,
                recipe.yield_qty
            );

            for (const recipeItem of recipeItems) {
                const recipeQuantity =
                    productionFactor * Number(recipeItem.qty || 0);

                const consumptionQty =
                    convertQuantity(
                        recipeQuantity,
                        recipeItem.recipe_unit_code,
                        recipeItem.raw_material_unit_code
                    );

                const wastagePercent =
                    Number(recipeItem.wastage_percent || 0);

                const wastageQty =
                    consumptionQty * wastagePercent / 100;

                consumption.push({
                    billItemId:
                        billItem.bill_item_id,

                    menuItemId:
                        billItem.menu_item_id,

                    itemName:
                        billItem.item_name,

                    variantId:
                        billItem.variant_id,

                    variantName:
                        billItem.variant_name,

                    soldQty:
                        Number(billItem.qty || 0),

                    recipeId:
                        recipe.recipe_id,

                    recipeVersionNo:
                        recipe.version_no,

                    recipeName:
                        recipe.recipe_name,

                    effectiveFrom:
                        normalizeDate(recipe.effective_from),

                    effectiveTo:
                        normalizeDate(recipe.effective_to),

                    recipeYieldQty:
                        Number(recipe.yield_qty || 0),

                    recipeYieldUnitCode:
                        recipe.yield_unit_code,

                    recipeYieldUnitName:
                        recipe.yield_unit_name,

                    recipeItemId:
                        recipeItem.recipe_item_id,

                    rawMaterialId:
                        recipeItem.raw_material_id,

                    materialCode:
                        recipeItem.material_code,

                    materialName:
                        recipeItem.material_name,

                    recipeQty:
                        Number(recipeItem.qty || 0),

                    recipeUnitCode:
                        recipeItem.recipe_unit_code,

                    recipeUnitName:
                        recipeItem.recipe_unit_name,

                    consumptionQty:
                        consumptionQty,

                    consumptionUnitCode:
                        recipeItem.raw_material_unit_code,

                    consumptionUnitName:
                        recipeItem.raw_material_unit_name,

                    wastagePercent:
                        wastagePercent,

                    wastageQty:
                        wastageQty,

                    totalConsumptionQty:
                        consumptionQty + wastageQty,

                    totalConsumptionUnitCode:
                        recipeItem.raw_material_unit_code,

                    totalConsumptionUnitName:
                        recipeItem.raw_material_unit_name
                });
            }
        }

        const totalsMap = new Map();

        for (const row of consumption) {
            const key = String(row.rawMaterialId);

            if (!totalsMap.has(key)) {
                totalsMap.set(key, {
                    rawMaterialId: row.rawMaterialId,
                    materialCode: row.materialCode,
                    materialName: row.materialName,
                    unitCode: row.totalConsumptionUnitCode,
                    unitName: row.totalConsumptionUnitName,
                    consumptionQty: 0,
                    wastageQty: 0,
                    totalConsumptionQty: 0
                });
            }

            const total = totalsMap.get(key);

            total.consumptionQty += Number(row.consumptionQty || 0);
            total.wastageQty += Number(row.wastageQty || 0);
            total.totalConsumptionQty += Number(
                row.totalConsumptionQty || 0
            );
        }

        return res.json({
            success: true,

            bill: {
                billId: bill.bill_id,
                billNo: bill.bill_no,
                billDate: normalizeDate(bill.bill_date),
                billStatus: bill.bill_status,
                billType: bill.bill_type,
                outletId: bill.outlet_id
            },

            consumption,

            totalsByRawMaterial:
                Array.from(totalsMap.values()),

            missingRecipes
        });

    } catch (error) {
        console.error(
            'Get bill consumption preview error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                error.message ||
                'Unable to calculate bill inventory consumption'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// GET INVENTORY CONSUMPTION REPORT
//
// GET /inventory/consumption/report
//
// Query:
//   outletId      required
//   fromDate      required YYYY-MM-DD
//   toDate        required YYYY-MM-DD
//   rawMaterialId optional
//
// The report is calculated directly from bills + historical
// recipes. It does not read bill consumption transactions.
// ============================================================
exports.getConsumptionReport = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const fromDate = String(req.query.fromDate || '').trim();
        const toDate = String(req.query.toDate || '').trim();

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!/^\d{4}-\d{2}-\d{2}$/.test(fromDate)) {
            return res.status(400).json({
                success: false,
                message: 'fromDate must be YYYY-MM-DD'
            });
        }

        if (!/^\d{4}-\d{2}-\d{2}$/.test(toDate)) {
            return res.status(400).json({
                success: false,
                message: 'toDate must be YYYY-MM-DD'
            });
        }

        if (fromDate > toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be after toDate'
            });
        }

        const [authorized] = await connection.query(
            `
            SELECT 1
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

        if (authorized.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You do not have access to this outlet'
            });
        }

        const params = [
            outletId,
            fromDate,
            toDate
        ];

        let rawMaterialCondition = '';

        if (req.query.rawMaterialId !== undefined) {
            const rawMaterialId = Number(req.query.rawMaterialId);

            if (!rawMaterialId) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid rawMaterialId'
                });
            }

            rawMaterialCondition =
                ' AND rm.raw_material_id = ? ';

            params.push(rawMaterialId);
        }

        // The recipe join prefers the exact variant version when it exists.
        // If no exact variant recipe exists, the default item recipe is used.
        const [rows] = await connection.query(
            `
            SELECT
                rm.raw_material_id,
                rm.material_code,
                rm.material_name,
                ub.unit_code,
                ub.unit_name,

                SUM(
                    (
                        bi.qty / NULLIF(r.yield_qty, 0)
                    )
                    * ri.qty
                    * CASE
                        WHEN ur.unit_code = ub.unit_code THEN 1
                        WHEN ur.unit_code IN ('KG')
                             AND ub.unit_code IN ('GM', 'G') THEN 1000
                        WHEN ur.unit_code IN ('GM', 'G')
                             AND ub.unit_code = 'KG' THEN 0.001
                        WHEN ur.unit_code IN ('LTR', 'L')
                             AND ub.unit_code = 'ML' THEN 1000
                        WHEN ur.unit_code = 'ML'
                             AND ub.unit_code IN ('LTR', 'L') THEN 0.001
                        ELSE NULL
                      END
                ) AS raw_recipe_qty,

                SUM(
                    (
                        (
                            bi.qty / NULLIF(r.yield_qty, 0)
                        )
                        * ri.qty
                        * CASE
                            WHEN ur.unit_code = ub.unit_code THEN 1
                            WHEN ur.unit_code IN ('KG')
                                 AND ub.unit_code IN ('GM', 'G') THEN 1000
                            WHEN ur.unit_code IN ('GM', 'G')
                                 AND ub.unit_code = 'KG' THEN 0.001
                            WHEN ur.unit_code IN ('LTR', 'L')
                                 AND ub.unit_code = 'ML' THEN 1000
                            WHEN ur.unit_code = 'ML'
                                 AND ub.unit_code IN ('LTR', 'L') THEN 0.001
                            ELSE NULL
                          END
                    )
                    * ri.wastage_percent / 100
                ) AS raw_wastage_qty,

                COUNT(DISTINCT b.bill_id) AS bill_count

            FROM bill b

            INNER JOIN bill_item bi
                ON bi.bill_id = b.bill_id

            INNER JOIN recipe r
                ON r.menu_item_id = bi.menu_item_id
               AND r.effective_from <= b.bill_date
               AND (
                    r.effective_to IS NULL
                    OR b.bill_date < r.effective_to
               )
               AND (
                    r.variant_id = bi.variant_id
                    OR (
                        r.variant_id IS NULL
                        AND NOT EXISTS (
                            SELECT 1
                            FROM recipe rex
                            WHERE rex.menu_item_id = bi.menu_item_id
                              AND rex.variant_id = bi.variant_id
                              AND bi.variant_id IS NOT NULL
                              AND rex.effective_from <= b.bill_date
                              AND (
                                    rex.effective_to IS NULL
                                    OR b.bill_date < rex.effective_to
                                  )
                        )
                    )
               )

            INNER JOIN recipe_item ri
                ON ri.recipe_id = r.recipe_id

            INNER JOIN raw_material rm
                ON rm.raw_material_id = ri.raw_material_id
               AND rm.outlet_id = b.outlet_id

            INNER JOIN unit ur
                ON ur.unit_id = ri.unit_id

            INNER JOIN unit ub
                ON ub.unit_id = rm.unit_id

            WHERE b.outlet_id = ?
              AND b.bill_date BETWEEN ? AND ?
              AND b.bill_status IN (
                    'FINAL',
                    'PARTIALLY_PAID',
                    'PAID',
                    'REFUNDED'
              )
              AND bi.qty > 0
              ${rawMaterialCondition}

            GROUP BY
                rm.raw_material_id,
                rm.material_code,
                rm.material_name,
                ub.unit_code,
                ub.unit_name

            ORDER BY
                rm.material_name
            `,
            params
        );

        // The aggregate report currently supports the same mass/volume
        // conversions as the preview endpoint: KG/GM and LTR/ML.
        return res.json({
            success: true,
            outletId,
            fromDate,
            toDate,
            note:
                'Consumption report is calculated from posted bill documents and SCD2 recipe versions. KG/GM and LTR/ML conversion is supported; liquor Bottle/ML conversion remains part of the later liquor module.',
            rows: rows.map(row => ({
                rawMaterialId: row.raw_material_id,
                materialCode: row.material_code,
                materialName: row.material_name,
                unitCode: row.unit_code,
                unitName: row.unit_name,
                recipeConsumptionQty: Number(row.raw_recipe_qty || 0),
                wastageQty: Number(row.raw_wastage_qty || 0),
                totalConsumptionQty:
                    Number(row.raw_recipe_qty || 0) +
                    Number(row.raw_wastage_qty || 0),
                billCount: Number(row.bill_count || 0)
            }))
        });

    } catch (error) {
        console.error(
            'Get inventory consumption report error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                error.message ||
                'Unable to calculate inventory consumption report'
        });

    } finally {
        connection.release();
    }
};
