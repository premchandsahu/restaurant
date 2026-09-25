const db = require('../database');

// ============================================================
// PHASE 5A - DYNAMIC STOCK REGISTER
//
// The register is calculated from source documents:
//   - POSTED purchase documents
//   - stock adjustment documents
//   - restaurant bill documents + historical SCD2 recipes
//
// stock_transaction / stock_balance are deliberately NOT used
// as the source of truth for this report.
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

    return text.length >= 10
        ? text.substring(0, 10)
        : text;
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

    return Math.round((Number(value || 0) + Number.EPSILON) * factor) / factor;
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
        [
            outletId,
            req.user.companyId,
            req.user.userId
        ]
    );

    return rows.length > 0 ? rows[0] : null;
}

async function getRawMaterials(connection, outletId) {
    const [rows] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
            rm.material_code,
            rm.material_name,
            rm.unit_id,
            u.unit_code,
            u.unit_name,
            u.decimal_places
        FROM raw_material rm
        INNER JOIN unit u
            ON u.unit_id = rm.unit_id
        WHERE rm.outlet_id = ?
        ORDER BY rm.material_name, rm.raw_material_id
        `,
        [outletId]
    );

    return rows;
}

// ============================================================
// PURCHASE TOTALS
//
// purchase_item.base_qty is the authoritative base-unit quantity
// for a posted purchase. POST PURCHASE already validates base_qty.
// ============================================================
async function getPurchaseTotals(
    connection,
    outletId,
    fromDate,
    toDate
) {
    const [rows] = await connection.query(
        `
        SELECT
            pi.raw_material_id,

            SUM(
                CASE
                    WHEN p.purchase_date < ?
                    THEN COALESCE(pi.base_qty, 0)
                    ELSE 0
                END
            ) AS opening_purchase_qty,

            SUM(
                CASE
                    WHEN p.purchase_date BETWEEN ? AND ?
                    THEN COALESCE(pi.base_qty, 0)
                    ELSE 0
                END
            ) AS period_purchase_qty

        FROM purchase p

        INNER JOIN purchase_item pi
            ON pi.purchase_id = p.purchase_id

        WHERE p.outlet_id = ?
          AND p.status = 'POSTED'
          AND p.purchase_date <= ?

        GROUP BY
            pi.raw_material_id
        `,
        [
            fromDate,
            fromDate,
            toDate,
            outletId,
            toDate
        ]
    );

    return rows;
}

// ============================================================
// STOCK ADJUSTMENTS
//
// Adjustment quantities are stored in the transaction unit, so
// they are converted to the raw material's base unit here.
// ============================================================
async function getAdjustmentTotals(
    connection,
    outletId,
    fromDate,
    toDate
) {
    const [rows] = await connection.query(
        `
        SELECT
            sai.stock_adjustment_item_id,
            sa.stock_adjustment_id,
            sa.adjustment_date,
            sa.adjustment_type,
            sai.raw_material_id,
            sai.qty,
            u.unit_code AS adjustment_unit_code,
            rm.unit_id AS base_unit_id,
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

        ORDER BY
            sa.adjustment_date,
            sa.stock_adjustment_id,
            sai.stock_adjustment_item_id
        `,
        [
            outletId,
            toDate
        ]
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
                `Stock adjustment ${row.stock_adjustment_id}, ` +
                `raw material ${row.raw_material_id}: ${error.message}`
            );
            conversionError.statusCode = 400;
            throw conversionError;
        }

        let bucket = totals.get(row.raw_material_id);

        if (!bucket) {
            bucket = {
                openingIn: 0,
                openingOut: 0,
                periodIn: 0,
                periodOut: 0,
                periodWastage: 0,
                periodDamage: 0,
                openingWastage: 0,
                openingDamage: 0
            };

            totals.set(row.raw_material_id, bucket);
        }

        const beforePeriod =
            normalizeDate(row.adjustment_date) < fromDate;

        const type = row.adjustment_type;
        const isIn =
            type === 'OPENING' ||
            type === 'INCREASE';

        if (isIn) {
            if (beforePeriod) {
                bucket.openingIn += baseQty;
            } else {
                bucket.periodIn += baseQty;
            }

            continue;
        }

        if (type === 'WASTAGE') {
            if (beforePeriod) {
                bucket.openingWastage += baseQty;
            } else {
                bucket.periodWastage += baseQty;
            }

            continue;
        }

        if (type === 'DAMAGE') {
            if (beforePeriod) {
                bucket.openingDamage += baseQty;
            } else {
                bucket.periodDamage += baseQty;
            }

            continue;
        }

        if (
            type === 'DECREASE'
        ) {
            if (beforePeriod) {
                bucket.openingOut += baseQty;
            } else {
                bucket.periodOut += baseQty;
            }
        }
    }

    return totals;
}

// ============================================================
// CONSUMPTION TOTALS USING SCD2 RECIPES
//
// Returns recipe consumption and recipe wastage separately.
// No stock document is created.
// ============================================================
async function getConsumptionTotals(
    connection,
    outletId,
    fromDate,
    toDate,
    mode
) {
    let dateCondition;
    let params;

    if (mode === 'OPENING') {
        dateCondition = 'b.bill_date < ?';
        params = [
            outletId,
            fromDate
        ];
    } else {
        dateCondition = 'b.bill_date BETWEEN ? AND ?';
        params = [
            outletId,
            fromDate,
            toDate
        ];
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
          AND ${dateCondition}
          AND b.bill_status IN (
                'FINAL',
                'PARTIALLY_PAID',
                'PAID',
                'REFUNDED'
          )
          AND bi.qty > 0

        GROUP BY
            rm.raw_material_id
        `,
        params
    );

    return rows;
}

