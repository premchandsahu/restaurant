const db = require('../database');

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
        [
            outletId,
            req.user.companyId,
            req.user.userId
        ]
    );

    return rows.length > 0 ? rows[0] : null;
}

// ============================================================
// HELPER: VALIDATE DATE
// ============================================================

function isValidDateString(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) {
        return false;
    }

    const date = new Date(`${value}T00:00:00Z`);

    return !Number.isNaN(date.getTime()) &&
        date.toISOString().slice(0, 10) === value;
}

// ============================================================
// HELPER: GET AND VALIDATE REPORT DATES
// ============================================================

function getReportDates(req, res) {
    const fromDate = String(req.query.fromDate || '');
    const toDate = String(req.query.toDate || '');

    if (!isValidDateString(fromDate)) {
        res.status(400).json({
            success: false,
            message: 'Valid fromDate is required in YYYY-MM-DD format'
        });
        return null;
    }

    if (!isValidDateString(toDate)) {
        res.status(400).json({
            success: false,
            message: 'Valid toDate is required in YYYY-MM-DD format'
        });
        return null;
    }

    if (fromDate > toDate) {
        res.status(400).json({
            success: false,
            message: 'fromDate cannot be greater than toDate'
        });
        return null;
    }

    return { fromDate, toDate };
}

// ============================================================
// HELPER: FETCH RAW MATERIAL FOR OUTLET
// ============================================================

