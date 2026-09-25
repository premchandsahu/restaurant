const db = require('../database');

// ============================================================
// PHASE 5C - DYNAMIC STOCK RECONCILIATION
//
// Purpose:
//   Compare dynamically calculated stock from source documents
//   against the operational stock_balance cache.
//
// Source-of-truth for dynamic stock:
//   - POSTED purchases
//   - stock adjustments
//   - restaurant bills + historical SCD2 recipes
//
// IMPORTANT:
//   This endpoint is READ-ONLY.
//   It does not update stock_balance or stock_transaction.
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
    return text.length >= 10 ? text.substring(0, 10) : text;
}

function isValidDateString(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
    }

    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));

    return (
        date.getUTCFullYear() === year &&
        date.getUTCMonth() === month - 1 &&
        date.getUTCDate() === day
    );
}

function roundQuantity(value, decimalPlaces = 3) {
    const places = Math.max(0, Number(decimalPlaces || 0));
    const factor = Math.pow(10, places);

    return Math.round(
        (Number(value || 0) + Number.EPSILON) * factor
    ) / factor;
}

function convertQuantity(qty, fromUnitCode, toUnitCode) {
    const quantity = Number(qty || 0);

    const from = String(fromUnitCode || '').trim().toUpperCase();
    const to = String(toUnitCode || '').trim().toUpperCase();

    if (from === to) {
        return quantity;
    }

    const massToGram = {
        GM: 1,
        G: 1,
        KG: 1000
    };

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

async function getAuthorizedOutlet(connection, outletId, req) {
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
        [outletId, req.user.companyId, req.user.userId]
    );

    return rows.length > 0 ? rows[0] : null;
}

async function getRawMaterials(connection, outletId, rawMaterialId = null) {
    const params = [outletId];
    let filter = '';

    if (rawMaterialId !== null) {
        filter = ' AND rm.raw_material_id = ?';
        params.push(rawMaterialId);
    }

    const [rows] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
            rm.material_code,
            rm.material_name,
            rm.unit_id,
            u.unit_code,
            u.unit_name,
            u.decimal_places,
            COALESCE(sb.current_qty, 0) AS cached_current_qty
        FROM raw_material rm
        INNER JOIN unit u
            ON u.unit_id = rm.unit_id
        LEFT JOIN stock_balance sb
            ON sb.raw_material_id = rm.raw_material_id
           AND sb.outlet_id = rm.outlet_id
        WHERE rm.outlet_id = ?
        ${filter}
        ORDER BY rm.material_name, rm.raw_material_id
        `,
        params
    );

    return rows;
}

async function getPurchaseTotals(
    connection,
    outletId,
    asOfDate,
    rawMaterialId = null
) {
    const params = [outletId, asOfDate];
    let rawMaterialFilter = '';

    if (rawMaterialId !== null) {
        rawMaterialFilter = ' AND pi.raw_material_id = ?';
        params.push(rawMaterialId);
    }

    const [rows] = await connection.query(
        `
        SELECT
            pi.raw_material_id,
            SUM(COALESCE(pi.base_qty, 0)) AS purchase_qty
        FROM purchase p
        INNER JOIN purchase_item pi
            ON pi.purchase_id = p.purchase_id
        WHERE p.outlet_id = ?
          AND p.status = 'POSTED'
          AND p.purchase_date <= ?
          ${rawMaterialFilter}
        GROUP BY pi.raw_material_id
        `,
        params
    );

    return new Map(
        rows.map(row => [
            Number(row.raw_material_id),
            Number(row.purchase_qty || 0)
        ])
    );
}

async function getAdjustmentTotals(
    connection,
    outletId,
    asOfDate,
    rawMaterialId = null
) {
    const params = [outletId, asOfDate];
    let rawMaterialFilter = '';

    if (rawMaterialId !== null) {
        rawMaterialFilter = ' AND sai.raw_material_id = ?';
        params.push(rawMaterialId);
    }

    const [rows] = await connection.query(
        `
        SELECT
            sai.raw_material_id,
            sa.adjustment_type,
            sai.qty,
            u.unit_code AS adjustment_unit_code,
            ub.unit_code AS base_unit_code
        FROM stock_adjustment sa
        INNER JOIN stock_adjustment_item sai
            ON sai.stock_adjustment_id = sa.stock_adjustment_id
        INNER JOIN raw_material rm
            ON rm.raw_material_id = sai.raw_material_id
           AND rm.outlet_id = sa.outlet_id
        INNER JOIN unit u
            ON u.unit_id = sai.unit_id
        INNER JOIN unit ub
            ON ub.unit_id = rm.unit_id
        WHERE sa.outlet_id = ?
          AND sa.adjustment_date <= ?
          ${rawMaterialFilter}
        ORDER BY
            sa.adjustment_date,
            sa.stock_adjustment_id,
            sai.stock_adjustment_item_id
        `,
        params
    );

    const totals = new Map();

    for (const row of rows) {
        let baseQty;

        try {
            baseQty = convertQuantity(
                row.qty,
                row.adjustment_unit_code,
                row.base_unit_code
            );
        } catch (error) {
            const conversionError = new Error(
                `Stock adjustment raw material ${row.raw_material_id}: ${error.message}`
            );
            conversionError.statusCode = 400;
            throw conversionError;
        }

        const rawMaterialKey = Number(row.raw_material_id);
        let bucket = totals.get(rawMaterialKey);

        if (!bucket) {
            bucket = {
                increaseQty: 0,
                decreaseQty: 0,
                wastageQty: 0,
                damageQty: 0,
                openingQty: 0
            };
            totals.set(rawMaterialKey, bucket);
        }

        switch (row.adjustment_type) {
            case 'OPENING':
                bucket.openingQty += baseQty;
                break;

            case 'INCREASE':
                bucket.increaseQty += baseQty;
                break;

            case 'DECREASE':
                bucket.decreaseQty += baseQty;
                break;

            case 'WASTAGE':
                bucket.wastageQty += baseQty;
                break;

            case 'DAMAGE':
                bucket.damageQty += baseQty;
                break;

            default:
                break;
        }
    }

    return totals;
}

async function getConsumptionTotals(
    connection,
    outletId,
    asOfDate,
    rawMaterialId = null
) {
    const params = [outletId, asOfDate];
    let rawMaterialFilter = '';

    if (rawMaterialId !== null) {
        rawMaterialFilter = ' AND ri.raw_material_id = ?';
        params.push(rawMaterialId);
    }

    const [rows] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
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
            ) AS recipe_consumption_qty,
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
            ) AS recipe_wastage_qty
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
          AND b.bill_date <= ?
          AND b.bill_status IN (
                'FINAL',
                'PARTIALLY_PAID',
                'PAID',
                'REFUNDED'
          )
          AND bi.qty > 0
          ${rawMaterialFilter}
        GROUP BY rm.raw_material_id
        `,
        params
    );

    return new Map(
        rows.map(row => [
            Number(row.raw_material_id),
            {
                consumptionQty: Number(row.recipe_consumption_qty || 0),
                recipeWastageQty: Number(row.recipe_wastage_qty || 0)
            }
        ])
    );
}

