const db = require('../database');
const crypto = require('crypto');




// ============================================================
// HELPER: CHECK OUTLET ACCESS
// ============================================================

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

function isValidDateString(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) {
        return false;
    }

    const date = new Date(`${value}T00:00:00Z`);
    return !Number.isNaN(date.getTime()) &&
        date.toISOString().slice(0, 10) === value;
}

function getAdjustmentTransactionType(adjustmentType) {
    switch (adjustmentType) {
        case 'OPENING':
            return 'OPENING';
        case 'INCREASE':
            return 'ADJUSTMENT_IN';
        case 'DECREASE':
            return 'ADJUSTMENT_OUT';
        case 'WASTAGE':
            return 'WASTAGE';
        case 'DAMAGE':
            return 'DAMAGE';
        default:
            return null;
    }
}

function normalizePositiveNumber(value, fieldName) {
    const number = Number(value);
    if (!Number.isFinite(number) || number <= 0) {
        throw new Error(`${fieldName} must be greater than zero`);
    }
    return number;
}

function normalizeNonNegativeNumber(value, fieldName) {
    const number = Number(value ?? 0);
    if (!Number.isFinite(number) || number < 0) {
        throw new Error(`${fieldName} cannot be negative`);
    }
    return number;
}

// ============================================================
// HELPER: GET RAW MATERIAL
// ============================================================

async function getRawMaterial(connection, rawMaterialId, outletId) {
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
        WHERE rm.raw_material_id = ?
          AND rm.outlet_id = ?
        LIMIT 1
        `,
        [rawMaterialId, outletId]
    );

    return rows.length > 0 ? rows[0] : null;
}

// ============================================================
// HELPER: GET CURRENT STOCK FOR UPDATE
// ============================================================

async function getCurrentStockForUpdate(connection, outletId, rawMaterialId) {
    const [rows] = await connection.query(
        `
        SELECT
            stock_balance_id,
            current_qty,
            average_rate
        FROM stock_balance
        WHERE outlet_id = ?
          AND raw_material_id = ?
        FOR UPDATE
        `,
        [outletId, rawMaterialId]
    );

    if (rows.length === 0) {
        return {
            stockBalanceId: null,
            currentQty: 0,
            averageRate: 0
        };
    }

    return {
        stockBalanceId: rows[0].stock_balance_id,
        currentQty: Number(rows[0].current_qty || 0),
        averageRate: Number(rows[0].average_rate || 0)
    };
}

// ============================================================
// HELPER: UPSERT CURRENT STOCK
// ============================================================

async function upsertStockBalance(
    connection,
    outletId,
    rawMaterialId,
    currentQty,
    averageRate
) {
    await connection.query(
        `
        INSERT INTO stock_balance (
            outlet_id,
            raw_material_id,
            current_qty,
            average_rate
        )
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            current_qty = VALUES(current_qty),
            average_rate = VALUES(average_rate)
        `,
        [
            outletId,
            rawMaterialId,
            currentQty,
            averageRate
        ]
    );
}

// ============================================================
// HELPER: CREATE STOCK TRANSACTION
// ============================================================

async function createStockTransaction(
    connection,
    {
        outletId,
        rawMaterialId,
        transactionDate,
        transactionType,
        referenceId,
        qtyIn,
        qtyOut,
        rate,
        amount,
        balanceQty,
        remarks,
        createdBy
    }
) {
    const transactionUuid = crypto.randomUUID();

    const [result] = await connection.query(
        `
        INSERT INTO stock_transaction (
            transaction_uuid,
            outlet_id,
            raw_material_id,
            transaction_date,
            transaction_type,
            reference_type,
            reference_id,
            qty_in,
            qty_out,
            rate,
            amount,
            balance_qty,
            remarks,
            created_by
        )
        VALUES (?, ?, ?, ?, ?, 'STOCK_ADJUSTMENT', ?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
            transactionUuid,
            outletId,
            rawMaterialId,
            transactionDate,
            transactionType,
            referenceId,
            qtyIn,
            qtyOut,
            rate,
            amount,
            balanceQty,
            remarks || null,
            createdBy
        ]
    );

    return result.insertId;
}

// ============================================================
// CREATE STOCK ADJUSTMENT
//
// POST /inventory/stock-adjustments
//
// adjustmentType:
//   OPENING
//   INCREASE
//   DECREASE
//   WASTAGE
//   DAMAGE
//
// IMPORTANT:
// - This endpoint posts the adjustment immediately.
// - qty is entered in the raw material's own stock unit.
// - One adjustment can contain multiple items.
// - All header/item/stock transactions are committed together.
// ============================================================