async function getRawMaterialForOutlet(connection, rawMaterialId, outletId) {
    const [rows] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
            rm.raw_material_uuid,
            rm.outlet_id,
            rm.inventory_category_id,
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
// GET STOCK SUMMARY
//
// GET /inventory/stock/summary
//
// Required query:
//   outletId
//   fromDate
//   toDate
//
// Optional:
//   categoryId
//   rawMaterialId
//   search
//   active=true|false
//
// IMPORTANT:
//   Opening/period/closing quantities are calculated dynamically
//   from stock_transaction. stock_balance is not used for the
//   report calculation.
// ============================================================

exports.getStockSummary = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        const dates = getReportDates(req, res);
        if (!dates) {
            return;
        }

        const outlet = await getAuthorizedOutlet(
            connection,
            outletId,
            req
        );

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        const categoryId = req.query.categoryId === undefined ||
            req.query.categoryId === ''
            ? null
            : Number(req.query.categoryId);

        const rawMaterialId = req.query.rawMaterialId === undefined ||
            req.query.rawMaterialId === ''
            ? null
            : Number(req.query.rawMaterialId);

        const search = String(req.query.search || '').trim();

        const activeQuery = req.query.active;
        let activeValue = null;

        if (activeQuery !== undefined && activeQuery !== '') {
            activeValue = String(activeQuery).toLowerCase() === 'true'
                ? 1
                : 0;
        }

        if (categoryId !== null &&
            (!Number.isInteger(categoryId) || categoryId <= 0)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid categoryId'
            });
        }

        if (rawMaterialId !== null &&
            (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid rawMaterialId'
            });
        }

        const where = [
            'rm.outlet_id = ?'
        ];

        const params = [outletId];

        if (categoryId !== null) {
            where.push('rm.inventory_category_id = ?');
            params.push(categoryId);
        }

        if (rawMaterialId !== null) {
            where.push('rm.raw_material_id = ?');
            params.push(rawMaterialId);
        }

        if (search !== '') {
            where.push(`
                (
                    rm.material_code LIKE ?
                    OR rm.material_name LIKE ?
                )
            `);
            const searchValue = `%${search}%`;
            params.push(searchValue, searchValue);
        }

        if (activeValue !== null) {
            where.push('rm.is_active = ?');
            params.push(activeValue);
        }

        // Transaction parameters are intentionally separate from the
        // raw-material filters because they are used inside JOIN conditions.
        const fromDateTime = `${dates.fromDate} 00:00:00`;
        const toDateTime = `${dates.toDate} 23:59:59.999999`;

        const [rows] = await connection.query(
            `
            SELECT
                rm.raw_material_id,
                rm.material_code,
                rm.material_name,
                rm.inventory_category_id,
                ic.category_code,
                ic.category_name,
                rm.unit_id,
                u.unit_code,
                u.unit_name,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date < ?
                        THEN st.qty_in - st.qty_out
                        ELSE 0
                    END
                ), 0) AS opening_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'PURCHASE'
                        THEN st.qty_in
                        ELSE 0
                    END
                ), 0) AS purchase_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'PURCHASE_RETURN'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS purchase_return_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'SALE_CONSUMPTION'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS sale_consumption_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'WASTAGE'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS wastage_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'DAMAGE'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS damage_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'ADJUSTMENT_IN'
                        THEN st.qty_in
                        ELSE 0
                    END
                ), 0) AS adjustment_in_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'ADJUSTMENT_OUT'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS adjustment_out_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'TRANSFER_IN'
                        THEN st.qty_in
                        ELSE 0
                    END
                ), 0) AS transfer_in_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                         AND st.transaction_type = 'TRANSFER_OUT'
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS transfer_out_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                        THEN st.qty_in
                        ELSE 0
                    END
                ), 0) AS period_in_qty,

                COALESCE(SUM(
                    CASE
                        WHEN st.transaction_date >= ?
                         AND st.transaction_date <= ?
                        THEN st.qty_out
                        ELSE 0
                    END
                ), 0) AS period_out_qty

            FROM raw_material rm

            LEFT JOIN inventory_category ic
                ON ic.inventory_category_id = rm.inventory_category_id

            INNER JOIN unit u
                ON u.unit_id = rm.unit_id

            LEFT JOIN stock_transaction st
                ON st.raw_material_id = rm.raw_material_id
               AND st.outlet_id = rm.outlet_id

            WHERE ${where.join(' AND ')}

            GROUP BY
                rm.raw_material_id,
                rm.material_code,
                rm.material_name,
                rm.inventory_category_id,
                ic.category_code,
                ic.category_name,
                rm.unit_id,
                u.unit_code,
                u.unit_name

            ORDER BY
                rm.material_name,
                rm.raw_material_id
            `,
            [
                fromDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                fromDateTime,
                toDateTime,

                ...params
            ]
        );

        const summary = rows.map(row => {
            const openingQty = Number(row.opening_qty || 0);
            const periodInQty = Number(row.period_in_qty || 0);
            const periodOutQty = Number(row.period_out_qty || 0);
            const closingQty = openingQty + periodInQty - periodOutQty;

            return {
                rawMaterialId: row.raw_material_id,
                materialCode: row.material_code,
                materialName: row.material_name,
                inventoryCategoryId: row.inventory_category_id === null
                    ? null
                    : Number(row.inventory_category_id),
                categoryCode: row.category_code,
                categoryName: row.category_name,
                unitId: row.unit_id,
                unitCode: row.unit_code,
                unitName: row.unit_name,

                openingQty,

                purchaseQty: Number(row.purchase_qty || 0),
                purchaseReturnQty: Number(row.purchase_return_qty || 0),
                saleConsumptionQty: Number(row.sale_consumption_qty || 0),
                wastageQty: Number(row.wastage_qty || 0),
                damageQty: Number(row.damage_qty || 0),
                adjustmentInQty: Number(row.adjustment_in_qty || 0),
                adjustmentOutQty: Number(row.adjustment_out_qty || 0),
                transferInQty: Number(row.transfer_in_qty || 0),
                transferOutQty: Number(row.transfer_out_qty || 0),

                periodInQty,
                periodOutQty,
                closingQty
            };
        });

        return res.json({
            success: true,
            report: {
                outletId,
                fromDate: dates.fromDate,
                toDate: dates.toDate,
                items: summary
            }
        });

    } catch (error) {
        console.error('Get stock summary error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get stock summary'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// GET STOCK ITEM LEDGER
//
// GET /inventory/stock/ledger
//
// Required query:
//   outletId
//   rawMaterialId
//   fromDate
//   toDate
// ============================================================

exports.getStockLedger = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const rawMaterialId = Number(req.query.rawMaterialId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid rawMaterialId is required'
            });
        }

        const dates = getReportDates(req, res);
        if (!dates) {
            return;
        }

        const outlet = await getAuthorizedOutlet(
            connection,
            outletId,
            req
        );

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        const rawMaterial = await getRawMaterialForOutlet(
            connection,
            rawMaterialId,
            outletId
        );

        if (!rawMaterial) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found for outlet'
            });
        }

        const fromDateTime = `${dates.fromDate} 00:00:00`;
        const toDateTime = `${dates.toDate} 23:59:59.999999`;

        const [openingRows] = await connection.query(
            `
            SELECT
                COALESCE(SUM(qty_in - qty_out), 0) AS opening_qty
            FROM stock_transaction
            WHERE outlet_id = ?
              AND raw_material_id = ?
              AND transaction_date < ?
            `,
            [
                outletId,
                rawMaterialId,
                fromDateTime
            ]
        );

        const openingQty = Number(
            openingRows[0]?.opening_qty || 0
        );

        const [transactions] = await connection.query(
            `
            SELECT
                stock_transaction_id,
                transaction_uuid,
                transaction_date,
                transaction_type,
                reference_type,
                reference_id,
                qty_in,
                qty_out,
                rate,
                amount,
                remarks,
                created_by
            FROM stock_transaction
            WHERE outlet_id = ?
              AND raw_material_id = ?
              AND transaction_date >= ?
              AND transaction_date <= ?
            ORDER BY
                transaction_date,
                stock_transaction_id
            `,
            [
                outletId,
                rawMaterialId,
                fromDateTime,
                toDateTime
            ]
        );

        let runningBalance = openingQty;

        const ledger = transactions.map(row => {
            const qtyIn = Number(row.qty_in || 0);
            const qtyOut = Number(row.qty_out || 0);

            runningBalance += qtyIn - qtyOut;

            return {
                stockTransactionId: row.stock_transaction_id,
                transactionUuid: row.transaction_uuid,
                transactionDate: row.transaction_date,
                transactionType: row.transaction_type,
                referenceType: row.reference_type,
                referenceId: row.reference_id === null
                    ? null
                    : Number(row.reference_id),
                qtyIn,
                qtyOut,
                rate: Number(row.rate || 0),
                amount: Number(row.amount || 0),
                runningBalanceQty: runningBalance,
                remarks: row.remarks,
                createdBy: row.created_by === null
                    ? null
                    : Number(row.created_by)
            };
        });

        const periodInQty = ledger.reduce(
            (sum, row) => sum + row.qtyIn,
            0
        );

        const periodOutQty = ledger.reduce(
            (sum, row) => sum + row.qtyOut,
            0
        );

        const closingQty = runningBalance;

        return res.json({
            success: true,
            report: {
                outletId,
                fromDate: dates.fromDate,
                toDate: dates.toDate,
                item: {
                    rawMaterialId: rawMaterial.raw_material_id,
                    materialCode: rawMaterial.material_code,
                    materialName: rawMaterial.material_name,
                    inventoryCategoryId: rawMaterial.inventory_category_id === null
                        ? null
                        : Number(rawMaterial.inventory_category_id),
                    unitId: rawMaterial.unit_id,
                    unitCode: rawMaterial.unit_code,
                    unitName: rawMaterial.unit_name,
                    decimalPlaces: Number(rawMaterial.decimal_places || 0)
                },
                openingQty,
                periodInQty,
                periodOutQty,
                closingQty,
                transactions: ledger
            }
        });

    } catch (error) {
        console.error('Get stock ledger error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get stock ledger'
        });

    } finally {
        connection.release();
    }
};
