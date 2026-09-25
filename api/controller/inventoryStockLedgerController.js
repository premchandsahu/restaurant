const db = require('../database');

// ============================================================
// PHASE 5B - DYNAMIC STOCK ITEM LEDGER
//
// Source of truth:
//   - POSTED purchase documents
//   - stock adjustment documents
//   - restaurant bill documents + historical SCD2 recipes
//
// This endpoint is read-only. It does not use stock_transaction
// or stock_balance as the report source of truth.
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
        [outletId, req.user.companyId, req.user.userId]
    );

    return rows.length > 0 ? rows[0] : null;
}

async function getRawMaterial(connection, outletId, rawMaterialId) {
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
          AND rm.raw_material_id = ?
        LIMIT 1
        `,
        [outletId, rawMaterialId]
    );

    return rows.length > 0 ? rows[0] : null;
}

async function getOpeningQuantity(
    connection,
    outletId,
    rawMaterial,
    fromDate
) {
    let quantity = 0;

    // --------------------------------------------------------
    // Purchases before the report period.
    // --------------------------------------------------------
    const [purchaseRows] = await connection.query(
        `
        SELECT
            pi.qty,
            pi.base_qty,
            pu.unit_code AS purchase_unit_code
        FROM purchase p
        INNER JOIN purchase_item pi
            ON pi.purchase_id = p.purchase_id
        INNER JOIN unit pu
            ON pu.unit_id = pi.unit_id
        WHERE p.outlet_id = ?
          AND p.status = 'POSTED'
          AND p.purchase_date < ?
          AND pi.raw_material_id = ?
        ORDER BY p.purchase_date, p.purchase_id, pi.purchase_item_id
        `,
        [outletId, fromDate, rawMaterial.raw_material_id]
    );

    for (const row of purchaseRows) {
        if (row.base_qty !== null && row.base_qty !== undefined) {
            quantity += Number(row.base_qty || 0);
        } else {
            quantity += convertQuantity(
                row.qty,
                row.purchase_unit_code,
                rawMaterial.unit_code
            );
        }
    }

    // --------------------------------------------------------
    // Stock adjustments before the report period.
    // --------------------------------------------------------
    const [adjustmentRows] = await connection.query(
        `
        SELECT
            sa.adjustment_type,
            sai.qty,
            u.unit_code AS adjustment_unit_code
        FROM stock_adjustment sa
        INNER JOIN stock_adjustment_item sai
            ON sai.stock_adjustment_id = sa.stock_adjustment_id
        INNER JOIN unit u
            ON u.unit_id = sai.unit_id
        WHERE sa.outlet_id = ?
          AND sa.adjustment_date < ?
          AND sai.raw_material_id = ?
        ORDER BY sa.adjustment_date, sa.stock_adjustment_id, sai.stock_adjustment_item_id
        `,
        [outletId, fromDate, rawMaterial.raw_material_id]
    );

    for (const row of adjustmentRows) {
        const qty = convertQuantity(
            row.qty,
            row.adjustment_unit_code,
            rawMaterial.unit_code
        );

        switch (row.adjustment_type) {
            case 'OPENING':
            case 'INCREASE':
                quantity += qty;
                break;

            case 'DECREASE':
            case 'WASTAGE':
            case 'DAMAGE':
                quantity -= qty;
                break;

            default:
                break;
        }
    }

    // The bulk bill query below is used for actual opening consumption.
    const [consumptionRows] = await connection.query(
        `
        SELECT
            bi.bill_item_id,
            b.bill_id,
            b.bill_date,
            bi.qty AS sold_qty,
            bi.menu_item_id,
            bi.variant_id,
            ri.qty AS recipe_qty,
            ri.wastage_percent,
            r.yield_qty,
            ur.unit_code AS recipe_unit_code,
            ub.unit_code AS base_unit_code
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
           AND ri.raw_material_id = ?
        INNER JOIN raw_material rm
            ON rm.raw_material_id = ri.raw_material_id
           AND rm.outlet_id = b.outlet_id
        INNER JOIN unit ur
            ON ur.unit_id = ri.unit_id
        INNER JOIN unit ub
            ON ub.unit_id = rm.unit_id
        WHERE b.outlet_id = ?
          AND b.bill_date < ?
          AND b.bill_status IN (
                'FINAL',
                'PARTIALLY_PAID',
                'PAID',
                'REFUNDED'
          )
          AND bi.qty > 0
        ORDER BY b.bill_date, b.bill_id, bi.bill_item_id, ri.recipe_item_id
        `,
        [
            rawMaterial.raw_material_id,
            outletId,
            fromDate
        ]
    );

    for (const row of consumptionRows) {
        const conversion = convertQuantity(
            row.recipe_qty,
            row.recipe_unit_code,
            row.base_unit_code
        );

        const consumed =
            (Number(row.sold_qty || 0) /
                Number(row.yield_qty || 1)) *
            conversion;

        const recipeWastage =
            consumed * Number(row.wastage_percent || 0) / 100;

        quantity -= consumed;
        quantity -= recipeWastage;
    }

    return quantity;
}

// ============================================================
// IMPORTANT:
// The opening helper above deliberately keeps all opening sources in
// one place, but bill history is more efficient as a direct aggregate.
// The following function provides the complete period transaction rows.
// ============================================================

async function getLedgerRows(
    connection,
    outletId,
    rawMaterial,
    fromDate,
    toDate
) {
    const rows = [];

    // --------------------------------------------------------
    // Purchases
    // --------------------------------------------------------
    const [purchaseRows] = await connection.query(
        `
        SELECT
            p.purchase_id,
            p.purchase_no,
            p.purchase_date,
            pi.purchase_item_id,
            pi.qty,
            pi.base_qty,
            pi.rate,
            pu.unit_code AS purchase_unit_code
        FROM purchase p
        INNER JOIN purchase_item pi
            ON pi.purchase_id = p.purchase_id
        INNER JOIN unit pu
            ON pu.unit_id = pi.unit_id
        WHERE p.outlet_id = ?
          AND p.status = 'POSTED'
          AND p.purchase_date BETWEEN ? AND ?
          AND pi.raw_material_id = ?
        ORDER BY p.purchase_date, p.purchase_id, pi.purchase_item_id
        `,
        [
            outletId,
            fromDate,
            toDate,
            rawMaterial.raw_material_id
        ]
    );

    for (const row of purchaseRows) {
        const baseQty =
            row.base_qty !== null && row.base_qty !== undefined
                ? Number(row.base_qty || 0)
                : convertQuantity(
                    row.qty,
                    row.purchase_unit_code,
                    rawMaterial.unit_code
                );

        rows.push({
            date: normalizeDate(row.purchase_date),
            sortDateTime: `${normalizeDate(row.purchase_date)} 00:00:00`,
            sequence: Number(row.purchase_id),
            sourceType: 'PURCHASE',
            sourceId: Number(row.purchase_id),
            sourceLineId: Number(row.purchase_item_id),
            referenceNo: row.purchase_no,
            description: `Purchase ${row.purchase_no}`,
            quantityIn: baseQty,
            quantityOut: 0,
            rate: Number(row.rate || 0),
            remarks: null
        });
    }

    // --------------------------------------------------------
    // Stock adjustments
    // --------------------------------------------------------
    const [adjustmentRows] = await connection.query(
        `
        SELECT
            sa.stock_adjustment_id,
            sa.adjustment_no,
            sa.adjustment_date,
            sa.adjustment_type,
            sa.reason,
            sai.stock_adjustment_item_id,
            sai.qty,
            sai.rate,
            u.unit_code AS adjustment_unit_code
        FROM stock_adjustment sa
        INNER JOIN stock_adjustment_item sai
            ON sai.stock_adjustment_id = sa.stock_adjustment_id
        INNER JOIN unit u
            ON u.unit_id = sai.unit_id
        WHERE sa.outlet_id = ?
          AND sa.adjustment_date BETWEEN ? AND ?
          AND sai.raw_material_id = ?
        ORDER BY sa.adjustment_date, sa.stock_adjustment_id, sai.stock_adjustment_item_id
        `,
        [
            outletId,
            fromDate,
            toDate,
            rawMaterial.raw_material_id
        ]
    );

    for (const row of adjustmentRows) {
        const baseQty = convertQuantity(
            row.qty,
            row.adjustment_unit_code,
            rawMaterial.unit_code
        );

        const isIn =
            row.adjustment_type === 'OPENING' ||
            row.adjustment_type === 'INCREASE';

        rows.push({
            date: normalizeDate(row.adjustment_date),
            sortDateTime: `${normalizeDate(row.adjustment_date)} 12:00:00`,
            sequence: Number(row.stock_adjustment_id),
            sourceType: row.adjustment_type === 'OPENING'
                ? 'OPENING'
                : row.adjustment_type === 'INCREASE'
                    ? 'ADJUSTMENT_IN'
                    : row.adjustment_type === 'DECREASE'
                        ? 'ADJUSTMENT_OUT'
                        : row.adjustment_type,
            sourceId: Number(row.stock_adjustment_id),
            sourceLineId: Number(row.stock_adjustment_item_id),
            referenceNo: row.adjustment_no,
            description: `${row.adjustment_type} ${row.adjustment_no}`,
            quantityIn: isIn ? baseQty : 0,
            quantityOut: isIn ? 0 : baseQty,
            rate: Number(row.rate || 0),
            remarks: row.reason || null
        });
    }

    // --------------------------------------------------------
    // Restaurant bill / recipe consumption
    // --------------------------------------------------------
    const [consumptionRows] = await connection.query(
        `
        SELECT
            b.bill_id,
            b.bill_no,
            b.bill_date,
            b.bill_time,
            bi.bill_item_id,
            bi.item_name,
            bi.variant_name,
            bi.qty AS sold_qty,
            bi.menu_item_id,
            bi.variant_id,
            r.recipe_id,
            r.version_no,
            r.recipe_name,
            r.yield_qty,
            ri.recipe_item_id,
            ri.qty AS recipe_qty,
            ri.wastage_percent,
            ur.unit_code AS recipe_unit_code,
            ub.unit_code AS base_unit_code
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
           AND ri.raw_material_id = ?
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
        ORDER BY b.bill_date, b.bill_time, b.bill_id, bi.bill_item_id, ri.recipe_item_id
        `,
        [
            rawMaterial.raw_material_id,
            outletId,
            fromDate,
            toDate
        ]
    );

    for (const row of consumptionRows) {
        const recipeQtyInBase = convertQuantity(
            row.recipe_qty,
            row.recipe_unit_code,
            row.base_unit_code
        );

        const consumptionQty =
            (Number(row.sold_qty || 0) /
                Number(row.yield_qty || 1)) *
            recipeQtyInBase;

        const recipeWastageQty =
            consumptionQty * Number(row.wastage_percent || 0) / 100;

        const itemLabel = row.variant_name
            ? `${row.item_name} (${row.variant_name})`
            : row.item_name;

        rows.push({
            date: normalizeDate(row.bill_date),
            sortDateTime: normalizeDate(row.bill_time || row.bill_date),
            sequence: Number(row.bill_id),
            sourceType: 'SALE_CONSUMPTION',
            sourceId: Number(row.bill_id),
            sourceLineId: Number(row.bill_item_id),
            referenceNo: row.bill_no,
            description: `Sale Consumption - ${itemLabel}`,
            quantityIn: 0,
            quantityOut: consumptionQty,
            rate: 0,
            remarks:
                `Recipe ${row.recipe_name} v${row.version_no}; ` +
                `sold qty ${Number(row.sold_qty || 0)}`
        });

        if (recipeWastageQty > 0) {
            rows.push({
                date: normalizeDate(row.bill_date),
                sortDateTime: normalizeDate(row.bill_time || row.bill_date),
                sequence: Number(row.bill_id),
                sourceType: 'RECIPE_WASTAGE',
                sourceId: Number(row.bill_id),
                sourceLineId: Number(row.recipe_item_id),
                referenceNo: row.bill_no,
                description: `Recipe Wastage - ${itemLabel}`,
                quantityIn: 0,
                quantityOut: recipeWastageQty,
                rate: 0,
                remarks:
                    `Wastage ${Number(row.wastage_percent || 0)}% from ` +
                    `recipe ${row.recipe_name} v${row.version_no}`
            });
        }
    }

    rows.sort((a, b) => {
        const dateCompare = String(a.sortDateTime).localeCompare(String(b.sortDateTime));
        if (dateCompare !== 0) return dateCompare;

        const sourceOrder = {
            OPENING: 1,
            PURCHASE: 2,
            ADJUSTMENT_IN: 3,
            ADJUSTMENT_OUT: 4,
            WASTAGE: 5,
            DAMAGE: 6,
            SALE_CONSUMPTION: 7,
            RECIPE_WASTAGE: 8
        };

        const aOrder = sourceOrder[a.sourceType] || 99;
        const bOrder = sourceOrder[b.sourceType] || 99;

        if (aOrder !== bOrder) return aOrder - bOrder;
        if (a.sequence !== b.sequence) return a.sequence - b.sequence;
        return (a.sourceLineId || 0) - (b.sourceLineId || 0);
    });

    return rows;
}

// ============================================================
// GET STOCK ITEM LEDGER
//
// GET /inventory/stock/ledger
//
// Query:
//   outletId       required
//   rawMaterialId  required
//   fromDate       required YYYY-MM-DD
//   toDate         required YYYY-MM-DD
// ============================================================
exports.getStockItemLedger = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const rawMaterialId = Number(req.query.rawMaterialId);
        const fromDate = String(req.query.fromDate || '').trim();
        const toDate = String(req.query.toDate || '').trim();

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'rawMaterialId is required'
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

        const rawMaterial = await getRawMaterial(
            connection,
            outletId,
            rawMaterialId
        );

        if (!rawMaterial) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found for this outlet'
            });
        }

        // Opening quantity is the source-document stock immediately before
        // the requested date range.
        const openingQty = await getOpeningQuantity(
            connection,
            outletId,
            rawMaterial,
            fromDate
        );

        const ledgerRows = await getLedgerRows(
            connection,
            outletId,
            rawMaterial,
            fromDate,
            toDate
        );

        let runningBalance = openingQty;

        const transactions = ledgerRows.map(row => {
            runningBalance +=
                Number(row.quantityIn || 0) -
                Number(row.quantityOut || 0);

            return {
                date: row.date,
                sourceType: row.sourceType,
                sourceId: row.sourceId,
                sourceLineId: row.sourceLineId,
                referenceNo: row.referenceNo,
                description: row.description,
                quantityIn: roundQuantity(
                    row.quantityIn,
                    rawMaterial.decimal_places
                ),
                quantityOut: roundQuantity(
                    row.quantityOut,
                    rawMaterial.decimal_places
                ),
                rate: Number(row.rate || 0),
                balanceQty: roundQuantity(
                    runningBalance,
                    rawMaterial.decimal_places
                ),
                remarks: row.remarks
            };
        });

        const periodIn = ledgerRows.reduce(
            (total, row) => total + Number(row.quantityIn || 0),
            0
        );

        const periodOut = ledgerRows.reduce(
            (total, row) => total + Number(row.quantityOut || 0),
            0
        );

        const closingQty = runningBalance;

        return res.json({
            success: true,
            outletId,
            fromDate,
            toDate,
            rawMaterial: {
                rawMaterialId: rawMaterial.raw_material_id,
                materialCode: rawMaterial.material_code,
                materialName: rawMaterial.material_name,
                unitId: rawMaterial.unit_id,
                unitCode: rawMaterial.unit_code,
                unitName: rawMaterial.unit_name,
                decimalPlaces: Number(rawMaterial.decimal_places || 0)
            },
            summary: {
                openingQty: roundQuantity(
                    openingQty,
                    rawMaterial.decimal_places
                ),
                periodInQty: roundQuantity(
                    periodIn,
                    rawMaterial.decimal_places
                ),
                periodOutQty: roundQuantity(
                    periodOut,
                    rawMaterial.decimal_places
                ),
                closingQty: roundQuantity(
                    closingQty,
                    rawMaterial.decimal_places
                ),
                negativeStock: closingQty < -0.0000001
            },
            transactions
        });

    } catch (error) {
        console.error(
            'Get dynamic stock item ledger error:',
            error
        );

        return res.status(error.statusCode || 500).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to calculate dynamic stock item ledger'
        });

    } finally {
        connection.release();
    }
};
