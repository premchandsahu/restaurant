const db = require('../database');

function toNumber(value) {
    return Number(value || 0);
}

function round2(value) {
    return Number(Number(value || 0).toFixed(2));
}

function isValidDateOnly(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) {
        return false;
    }

    const d = new Date(`${value}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
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

async function getOpeningSummary(connection, supplierId, fromDate) {
    const [purchaseRows] = await connection.query(
        `
        SELECT COALESCE(SUM(p.grand_total), 0) AS amount
        FROM purchase p
        WHERE p.supplier_id = ?
          AND p.status = 'POSTED'
          AND p.purchase_date < ?
        `,
        [supplierId, fromDate]
    );

    const [paymentRows] = await connection.query(
        `
        SELECT COALESCE(SUM(sp.amount), 0) AS amount
        FROM supplier_payment sp
        WHERE sp.supplier_id = ?
          AND sp.status = 'SUCCESS'
          AND sp.payment_date < CONCAT(?, ' 00:00:00')
        `,
        [supplierId, fromDate]
    );

    return {
        purchases: toNumber(purchaseRows[0]?.amount),
        payments: toNumber(paymentRows[0]?.amount)
    };
}

exports.getSupplierLedger = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);
        const fromDate = String(req.query.fromDate || '').trim();
        const toDate = String(req.query.toDate || '').trim();

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        if (!isValidDateOnly(fromDate) || !isValidDateOnly(toDate)) {
            return res.status(400).json({
                success: false,
                message: 'fromDate and toDate are required in YYYY-MM-DD format'
            });
        }

        if (fromDate > toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be greater than toDate'
            });
        }

        const supplier = await getSupplier(connection, supplierId, req);
        const openingHistory = await getOpeningSummary(
            connection,
            supplierId,
            fromDate
        );

        const openingBalance =
            toNumber(supplier.opening_balance) +
            openingHistory.purchases -
            openingHistory.payments;

        const [purchaseRows] = await connection.query(
            `
            SELECT
                p.purchase_id,
                p.purchase_date AS transaction_date,
                p.purchase_no,
                p.supplier_invoice_no,
                p.grand_total
            FROM purchase p
            WHERE p.supplier_id = ?
              AND p.status = 'POSTED'
              AND p.purchase_date BETWEEN ? AND ?
            ORDER BY p.purchase_date, p.purchase_id
            `,
            [supplierId, fromDate, toDate]
        );

        const [paymentRows] = await connection.query(
            `
            SELECT
                sp.payment_id,
                sp.payment_date AS transaction_date,
                sp.payment_mode,
                sp.amount,
                sp.reference_no,
                sp.remarks
            FROM supplier_payment sp
            WHERE sp.supplier_id = ?
              AND sp.status = 'SUCCESS'
              AND sp.payment_date >= CONCAT(?, ' 00:00:00')
              AND sp.payment_date < DATE_ADD(?, INTERVAL 1 DAY)
            ORDER BY sp.payment_date, sp.payment_id
            `,
            [supplierId, fromDate, toDate]
        );

        const transactions = [];

        for (const purchase of purchaseRows) {
            transactions.push({
                sortDate: `${String(purchase.transaction_date).slice(0, 10)} 00:00:00`,
                sortId: Number(purchase.purchase_id),
                transactionId: Number(purchase.purchase_id),
                transactionDate: purchase.transaction_date,
                transactionType: 'PURCHASE',
                referenceNo: purchase.purchase_no,
                referenceId: purchase.purchase_id,
                description: purchase.supplier_invoice_no
                    ? `Purchase ${purchase.purchase_no} / ${purchase.supplier_invoice_no}`
                    : `Purchase ${purchase.purchase_no}`,
                debit: toNumber(purchase.grand_total),
                credit: 0,
                paymentMode: null,
                remarks: null
            });
        }

        for (const payment of paymentRows) {
            transactions.push({
                sortDate: String(payment.transaction_date),
                sortId: Number(payment.payment_id),
                transactionId: Number(payment.payment_id),
                transactionDate: payment.transaction_date,
                transactionType: 'PAYMENT',
                referenceNo: payment.reference_no,
                referenceId: payment.payment_id,
                description: 'Supplier payment',
                debit: 0,
                credit: toNumber(payment.amount),
                paymentMode: payment.payment_mode,
                remarks: payment.remarks
            });
        }

        /* Purchases first when date/timestamp is identical. */
        transactions.sort((a, b) => {
            const dateCompare = a.sortDate.localeCompare(b.sortDate);
            if (dateCompare !== 0) return dateCompare;

            if (a.transactionType !== b.transactionType) {
                return a.transactionType === 'PURCHASE' ? -1 : 1;
            }

            return a.sortId - b.sortId;
        });

        let runningBalance = openingBalance;

        for (const transaction of transactions) {
            runningBalance += transaction.debit - transaction.credit;
            transaction.runningBalance = round2(runningBalance);
            delete transaction.sortDate;
            delete transaction.sortId;
        }

        const totalPurchases = transactions.reduce(
            (sum, row) => sum + row.debit,
            0
        );
        const totalPayments = transactions.reduce(
            (sum, row) => sum + row.credit,
            0
        );
        const closingBalance = openingBalance + totalPurchases - totalPayments;

        return res.json({
            success: true,
            supplier: {
                supplierId: supplier.supplier_id,
                supplierCode: supplier.supplier_code,
                supplierName: supplier.supplier_name,
                mobile: supplier.mobile,
                email: supplier.email,
                gstin: supplier.gstin
            },
            period: {
                fromDate,
                toDate
            },
            summary: {
                masterOpeningBalance: round2(supplier.opening_balance),
                historicalPurchasesBeforeFromDate: round2(openingHistory.purchases),
                historicalPaymentsBeforeFromDate: round2(openingHistory.payments),
                openingBalance: round2(openingBalance),
                totalPurchases: round2(totalPurchases),
                totalPayments: round2(totalPayments),
                closingBalance: round2(closingBalance),
                payableBalance: round2(Math.max(0, closingBalance)),
                advanceBalance: round2(Math.max(0, -closingBalance))
            },
            transactions
        });

    } catch (error) {
        console.error('Get supplier ledger error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to get supplier ledger'
        });
    } finally {
        connection.release();
    }
};

exports.getSupplierOutstanding = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId = Number(req.params.supplierId);

        if (!Number.isInteger(supplierId) || supplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        const supplier = await getSupplier(connection, supplierId, req);

        const [purchaseRows] = await connection.query(
            `
            SELECT COALESCE(SUM(p.grand_total), 0) AS amount
            FROM purchase p
            WHERE p.supplier_id = ?
              AND p.status = 'POSTED'
            `,
            [supplierId]
        );

        const [paymentRows] = await connection.query(
            `
            SELECT COALESCE(SUM(sp.amount), 0) AS amount
            FROM supplier_payment sp
            WHERE sp.supplier_id = ?
              AND sp.status = 'SUCCESS'
            `,
            [supplierId]
        );

        const openingBalance = toNumber(supplier.opening_balance);
        const totalPurchases = toNumber(purchaseRows[0]?.amount);
        const totalPayments = toNumber(paymentRows[0]?.amount);
        const accountBalance = openingBalance + totalPurchases - totalPayments;

        return res.json({
            success: true,
            supplier: {
                supplierId: supplier.supplier_id,
                supplierCode: supplier.supplier_code,
                supplierName: supplier.supplier_name
            },
            summary: {
                openingBalance: round2(openingBalance),
                totalPurchases: round2(totalPurchases),
                totalPayments: round2(totalPayments),
                accountBalance: round2(accountBalance),
                payableBalance: round2(Math.max(0, accountBalance)),
                advanceBalance: round2(Math.max(0, -accountBalance))
            }
        });

    } catch (error) {
        console.error('Get supplier outstanding error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : 'Unable to get supplier outstanding'
        });
    } finally {
        connection.release();
    }
};
