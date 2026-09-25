const db = require('../database');

const PAYMENT_MODES = new Set([
    'CASH',
    'CARD',
    'UPI',
    'BANK',
    'WALLET',
    'CREDIT',
    'OTHER'
]);

function toNumber(value) {
    return Number(value || 0);
}

function round2(value) {
    return Number(Number(value || 0).toFixed(2));
}

function normalizeDateTime(value) {
    if (!value) return null;

    const text = String(value).trim();
    if (!text) return null;

    if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
        return `${text} 00:00:00`;
    }

    const date = new Date(text);
    if (Number.isNaN(date.getTime())) return null;

    const pad = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function isValidDateOnly(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) {
        return false;
    }

    const d = new Date(`${value}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

async function getAuthorizedOutlet(connection, outletId, req) {
    const [rows] = await connection.query(
        `
        SELECT
            o.outlet_id,
            o.company_id
        FROM outlet o
        INNER JOIN user_outlet uo
            ON uo.outlet_id = o.outlet_id
           AND uo.user_id = ?
        WHERE o.outlet_id = ?
          AND o.is_active = 1
          AND o.company_id = ?
        LIMIT 1
        `,
        [req.user.userId, outletId, req.user.companyId]
    );

    if (!rows.length) {
        const error = new Error('Outlet is not authorized');
        error.statusCode = 403;
        throw error;
    }

    return rows[0];
}

async function getSupplier(connection, supplierId, req) {
    const [rows] = await connection.query(
        `
        SELECT
            supplier_id,
            company_id,
            supplier_code,
            supplier_name,
            mobile,
            email,
            gstin,
            opening_balance,
            is_active
        FROM supplier
        WHERE supplier_id = ?
          AND company_id = ?
          AND is_active = 1
        LIMIT 1
        `,
        [supplierId, req.user.companyId]
    );

    if (!rows.length) {
        const error = new Error('Supplier not found');
        error.statusCode = 404;
        throw error;
    }

    return rows[0];
}

function normalizeAllocations(allocations) {
    if (allocations === undefined || allocations === null) {
        return [];
    }

    if (!Array.isArray(allocations)) {
        const error = new Error('allocations must be an array');
        error.statusCode = 400;
        throw error;
    }

    const map = new Map();

    for (const row of allocations) {
        const purchaseId = Number(row?.purchaseId);
        const amount = Number(row?.amount);

        if (!Number.isInteger(purchaseId) || purchaseId <= 0) {
            const error = new Error('Invalid purchaseId in allocations');
            error.statusCode = 400;
            throw error;
        }

        if (!Number.isFinite(amount) || amount <= 0) {
            const error = new Error('Allocation amount must be greater than zero');
            error.statusCode = 400;
            throw error;
        }

        map.set(
            purchaseId,
            round2((map.get(purchaseId) || 0) + amount)
        );
    }

    return [...map.entries()].map(([purchaseId, amount]) => ({
        purchaseId,
        amount
    }));
}

async function lockPurchasesForAllocation(connection, supplierId, allocationRows) {
    if (!allocationRows.length) return [];

    const ids = allocationRows.map((row) => row.purchaseId);
    const placeholders = ids.map(() => '?').join(',');

    const [rows] = await connection.query(
        `
        SELECT
            p.purchase_id,
            p.supplier_id,
            p.outlet_id,
            p.purchase_no,
            p.status,
            p.grand_total
        FROM purchase p
        WHERE p.purchase_id IN (${placeholders})
        FOR UPDATE
        `,
        ids
    );

    const byId = new Map(rows.map((row) => [Number(row.purchase_id), row]));

    for (const allocation of allocationRows) {
        const purchase = byId.get(allocation.purchaseId);

        if (!purchase) {
            const error = new Error(`Purchase ${allocation.purchaseId} not found`);
            error.statusCode = 404;
            throw error;
        }

        if (Number(purchase.supplier_id) !== Number(supplierId)) {
            const error = new Error(
                `Purchase ${allocation.purchaseId} does not belong to this supplier`
            );
            error.statusCode = 400;
            throw error;
        }

        if (purchase.status !== 'POSTED') {
            const error = new Error(
                `Purchase ${allocation.purchaseId} must be POSTED before payment allocation`
            );
            error.statusCode = 400;
            throw error;
        }
    }

    return rows;
}

async function getPurchaseAllocatedAmount(connection, purchaseId) {
    const [rows] = await connection.query(
        `
        SELECT COALESCE(SUM(spa.allocated_amount), 0) AS allocated_amount
        FROM supplier_payment_allocation spa
        INNER JOIN supplier_payment sp
            ON sp.payment_id = spa.payment_id
        WHERE spa.purchase_id = ?
          AND sp.status = 'SUCCESS'
        `,
        [purchaseId]
    );

    return toNumber(rows[0]?.allocated_amount);
}

async function refreshPurchaseSnapshot(connection, purchaseId) {
    const [rows] = await connection.query(
        `
        SELECT grand_total, status
        FROM purchase
        WHERE purchase_id = ?
        FOR UPDATE
        `,
        [purchaseId]
    );

    if (!rows.length || rows[0].status !== 'POSTED') {
        return;
    }

    const grandTotal = toNumber(rows[0].grand_total);
    const paidAmount = await getPurchaseAllocatedAmount(connection, purchaseId);
    const boundedPaid = Math.min(grandTotal, paidAmount);

    await connection.query(
        `
        UPDATE purchase
        SET
            paid_amount = ?,
            balance_amount = ?
        WHERE purchase_id = ?
        `,
        [
            round2(boundedPaid),
            round2(Math.max(0, grandTotal - boundedPaid)),
            purchaseId
        ]
    );
}

async function getPaymentWithAllocations(connection, paymentId) {
    const [paymentRows] = await connection.query(
        `
        SELECT
            sp.payment_id,
            sp.supplier_id,
            sp.outlet_id,
            sp.payment_date,
            sp.payment_mode,
            sp.amount,
            sp.reference_no,
            sp.paid_by,
            sp.remarks,
            sp.status,
            sp.created_at
        FROM supplier_payment sp
        WHERE sp.payment_id = ?
        LIMIT 1
        `,
        [paymentId]
    );

    if (!paymentRows.length) return null;

    const [allocationRows] = await connection.query(
        `
        SELECT
            spa.allocation_id,
            spa.payment_id,
            spa.purchase_id,
            spa.allocated_amount,
            p.purchase_no,
            p.purchase_date,
            p.grand_total,
            p.status AS purchase_status
        FROM supplier_payment_allocation spa
        INNER JOIN purchase p
            ON p.purchase_id = spa.purchase_id
        WHERE spa.payment_id = ?
        ORDER BY spa.allocation_id
        `,
        [paymentId]
    );

    const payment = paymentRows[0];
    const amount = toNumber(payment.amount);
    const allocatedAmount = allocationRows.reduce(
        (sum, row) => sum + toNumber(row.allocated_amount),
        0
    );

    return {
        paymentId: payment.payment_id,
        supplierId: payment.supplier_id,
        outletId: payment.outlet_id,
        paymentDate: payment.payment_date,
        paymentMode: payment.payment_mode,
        amount,
        allocatedAmount: round2(allocatedAmount),
        unallocatedAmount: round2(Math.max(0, amount - allocatedAmount)),
        referenceNo: payment.reference_no,
        paidBy: payment.paid_by,
        remarks: payment.remarks,
        status: payment.status,
        createdAt: payment.created_at,
        allocations: allocationRows.map((row) => ({
            allocationId: row.allocation_id,
            paymentId: row.payment_id,
            purchaseId: row.purchase_id,
            purchaseNo: row.purchase_no,
            purchaseDate: row.purchase_date,
            purchaseGrandTotal: toNumber(row.grand_total),
            allocatedAmount: toNumber(row.allocated_amount),
            purchaseStatus: row.purchase_status
        }))
    };
}

async function validateAndCalculateAllocations(connection, supplierId, paymentAmount, allocationRows) {
    const purchases = await lockPurchasesForAllocation(
        connection,
        supplierId,
        allocationRows
    );

    const purchaseMap = new Map(
        purchases.map((row) => [Number(row.purchase_id), row])
    );

    let totalAllocation = 0;
    const calculated = [];

    for (const allocation of allocationRows) {
        const purchase = purchaseMap.get(allocation.purchaseId);
        const alreadyAllocated = await getPurchaseAllocatedAmount(
            connection,
            allocation.purchaseId
        );

        const outstanding = round2(
            Math.max(0, toNumber(purchase.grand_total) - alreadyAllocated)
        );

        if (allocation.amount > outstanding + 0.005) {
            const error = new Error(
                `Allocation for purchase ${allocation.purchaseId} exceeds outstanding balance ${outstanding.toFixed(2)}`
            );
            error.statusCode = 400;
            throw error;
        }

        totalAllocation = round2(totalAllocation + allocation.amount);

        calculated.push({
            purchaseId: allocation.purchaseId,
            purchaseNo: purchase.purchase_no,
            amount: allocation.amount,
            previousAllocatedAmount: round2(alreadyAllocated),
            purchaseOutstandingBeforePayment: outstanding,
            purchaseOutstandingAfterPayment: round2(
                Math.max(0, outstanding - allocation.amount)
            )
        });
    }

    if (totalAllocation > paymentAmount + 0.005) {
        const error = new Error(
            `Total allocation ${totalAllocation.toFixed(2)} cannot exceed payment amount ${paymentAmount.toFixed(2)}`
        );
        error.statusCode = 400;
        throw error;
    }

    return {
        calculated,
        totalAllocation,
        unallocatedAmount: round2(paymentAmount - totalAllocation)
    };
}

exports.createSupplierPayment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        const {
            outletId,
            amount,
            paymentMode,
            paymentDate,
            referenceNo,
            remarks,
            allocations
        } = req.body || {};

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        const outlet = Number(outletId);
        if (!Number.isInteger(outlet) || outlet <= 0) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const paymentAmount = Number(amount);
        if (!Number.isFinite(paymentAmount) || paymentAmount <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Payment amount must be greater than zero'
            });
        }

        const normalizedPaymentMode = String(paymentMode || '').toUpperCase();
        if (!PAYMENT_MODES.has(normalizedPaymentMode)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid paymentMode'
            });
        }

        const normalizedPaymentDate = normalizeDateTime(paymentDate) || null;
        if (paymentDate && !normalizedPaymentDate) {
            return res.status(400).json({
                success: false,
                message: 'Invalid paymentDate'
            });
        }

        const allocationRows = normalizeAllocations(allocations);

        await connection.beginTransaction();

        await getAuthorizedOutlet(connection, outlet, req);
        await getSupplier(connection, supplierId, req);

        /*
          Lock the supplier's existing payment rows only through the supplier
          ownership/validation path. Financial consistency for purchases is
          enforced by row locks on each allocated purchase.
        */
        const allocationResult = await validateAndCalculateAllocations(
            connection,
            supplierId,
            round2(paymentAmount),
            allocationRows
        );

        const paymentDateSql = normalizedPaymentDate || null;

        const [insertResult] = await connection.query(
            `
            INSERT INTO supplier_payment
                (
                    supplier_id,
                    outlet_id,
                    payment_date,
                    payment_mode,
                    amount,
                    reference_no,
                    paid_by,
                    remarks,
                    status
                )
            VALUES (?, ?, COALESCE(?, CURRENT_TIMESTAMP), ?, ?, ?, ?, ?, 'SUCCESS')
            `,
            [
                supplierId,
                outlet,
                paymentDateSql,
                normalizedPaymentMode,
                round2(paymentAmount),
                referenceNo || null,
                req.user.userId,
                remarks || null
            ]
        );

        const paymentId = insertResult.insertId;

        for (const allocation of allocationRows) {
            await connection.query(
                `
                INSERT INTO supplier_payment_allocation
                    (payment_id, purchase_id, allocated_amount)
                VALUES (?, ?, ?)
                `,
                [paymentId, allocation.purchaseId, allocation.amount]
            );
        }

        for (const allocation of allocationRows) {
            await refreshPurchaseSnapshot(connection, allocation.purchaseId);
        }

        await connection.commit();

        const payment = await getPaymentWithAllocations(connection, paymentId);

        return res.status(201).json({
            success: true,
            message: 'Supplier payment created successfully',
            payment,
            allocationSummary: allocationResult
        });

    } catch (error) {
        await connection.rollback().catch(() => {});
        console.error('Create supplier payment error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to create supplier payment'
        });
    } finally {
        connection.release();
    }
};

exports.getSupplierPayments = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        const fromDate = String(req.query.fromDate || '').trim();
        const toDate = String(req.query.toDate || '').trim();

        if ((fromDate && !isValidDateOnly(fromDate)) || (toDate && !isValidDateOnly(toDate))) {
            return res.status(400).json({
                success: false,
                message: 'fromDate and toDate, when supplied, must be YYYY-MM-DD'
            });
        }

        if (fromDate && toDate && fromDate > toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be greater than toDate'
            });
        }

        const supplier = await getSupplier(connection, supplierId, req);

        const conditions = ['sp.supplier_id = ?'];
        const params = [supplierId];

        if (fromDate) {
            conditions.push("sp.payment_date >= CONCAT(?, ' 00:00:00')");
            params.push(fromDate);
        }

        if (toDate) {
            conditions.push("sp.payment_date < DATE_ADD(?, INTERVAL 1 DAY)");
            params.push(toDate);
        }

        const [payments] = await connection.query(
            `
            SELECT
                sp.payment_id,
                sp.supplier_id,
                sp.outlet_id,
                sp.payment_date,
                sp.payment_mode,
                sp.amount,
                sp.reference_no,
                sp.paid_by,
                sp.remarks,
                sp.status,
                sp.created_at
            FROM supplier_payment sp
            WHERE ${conditions.join(' AND ')}
            ORDER BY sp.payment_date DESC, sp.payment_id DESC
            `,
            params
        );

        const paymentIds = payments.map((row) => row.payment_id);
        let allocationRows = [];

        if (paymentIds.length) {
            const placeholders = paymentIds.map(() => '?').join(',');

            const [rows] = await connection.query(
                `
                SELECT
                    spa.allocation_id,
                    spa.payment_id,
                    spa.purchase_id,
                    spa.allocated_amount,
                    p.purchase_no,
                    p.purchase_date
                FROM supplier_payment_allocation spa
                INNER JOIN purchase p
                    ON p.purchase_id = spa.purchase_id
                WHERE spa.payment_id IN (${placeholders})
                ORDER BY spa.payment_id DESC, spa.allocation_id
                `,
                paymentIds
            );

            allocationRows = rows;
        }

        const allocationMap = new Map();
        for (const row of allocationRows) {
            const key = Number(row.payment_id);
            if (!allocationMap.has(key)) allocationMap.set(key, []);
            allocationMap.get(key).push(row);
        }

        return res.json({
            success: true,
            supplier: {
                supplierId: supplier.supplier_id,
                supplierCode: supplier.supplier_code,
                supplierName: supplier.supplier_name
            },
            payments: payments.map((payment) => {
                const rows = allocationMap.get(Number(payment.payment_id)) || [];
                const amount = toNumber(payment.amount);
                const allocatedAmount = rows.reduce(
                    (sum, row) => sum + toNumber(row.allocated_amount),
                    0
                );

                return {
                    paymentId: payment.payment_id,
                    supplierId: payment.supplier_id,
                    outletId: payment.outlet_id,
                    paymentDate: payment.payment_date,
                    paymentMode: payment.payment_mode,
                    amount,
                    allocatedAmount: round2(allocatedAmount),
                    unallocatedAmount: round2(Math.max(0, amount - allocatedAmount)),
                    referenceNo: payment.reference_no,
                    paidBy: payment.paid_by,
                    remarks: payment.remarks,
                    status: payment.status,
                    createdAt: payment.created_at,
                    allocations: rows.map((row) => ({
                        allocationId: row.allocation_id,
                        purchaseId: row.purchase_id,
                        purchaseNo: row.purchase_no,
                        purchaseDate: row.purchase_date,
                        allocatedAmount: toNumber(row.allocated_amount)
                    }))
                };
            })
        });

    } catch (error) {
        console.error('Get supplier payments error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to get supplier payments'
        });
    } finally {
        connection.release();
    }
};

exports.getSupplierPayment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        const paymentId = Number(req.params.paymentId);

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        if (!Number.isInteger(paymentId) || paymentId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid paymentId'
            });
        }

        await getSupplier(connection, supplierId, req);

        const payment = await getPaymentWithAllocations(connection, paymentId);

        if (!payment || Number(payment.supplierId) !== supplierId) {
            return res.status(404).json({
                success: false,
                message: 'Supplier payment not found'
            });
        }

        return res.json({
            success: true,
            payment
        });

    } catch (error) {
        console.error('Get supplier payment error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to get supplier payment'
        });
    } finally {
        connection.release();
    }
};

exports.allocateSupplierPayment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        const paymentId = Number(req.params.paymentId);
        const allocationRows = normalizeAllocations(req.body?.allocations);

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        if (!Number.isInteger(paymentId) || paymentId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid paymentId'
            });
        }

        if (!allocationRows.length) {
            return res.status(400).json({
                success: false,
                message: 'At least one allocation is required'
            });
        }

        await connection.beginTransaction();
        await getSupplier(connection, supplierId, req);

        const [paymentRows] = await connection.query(
            `
            SELECT
                payment_id,
                supplier_id,
                amount,
                status
            FROM supplier_payment
            WHERE payment_id = ?
            FOR UPDATE
            `,
            [paymentId]
        );

        if (!paymentRows.length || Number(paymentRows[0].supplier_id) !== supplierId) {
            const error = new Error('Supplier payment not found');
            error.statusCode = 404;
            throw error;
        }

        const payment = paymentRows[0];
        if (payment.status !== 'SUCCESS') {
            const error = new Error('Only SUCCESS payments can be allocated');
            error.statusCode = 400;
            throw error;
        }

        const [existingRows] = await connection.query(
            `
            SELECT
                purchase_id,
                allocated_amount
            FROM supplier_payment_allocation
            WHERE payment_id = ?
            FOR UPDATE
            `,
            [paymentId]
        );

        const existingMap = new Map(
            existingRows.map((row) => [
                Number(row.purchase_id),
                toNumber(row.allocated_amount)
            ])
        );

        const newRows = allocationRows.filter((allocation) => {
            return !existingMap.has(allocation.purchaseId);
        });

        if (newRows.length !== allocationRows.length) {
            const error = new Error(
                'Payment is already allocated to one or more of the supplied purchases'
            );
            error.statusCode = 400;
            throw error;
        }

        let existingTotal = existingRows.reduce(
            (sum, row) => sum + toNumber(row.allocated_amount),
            0
        );

        const remainingPayment = round2(
            Math.max(0, toNumber(payment.amount) - existingTotal)
        );

        const validation = await validateAndCalculateAllocations(
            connection,
            supplierId,
            remainingPayment,
            newRows
        );

        for (const allocation of newRows) {
            await connection.query(
                `
                INSERT INTO supplier_payment_allocation
                    (payment_id, purchase_id, allocated_amount)
                VALUES (?, ?, ?)
                `,
                [paymentId, allocation.purchaseId, allocation.amount]
            );
        }

        for (const allocation of newRows) {
            await refreshPurchaseSnapshot(connection, allocation.purchaseId);
        }

        await connection.commit();

        const result = await getPaymentWithAllocations(connection, paymentId);

        return res.status(201).json({
            success: true,
            message: 'Supplier payment allocation added successfully',
            payment: result,
            allocationSummary: validation
        });

    } catch (error) {
        await connection.rollback().catch(() => {});
        console.error('Allocate supplier payment error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to allocate supplier payment'
        });
    } finally {
        connection.release();
    }
};

exports.voidSupplierPayment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        const paymentId = Number(req.params.paymentId);
        const remarks = req.body?.remarks || null;

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        if (!Number.isInteger(paymentId) || paymentId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid paymentId'
            });
        }

        await connection.beginTransaction();
        await getSupplier(connection, supplierId, req);

        const [paymentRows] = await connection.query(
            `
            SELECT
                payment_id,
                supplier_id,
                status,
                remarks
            FROM supplier_payment
            WHERE payment_id = ?
            FOR UPDATE
            `,
            [paymentId]
        );

        if (!paymentRows.length || Number(paymentRows[0].supplier_id) !== supplierId) {
            const error = new Error('Supplier payment not found');
            error.statusCode = 404;
            throw error;
        }

        if (paymentRows[0].status !== 'SUCCESS') {
            const error = new Error('Only SUCCESS payments can be voided');
            error.statusCode = 400;
            throw error;
        }

        const [allocationRows] = await connection.query(
            `
            SELECT purchase_id
            FROM supplier_payment_allocation
            WHERE payment_id = ?
            FOR UPDATE
            `,
            [paymentId]
        );

        await connection.query(
            `
            UPDATE supplier_payment
            SET
                status = 'VOID',
                remarks = COALESCE(?, remarks)
            WHERE payment_id = ?
            `,
            [remarks, paymentId]
        );

        for (const allocation of allocationRows) {
            await refreshPurchaseSnapshot(
                connection,
                Number(allocation.purchase_id)
            );
        }

        await connection.commit();

        const payment = await getPaymentWithAllocations(connection, paymentId);

        return res.json({
            success: true,
            message: 'Supplier payment voided successfully',
            payment
        });

    } catch (error) {
        await connection.rollback().catch(() => {});
        console.error('Void supplier payment error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to void supplier payment'
        });
    } finally {
        connection.release();
    }
};