async function getMissingRecipeItems(
    connection,
    outletId,
    asOfDate
) {
    const [rows] = await connection.query(
        `
        SELECT
            bi.menu_item_id,
            bi.variant_id,
            bi.item_name,
            bi.variant_name,
            COUNT(DISTINCT b.bill_id) AS bill_count,
            SUM(bi.qty) AS sold_qty
        FROM bill b
        INNER JOIN bill_item bi
            ON bi.bill_id = b.bill_id
        LEFT JOIN recipe r
            ON r.menu_item_id = bi.menu_item_id
           AND r.effective_from <= b.bill_date
           AND (
                r.effective_to IS NULL
                OR b.bill_date < r.effective_to
           )
           AND (
                r.variant_id = bi.variant_id
                OR r.variant_id IS NULL
           )
        WHERE b.outlet_id = ?
          AND b.bill_date <= ?
          AND b.bill_status IN (
                'FINAL',
                'PARTIALLY_PAID',
                'PAID',
                'REFUNDED'
          )
          AND bi.qty > 0
          AND r.recipe_id IS NULL
        GROUP BY
            bi.menu_item_id,
            bi.variant_id,
            bi.item_name,
            bi.variant_name
        ORDER BY bi.item_name, bi.variant_name
        `,
        [outletId, asOfDate]
    );

    return rows.map(row => ({
        menuItemId: Number(row.menu_item_id),
        variantId: row.variant_id === null
            ? null
            : Number(row.variant_id),
        itemName: row.item_name,
        variantName: row.variant_name,
        billCount: Number(row.bill_count || 0),
        soldQty: Number(row.sold_qty || 0)
    }));
}