function addConsumptionMap(target, rows, isOpening) {
    for (const row of rows) {
        let bucket = target.get(row.raw_material_id);

        if (!bucket) {
            bucket = {
                openingConsumption: 0,
                openingRecipeWastage: 0,
                periodConsumption: 0,
                periodRecipeWastage: 0
            };

            target.set(row.raw_material_id, bucket);
        }

        const consumption = Number(row.recipe_consumption_qty || 0);
        const wastage = Number(row.recipe_wastage_qty || 0);

        if (isOpening) {
            bucket.openingConsumption += consumption;
            bucket.openingRecipeWastage += wastage;
        } else {
            bucket.periodConsumption += consumption;
            bucket.periodRecipeWastage += wastage;
        }
    }
}

// ============================================================
// GET DYNAMIC STOCK REGISTER
//
// GET /inventory/stock/register
//
// Query:
//   outletId  required
//   fromDate  required YYYY-MM-DD
//   toDate    required YYYY-MM-DD
//   rawMaterialId optional
// ============================================================
exports.getStockRegister = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const fromDate = String(req.query.fromDate || '').trim();
        const toDate = String(req.query.toDate || '').trim();

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!isValidDateString(fromDate)) {
            return res.status(400).json({
                success: false,
                message: 'fromDate must be a valid YYYY-MM-DD date'
            });
        }

        if (!isValidDateString(toDate)) {
            return res.status(400).json({
                success: false,
                message: 'toDate must be a valid YYYY-MM-DD date'
            });
        }

        if (fromDate > toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be after toDate'
            });
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

        let rawMaterialFilter = null;

        if (req.query.rawMaterialId !== undefined) {
            rawMaterialFilter = Number(req.query.rawMaterialId);

            if (!Number.isInteger(rawMaterialFilter) || rawMaterialFilter <= 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid rawMaterialId'
                });
            }
        }

        const rawMaterials = await getRawMaterials(
            connection,
            outletId
        );

        const selectedRawMaterials = rawMaterialFilter === null
            ? rawMaterials
            : rawMaterials.filter(
                row => Number(row.raw_material_id) === rawMaterialFilter
            );

        if (
            rawMaterialFilter !== null &&
            selectedRawMaterials.length === 0
        ) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found for this outlet'
            });
        }

        const purchaseRows = await getPurchaseTotals(
            connection,
            outletId,
            fromDate,
            toDate
        );

        const adjustmentTotals = await getAdjustmentTotals(
            connection,
            outletId,
            fromDate,
            toDate
        );

        const consumptionTotals = new Map();

        const openingConsumptionRows = await getConsumptionTotals(
            connection,
            outletId,
            fromDate,
            toDate,
            'OPENING'
        );

        const periodConsumptionRows = await getConsumptionTotals(
            connection,
            outletId,
            fromDate,
            toDate,
            'PERIOD'
        );

        addConsumptionMap(
            consumptionTotals,
            openingConsumptionRows,
            true
        );

        addConsumptionMap(
            consumptionTotals,
            periodConsumptionRows,
            false
        );

        const purchaseMap = new Map();

        for (const row of purchaseRows) {
            purchaseMap.set(row.raw_material_id, {
                opening: Number(row.opening_purchase_qty || 0),
                period: Number(row.period_purchase_qty || 0)
            });
        }

        const rows = selectedRawMaterials.map(material => {
            const rawMaterialId = material.raw_material_id;

            const purchase = purchaseMap.get(rawMaterialId) || {
                opening: 0,
                period: 0
            };

            const adjustment = adjustmentTotals.get(rawMaterialId) || {
                openingIn: 0,
                openingOut: 0,
                periodIn: 0,
                periodOut: 0,
                periodWastage: 0,
                periodDamage: 0,
                openingWastage: 0,
                openingDamage: 0
            };

            const consumption = consumptionTotals.get(rawMaterialId) || {
                openingConsumption: 0,
                openingRecipeWastage: 0,
                periodConsumption: 0,
                periodRecipeWastage: 0
            };

            const openingQty =
                purchase.opening +
                adjustment.openingIn -
                adjustment.openingOut -
                consumption.openingConsumption -
                consumption.openingRecipeWastage -
                adjustment.openingWastage -
                adjustment.openingDamage;

            const periodIn =
                purchase.period +
                adjustment.periodIn;

            const periodOut =
                adjustment.periodOut +
                consumption.periodConsumption +
                consumption.periodRecipeWastage +
                adjustment.periodWastage +
                adjustment.periodDamage;

            const closingQty =
                openingQty +
                periodIn -
                periodOut;

            return {
                rawMaterialId,
                materialCode: material.material_code,
                materialName: material.material_name,
                unitId: material.unit_id,
                unitCode: material.unit_code,
                unitName: material.unit_name,
                openingQty: roundQuantity(
                    openingQty,
                    material.decimal_places
                ),
                purchaseQty: roundQuantity(
                    purchase.period,
                    material.decimal_places
                ),
                adjustmentInQty: roundQuantity(
                    adjustment.periodIn,
                    material.decimal_places
                ),
                adjustmentOutQty: roundQuantity(
                    adjustment.periodOut,
                    material.decimal_places
                ),
                consumptionQty: roundQuantity(
                    consumption.periodConsumption,
                    material.decimal_places
                ),
                recipeWastageQty: roundQuantity(
                    consumption.periodRecipeWastage,
                    material.decimal_places
                ),
                wastageQty: roundQuantity(
                    adjustment.periodWastage,
                    material.decimal_places
                ),
                damageQty: roundQuantity(
                    adjustment.periodDamage,
                    material.decimal_places
                ),
                closingQty: roundQuantity(
                    closingQty,
                    material.decimal_places
                ),
                negativeStock:
                    closingQty < -0.0000001
            };
        });

        return res.json({
            success: true,
            outletId,
            fromDate,
            toDate,
            note:
                'Stock register is calculated from source documents: POSTED purchases, stock adjustments, and restaurant bills using historical SCD2 recipes. stock_transaction and stock_balance are not used as the report source of truth.',
            rows
        });

    } catch (error) {
        console.error(
            'Get dynamic stock register error:',
            error
        );

        return res.status(error.statusCode || 500).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to calculate dynamic stock register'
        });

    } finally {
        connection.release();
    }
};