exports.createStockAdjustment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.body.outletId);
        const adjustmentDate = String(req.body.adjustmentDate || '');
        const adjustmentType = String(req.body.adjustmentType || '').toUpperCase();
      //  const adjustmentNo = String(req.body.adjustmentNo || '').trim();
        const reason = String(req.body.reason || '').trim() || null;
        const items = Array.isArray(req.body.items) ? req.body.items : [];
        console.log(adjustmentDate);    
        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!isValidDateString(adjustmentDate)) {
            return res.status(400).json({
                success: false,
                message: 'Valid adjustmentDate is required in YYYY-MM-DD format'
            });
        }

        if (!['OPENING', 'INCREASE', 'DECREASE', 'WASTAGE', 'DAMAGE'].includes(adjustmentType)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid adjustmentType'
            });
        }

     /*   if (!adjustmentNo) {
            return res.status(400).json({
                success: false,
                message: 'adjustmentNo is required'
            });
        }*/

        if (items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'At least one adjustment item is required'
            });
        }

        const outlet = await getAuthorizedOutlet(connection, outletId, req);

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

    
        const transactionType = getAdjustmentTransactionType(adjustmentType);

        await connection.beginTransaction();

        const adjustmentUuid = crypto.randomUUID();

        const [adjustmentResult] = await connection.query(
            `
            INSERT INTO stock_adjustment (
                adjustment_uuid,
                outlet_id,
                
                adjustment_date,
                adjustment_type,
                reason,
                created_by
            )
            VALUES (?, ?, ?, ?, ?, ?)
            `,
            [
                adjustmentUuid,
                outletId,
               
                adjustmentDate,
                adjustmentType,
                reason,
                req.user.userId
            ]
        );

        const stockAdjustmentId = adjustmentResult.insertId;
        const adjustmentNo = `ADJ-${String(stockAdjustmentId).padStart(6, '0')}`;

        await connection.query(
        `UPDATE stock_adjustment
         SET adjustment_no = ?
         WHERE stock_adjustment_id = ?`,
        [adjustmentNo, stockAdjustmentId]
        );
        const responseItems = [];

        for (const item of items) {
            const rawMaterialId = Number(item.rawMaterialId);
            const unitId = Number(item.unitId);
            const qty = normalizePositiveNumber(item.qty, 'qty');
            const rateInput = normalizeNonNegativeNumber(item.rate, 'rate');

            if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
                throw new Error('Invalid rawMaterialId');
            }

            if (!Number.isInteger(unitId) || unitId <= 0) {
                throw new Error('Invalid unitId');
            }

            const rawMaterial = await getRawMaterial(
                connection,
                rawMaterialId,
                outletId
            );

            if (!rawMaterial) {
                throw new Error(`Raw material ${rawMaterialId} does not belong to the selected outlet`);
            }

            // Phase 3 keeps stock adjustments in the raw material's own unit.
            // Conversion factors are handled by purchase/other specialized flows.
            if (unitId !== Number(rawMaterial.unit_id)) {
                throw new Error(
                    `Unit mismatch for ${rawMaterial.material_code}. Use unitId ${rawMaterial.unit_id} (${rawMaterial.unit_code})`
                );
            }

            const stock = await getCurrentStockForUpdate(
                connection,
                outletId,
                rawMaterialId
            );

            let qtyIn = 0;
            let qtyOut = 0;
            let appliedRate = rateInput;
            let newAverageRate = stock.averageRate;

            if (adjustmentType === 'OPENING' || adjustmentType === 'INCREASE') {
                if (appliedRate <= 0) {
                    throw new Error(
                        `rate is required and must be greater than zero for ${adjustmentType}`
                    );
                }

                qtyIn = qty;

                if (stock.currentQty > 0 && stock.averageRate > 0) {
                    const oldValue = stock.currentQty * stock.averageRate;
                    const newValue = qtyIn * appliedRate;
                    newAverageRate = (oldValue + newValue) /
                        (stock.currentQty + qtyIn);
                } else {
                    newAverageRate = appliedRate;
                }
            } else {
                qtyOut = qty;
                appliedRate = rateInput > 0
                    ? rateInput
                    : stock.averageRate;

                if (stock.currentQty < qtyOut) {
                    throw new Error(
                        `Insufficient stock for ${rawMaterial.material_code}. Current ${rawMaterial.unit_code} quantity is ${stock.currentQty}`
                    );
                }

                // Outward movements do not change the weighted average rate.
                newAverageRate = stock.averageRate;
            }

            const newCurrentQty = stock.currentQty + qtyIn - qtyOut;
            const amount = (qtyIn || qtyOut) * appliedRate;

            const [itemResult] = await connection.query(
                `
                INSERT INTO stock_adjustment_item (
                    stock_adjustment_id,
                    raw_material_id,
                    qty,
                    unit_id,
                    rate,
                    amount
                )
                VALUES (?, ?, ?, ?, ?, ?)
                `,
                [
                    stockAdjustmentId,
                    rawMaterialId,
                    qty,
                    unitId,
                    appliedRate,
                    amount
                ]
            );

            const stockTransactionId = await createStockTransaction(
                connection,
                {
                    outletId,
                    rawMaterialId,
                    transactionDate: `${adjustmentDate} 00:00:00`,
                    transactionType,
                    referenceId: stockAdjustmentId,
                    qtyIn,
                    qtyOut,
                    rate: appliedRate,
                    amount,
                    balanceQty: newCurrentQty,
                    remarks: reason,
                    createdBy: req.user.userId
                }
            );

            await upsertStockBalance(
                connection,
                outletId,
                rawMaterialId,
                newCurrentQty,
                newAverageRate
            );

            responseItems.push({
                stockAdjustmentItemId: itemResult.insertId,
                rawMaterialId,
                materialCode: rawMaterial.material_code,
                materialName: rawMaterial.material_name,
                qty,
                unitId,
                unitCode: rawMaterial.unit_code,
                unitName: rawMaterial.unit_name,
                rate: Number(appliedRate.toFixed(4)),
                amount: Number(amount.toFixed(2)),
                qtyIn: Number(qtyIn.toFixed(3)),
                qtyOut: Number(qtyOut.toFixed(3)),
                balanceQty: Number(newCurrentQty.toFixed(3)),
                averageRate: Number(newAverageRate.toFixed(4)),
                stockTransactionId
            });
        }

        await connection.commit();

        return res.status(201).json({
            success: true,
            message: 'Stock adjustment posted successfully',
            adjustment: {
                stockAdjustmentId,
                adjustmentUuid,
                outletId,
                adjustmentNo,
                adjustmentDate,
                adjustmentType,
                reason,
                createdBy: req.user.userId,
                items: responseItems
            }
        });

    } catch (error) {
        try {
            await connection.rollback();
        } catch (_) {
            // Ignore rollback errors.
        }

        console.error(
            'Create stock adjustment error:',
            error
        );

        if (
            error.code === 'ER_DUP_ENTRY' ||
            /Adjustment number already exists/i.test(error.message)
        ) {
            return res.status(409).json({
                success: false,
                message: 'Adjustment number already exists for this outlet'
            });
        }

        return res.status(400).json({
            success: false,
            message: error.message || 'Unable to post stock adjustment'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// GET STOCK ADJUSTMENTS
//
// GET /inventory/stock-adjustments?outletId=1&fromDate=...&toDate=...
// Optional: adjustmentType
// ============================================================

exports.getStockAdjustments = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const fromDate = req.query.fromDate ? String(req.query.fromDate) : null;
        const toDate = req.query.toDate ? String(req.query.toDate) : null;
        const adjustmentType = req.query.adjustmentType
            ? String(req.query.adjustmentType).toUpperCase()
            : null;

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (fromDate && !isValidDateString(fromDate)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid fromDate'
            });
        }

        if (toDate && !isValidDateString(toDate)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid toDate'
            });
        }

        if (fromDate && toDate && fromDate > toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be greater than toDate'
            });
        }

        if (
            adjustmentType &&
            !['OPENING', 'INCREASE', 'DECREASE', 'WASTAGE', 'DAMAGE'].includes(adjustmentType)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid adjustmentType'
            });
        }

        const outlet = await getAuthorizedOutlet(connection, outletId, req);

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        const where = ['sa.outlet_id = ?'];
        const params = [outletId];

        if (fromDate) {
            where.push('sa.adjustment_date >= ?');
            params.push(fromDate);
        }

        if (toDate) {
            where.push('sa.adjustment_date <= ?');
            params.push(toDate);
        }

        if (adjustmentType) {
            where.push('sa.adjustment_type = ?');
            params.push(adjustmentType);
        }

        const [rows] = await connection.query(
            `
            SELECT
                sa.stock_adjustment_id,
                sa.adjustment_uuid,
                sa.outlet_id,
                sa.adjustment_no,
                sa.adjustment_date,
                sa.adjustment_type,
                sa.reason,
                sa.created_by,
                COUNT(sai.stock_adjustment_item_id) AS item_count,
                COALESCE(SUM(sai.amount), 0) AS total_amount
            FROM stock_adjustment sa
            LEFT JOIN stock_adjustment_item sai
                ON sai.stock_adjustment_id = sa.stock_adjustment_id
            WHERE ${where.join(' AND ')}
            GROUP BY
                sa.stock_adjustment_id,
                sa.adjustment_uuid,
                sa.outlet_id,
                sa.adjustment_no,
                sa.adjustment_date,
                sa.adjustment_type,
                sa.reason,
                sa.created_by
            ORDER BY sa.adjustment_date DESC, sa.stock_adjustment_id DESC
            `,
            params
        );

        return res.json({
            success: true,
            adjustments: rows.map(row => ({
                stockAdjustmentId: row.stock_adjustment_id,
                adjustmentUuid: row.adjustment_uuid,
                outletId: row.outlet_id,
                adjustmentNo: row.adjustment_no,
                adjustmentDate: row.adjustment_date,
                adjustmentType: row.adjustment_type,
                reason: row.reason,
                createdBy: row.created_by,
                itemCount: Number(row.item_count || 0),
                totalAmount: Number(row.total_amount || 0)
            }))
        });

    } catch (error) {
        console.error(
            'Get stock adjustments error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get stock adjustments'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// GET STOCK ADJUSTMENT DETAIL
//
// GET /inventory/stock-adjustments/:adjustmentId?outletId=1
// ============================================================

exports.getStockAdjustment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const stockAdjustmentId = Number(req.params.adjustmentId);
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(stockAdjustmentId) || stockAdjustmentId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid adjustmentId'
            });
        }

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        const outlet = await getAuthorizedOutlet(connection, outletId, req);

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        const [headerRows] = await connection.query(
            `
            SELECT
                sa.stock_adjustment_id,
                sa.adjustment_uuid,
                sa.outlet_id,
                sa.adjustment_no,
                sa.adjustment_date,
                sa.adjustment_type,
                sa.reason,
                sa.created_by
            FROM stock_adjustment sa
            WHERE sa.stock_adjustment_id = ?
              AND sa.outlet_id = ?
            LIMIT 1
            `,
            [stockAdjustmentId, outletId]
        );

        if (headerRows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Stock adjustment not found'
            });
        }

        const [itemRows] = await connection.query(
            `
            SELECT
                sai.stock_adjustment_item_id,
                sai.stock_adjustment_id,
                sai.raw_material_id,
                rm.material_code,
                rm.material_name,
                sai.qty,
                sai.unit_id,
                u.unit_code,
                u.unit_name,
                sai.rate,
                sai.amount
            FROM stock_adjustment_item sai
            INNER JOIN raw_material rm
                ON rm.raw_material_id = sai.raw_material_id
               AND rm.outlet_id = ?
            INNER JOIN unit u
                ON u.unit_id = sai.unit_id
            WHERE sai.stock_adjustment_id = ?
            ORDER BY sai.stock_adjustment_item_id
            `,
            [outletId, stockAdjustmentId]
        );

        const header = headerRows[0];

        return res.json({
            success: true,
            adjustment: {
                stockAdjustmentId: header.stock_adjustment_id,
                adjustmentUuid: header.adjustment_uuid,
                outletId: header.outlet_id,
                adjustmentNo: header.adjustment_no,
                adjustmentDate: header.adjustment_date,
                adjustmentType: header.adjustment_type,
                reason: header.reason,
                createdBy: header.created_by,
                items: itemRows.map(row => ({
                    stockAdjustmentItemId: row.stock_adjustment_item_id,
                    stockAdjustmentId: row.stock_adjustment_id,
                    rawMaterialId: row.raw_material_id,
                    materialCode: row.material_code,
                    materialName: row.material_name,
                    qty: Number(row.qty || 0),
                    unitId: row.unit_id,
                    unitCode: row.unit_code,
                    unitName: row.unit_name,
                    rate: Number(row.rate || 0),
                    amount: Number(row.amount || 0)
                }))
            }
        });

    } catch (error) {
        console.error(
            'Get stock adjustment error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get stock adjustment'
        });

    } finally {
        connection.release();
    }
};