// ============================================================
// GET STOCK RECONCILIATION
//
// GET /inventory/stock/reconciliation
//
// Query:
//   outletId       required
//   asOfDate       optional YYYY-MM-DD (defaults to today)
//   rawMaterialId  optional
// ============================================================
exports.getStockReconciliation = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const asOfDate = String(
            req.query.asOfDate ||
            new Date().toISOString().substring(0, 10)
        ).trim();

        if (!isValidDateString(asOfDate)) {
            return res.status(400).json({
                success: false,
                message: 'asOfDate must be a valid YYYY-MM-DD date'
            });
        }

        let rawMaterialId = null;

        if (req.query.rawMaterialId !== undefined) {
            rawMaterialId = Number(req.query.rawMaterialId);

            if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid rawMaterialId'
                });
            }
        }

        const authorizedOutlet = await getAuthorizedOutlet(
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

        const rawMaterials = await getRawMaterials(
            connection,
            outletId,
            rawMaterialId
        );

        if (
            rawMaterialId !== null &&
            rawMaterials.length === 0
        ) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found for this outlet'
            });
        }

        const purchaseMap = await getPurchaseTotals(
            connection,
            outletId,
            asOfDate,
            rawMaterialId
        );

        const adjustmentMap = await getAdjustmentTotals(
            connection,
            outletId,
            asOfDate,
            rawMaterialId
        );

        const consumptionMap = await getConsumptionTotals(
            connection,
            outletId,
            asOfDate,
            rawMaterialId
        );

        const missingRecipeItems = rawMaterialId === null
            ? await getMissingRecipeItems(
                connection,
                outletId,
                asOfDate
            )
            : [];

        const rows = rawMaterials.map(material => {
            const id = Number(material.raw_material_id);

            const purchases =
                Number(purchaseMap.get(id) || 0);

            const adjustment =
                adjustmentMap.get(id) || {
                    increaseQty: 0,
                    decreaseQty: 0,
                    wastageQty: 0,
                    damageQty: 0,
                    openingQty: 0
                };

            const consumption =
                consumptionMap.get(id) || {
                    consumptionQty: 0,
                    recipeWastageQty: 0
                };

            const dynamicQty =
                purchases +
                adjustment.openingQty +
                adjustment.increaseQty -
                adjustment.decreaseQty -
                adjustment.wastageQty -
                adjustment.damageQty -
                consumption.consumptionQty -
                consumption.recipeWastageQty;

            const cachedQty = Number(
                material.cached_current_qty || 0
            );

            const difference = dynamicQty - cachedQty;
            const tolerance = 0.0005;

            return {
                rawMaterialId: id,
                materialCode: material.material_code,
                materialName: material.material_name,
                unitId: Number(material.unit_id),
                unitCode: material.unit_code,
                unitName: material.unit_name,
                decimalPlaces: Number(material.decimal_places || 0),
                asOfDate,
                dynamicStockQty: roundQuantity(
                    dynamicQty,
                    material.decimal_places
                ),
                cachedStockQty: roundQuantity(
                    cachedQty,
                    material.decimal_places
                ),
                differenceQty: roundQuantity(
                    difference,
                    material.decimal_places
                ),
                reconciled: Math.abs(difference) <= tolerance,
                negativeDynamicStock:
                    dynamicQty < -tolerance,
                components: {
                    purchaseQty: roundQuantity(
                        purchases,
                        material.decimal_places
                    ),
                    openingAdjustmentQty: roundQuantity(
                        adjustment.openingQty,
                        material.decimal_places
                    ),
                    adjustmentInQty: roundQuantity(
                        adjustment.increaseQty,
                        material.decimal_places
                    ),
                    adjustmentOutQty: roundQuantity(
                        adjustment.decreaseQty,
                        material.decimal_places
                    ),
                    wastageQty: roundQuantity(
                        adjustment.wastageQty,
                        material.decimal_places
                    ),
                    damageQty: roundQuantity(
                        adjustment.damageQty,
                        material.decimal_places
                    ),
                    recipeConsumptionQty: roundQuantity(
                        consumption.consumptionQty,
                        material.decimal_places
                    ),
                    recipeWastageQty: roundQuantity(
                        consumption.recipeWastageQty,
                        material.decimal_places
                    )
                }
            };
        });

        const mismatchCount = rows.filter(
            row => !row.reconciled
        ).length;

        return res.json({
            success: true,
            outletId,
            asOfDate,
            note:
                'Reconciliation compares source-document stock against stock_balance. ' +
                'No stock value is modified by this endpoint.',
            summary: {
                materialCount: rows.length,
                reconciledCount: rows.length - mismatchCount,
                mismatchCount,
                allReconciled: mismatchCount === 0,
                missingRecipeItemCount: missingRecipeItems.length
            },
            rows,
            missingRecipeItems
        });

    } catch (error) {
        console.error(
            'Get stock reconciliation error:',
            error
        );

        const statusCode =
            Number(error.statusCode) || 500;

        return res.status(statusCode).json({
            success: false,
            message:
                statusCode === 400
                    ? error.message
                    : 'Unable to get stock reconciliation'
        });

    } finally {
        connection.release();
    }
};
