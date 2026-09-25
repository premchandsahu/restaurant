const db = require('../database');
const crypto = require('crypto');



// ============================================================
// HELPER: GENERATE PURCHASE NUMBER
// ============================================================

function formatPurchaseNo(purchaseId,outletId) {
    return `PUR-${String(purchaseId).padStart(6, '0')}`;
}

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
// HELPER: ROUND MONEY
// ============================================================

function roundMoney(value) {
    return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

// ============================================================
// HELPER: BUILD TAX LINES
//
// Purchase item amount is kept as the taxable/pre-tax amount.
// Tax is stored separately in purchase_item_tax and in the
// purchase_item.tax_amount column.
//
// The tax group rates are expected to use the same inclusive
// setting. Existing configured tax groups use exclusive taxes.
// ============================================================

async function calculateItemTax(connection, taxableBase, taxGroupId) {
    const base = roundMoney(taxableBase);

    if (!taxGroupId) {
        return {
            taxableAmount: base,
            taxAmount: 0,
            taxRows: []
        };
    }

    const [rates] = await connection.query(
        `
        SELECT
            tax_rate_id,
            tax_group_id,
            tax_name,
            tax_type,
            rate,
            is_inclusive
        FROM tax_rate
        WHERE tax_group_id = ?
          AND is_active = TRUE
        ORDER BY tax_rate_id
        `,
        [taxGroupId]
    );

    if (rates.length === 0) {
        const error = new Error('Tax group has no active tax rates');
        error.statusCode = 400;
        throw error;
    }

    const inclusiveValues = [
        ...new Set(rates.map(rate => Boolean(rate.is_inclusive)))
    ];

    if (inclusiveValues.length > 1) {
        const error = new Error(
            'All tax rates in a tax group must have the same inclusive setting'
        );
        error.statusCode = 400;
        throw error;
    }

    const isInclusive = inclusiveValues[0];

    let taxableAmount = base;

    if (isInclusive) {
        const totalRate = rates.reduce(
            (sum, rate) => sum + Number(rate.rate || 0),
            0
        );

        taxableAmount = roundMoney(
            base / (1 + totalRate / 100)
        );
    }

    const taxRows = rates.map(rate => {
        const taxAmount = roundMoney(
            taxableAmount * Number(rate.rate || 0) / 100
        );

        return {
            taxRateId: Number(rate.tax_rate_id),
            taxGroupId: Number(rate.tax_group_id),
            taxName: rate.tax_name,
            taxType: rate.tax_type,
            rate: Number(rate.rate || 0),
            taxableAmount,
            taxAmount
        };
    });

    const taxAmount = roundMoney(
        taxRows.reduce((sum, row) => sum + row.taxAmount, 0)
    );

    return {
        taxableAmount,
        taxAmount,
        taxRows
    };
}

// ============================================================
// HELPER: VALIDATE PURCHASE ITEM
// ============================================================

async function validateAndCalculateItem(connection, item, outletId) {
    const rawMaterialId = Number(item.rawMaterialId);
    const qty = Number(item.qty);
    const unitId = Number(item.unitId);
    const conversionFactor =
        item.conversionFactor === undefined ||
        item.conversionFactor === null ||
        item.conversionFactor === ''
            ? 1
            : Number(item.conversionFactor);
    const rate = Number(item.rate);
    const discountAmount =
        item.discountAmount === undefined ||
        item.discountAmount === null ||
        item.discountAmount === ''
            ? 0
            : Number(item.discountAmount);
    const taxGroupId =
        item.taxGroupId === undefined ||
        item.taxGroupId === null ||
        item.taxGroupId === ''
            ? null
            : Number(item.taxGroupId);

    if (!Number.isInteger(rawMaterialId) || rawMaterialId <= 0) {
        throw Object.assign(
            new Error('Invalid rawMaterialId'),
            { statusCode: 400 }
        );
    }

    if (!Number.isInteger(unitId) || unitId <= 0) {
        throw Object.assign(
            new Error('Invalid unitId'),
            { statusCode: 400 }
        );
    }

    if (!Number.isFinite(qty) || qty <= 0) {
        throw Object.assign(
            new Error('qty must be greater than 0'),
            { statusCode: 400 }
        );
    }

    if (!Number.isFinite(conversionFactor) || conversionFactor <= 0) {
        throw Object.assign(
            new Error('conversionFactor must be greater than 0'),
            { statusCode: 400 }
        );
    }

    if (!Number.isFinite(rate) || rate < 0) {
        throw Object.assign(
            new Error('rate must be 0 or greater'),
            { statusCode: 400 }
        );
    }

    if (!Number.isFinite(discountAmount) || discountAmount < 0) {
        throw Object.assign(
            new Error('discountAmount must be 0 or greater'),
            { statusCode: 400 }
        );
    }

    if (taxGroupId !== null &&
        (!Number.isInteger(taxGroupId) || taxGroupId <= 0)) {
        throw Object.assign(
            new Error('Invalid taxGroupId'),
            { statusCode: 400 }
        );
    }

    const [rawMaterials] = await connection.query(
        `
        SELECT
            rm.raw_material_id,
            rm.raw_material_uuid,
            rm.outlet_id,
            rm.material_code,
            rm.material_name,
            rm.tax_group_id,
            rm.unit_id AS base_unit_id,
            u.unit_code AS base_unit_code,
            u.unit_name AS base_unit_name
        FROM raw_material rm
        INNER JOIN unit u
            ON u.unit_id = rm.unit_id
        WHERE rm.raw_material_id = ?
          AND rm.outlet_id = ?
          AND rm.is_active = TRUE
        LIMIT 1
        `,
        [rawMaterialId, outletId]
    );

    if (rawMaterials.length === 0) {
        throw Object.assign(
            new Error(`Raw material ${rawMaterialId} not found for outlet`),
            { statusCode: 400 }
        );
    }

    const rawMaterial = rawMaterials[0];

    const effectiveTaxGroupId =
    taxGroupId !== null
        ? taxGroupId
        : (
            rawMaterial.tax_group_id === null ||
            rawMaterial.tax_group_id === undefined
                ? null
                : Number(rawMaterial.tax_group_id)
        );

    const [units] = await connection.query(
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

    if (units.length === 0) {
        throw Object.assign(
            new Error(`Unit ${unitId} not found`),
            { statusCode: 400 }
        );
    }

    const unit = units[0];

    const grossAmount = roundMoney(qty * rate);

    if (discountAmount > grossAmount) {
        throw Object.assign(
            new Error('discountAmount cannot exceed gross amount'),
            { statusCode: 400 }
        );
    }

    const netBeforeTax = roundMoney(
        grossAmount - discountAmount
    );

    const tax = await calculateItemTax(
         connection,
         netBeforeTax,
         effectiveTaxGroupId
    );

    return {
        rawMaterialId,
        rawMaterial,
        qty,
        unitId,
        unit,
        conversionFactor,
        baseQty: Number((qty * conversionFactor).toFixed(6)),
        rate,
        grossAmount,
        discountAmount: roundMoney(discountAmount),
        taxGroupId: effectiveTaxGroupId,
        taxableAmount: tax.taxableAmount,
        taxAmount: tax.taxAmount,
        amount: tax.taxableAmount,
        taxRows: tax.taxRows,
        batchNo:
            item.batchNo === undefined || item.batchNo === null
                ? null
                : String(item.batchNo).trim() || null,
        expiryDate:
            item.expiryDate === undefined || item.expiryDate === null || item.expiryDate === ''
                ? null
                : String(item.expiryDate)
    };
}

// ============================================================
// HELPER: LOAD PURCHASE DETAIL
// ============================================================

async function loadPurchase(connection, purchaseId, outletId) {
    const [purchases] = await connection.query(
        `
        SELECT
            p.purchase_id,
            p.purchase_uuid,
            p.outlet_id,
            p.supplier_id,
            s.supplier_code,
            s.supplier_name,
            p.purchase_no,
            p.purchase_date,
            p.status,
            p.supplier_invoice_no,
            p.subtotal,
            p.tax_amount,
            p.discount_amount,
            p.grand_total,
            p.paid_amount,
            p.balance_amount,
            p.remarks,
            p.created_by
        FROM purchase p
        INNER JOIN supplier s
            ON s.supplier_id = p.supplier_id
        WHERE p.purchase_id = ?
          AND p.outlet_id = ?
        LIMIT 1
        `,
        [purchaseId, outletId]
    );

    if (purchases.length === 0) {
        return null;
    }

    const purchase = purchases[0];

    const [items] = await connection.query(
        `
        SELECT
            pi.purchase_item_id,
            pi.purchase_id,
            pi.raw_material_id,
            rm.material_code,
            rm.material_name,
            pi.batch_no,
            pi.expiry_date,
            pi.qty,
            pi.unit_id,
            u.unit_code,
            u.unit_name,
            pi.conversion_factor,
            pi.base_qty,
            pi.rate,
            pi.discount_amount,
            pi.tax_group_id,
            pi.tax_amount,
            pi.amount
        FROM purchase_item pi
        INNER JOIN raw_material rm
            ON rm.raw_material_id = pi.raw_material_id
        INNER JOIN unit u
            ON u.unit_id = pi.unit_id
        WHERE pi.purchase_id = ?
        ORDER BY pi.purchase_item_id
        `,
        [purchaseId]
    );

    const itemIds = items.map(item => item.purchase_item_id);

    let taxRows = [];

    if (itemIds.length > 0) {
        const placeholders = itemIds.map(() => '?').join(',');

        const [rows] = await connection.query(
            `
            SELECT
                pit.purchase_item_tax_id,
                pit.purchase_item_id,
                pit.tax_group_id,
                pit.tax_rate_id,
                pit.tax_name,
                pit.tax_type,
                pit.rate,
                pit.taxable_amount,
                pit.tax_amount
            FROM purchase_item_tax pit
            WHERE pit.purchase_item_id IN (${placeholders})
            ORDER BY pit.purchase_item_tax_id
            `,
            itemIds
        );

        taxRows = rows;
    }

    const taxMap = new Map();

    for (const tax of taxRows) {
        if (!taxMap.has(tax.purchase_item_id)) {
            taxMap.set(tax.purchase_item_id, []);
        }

        taxMap.get(tax.purchase_item_id).push({
            purchaseItemTaxId: tax.purchase_item_tax_id,
            taxGroupId: tax.tax_group_id,
            taxRateId: tax.tax_rate_id,
            taxName: tax.tax_name,
            taxType: tax.tax_type,
            rate: Number(tax.rate || 0),
            taxableAmount: Number(tax.taxable_amount || 0),
            taxAmount: Number(tax.tax_amount || 0)
        });
    }

    return {
        purchaseId: purchase.purchase_id,
        purchaseUuid: purchase.purchase_uuid,
        outletId: purchase.outlet_id,
        supplierId: purchase.supplier_id,
        supplierCode: purchase.supplier_code,
        supplierName: purchase.supplier_name,
        purchaseNo: purchase.purchase_no,
        purchaseDate: purchase.purchase_date,
        status: purchase.status,
        supplierInvoiceNo: purchase.supplier_invoice_no,
        subtotal: Number(purchase.subtotal || 0),
        taxAmount: Number(purchase.tax_amount || 0),
        discountAmount: Number(purchase.discount_amount || 0),
        grandTotal: Number(purchase.grand_total || 0),
        paidAmount: Number(purchase.paid_amount || 0),
        balanceAmount: Number(purchase.balance_amount || 0),
        remarks: purchase.remarks,
        createdBy: purchase.created_by,
        items: items.map(item => ({
            purchaseItemId: item.purchase_item_id,
            purchaseId: item.purchase_id,
            rawMaterialId: item.raw_material_id,
            materialCode: item.material_code,
            materialName: item.material_name,
            batchNo: item.batch_no,
            expiryDate: item.expiry_date,
            qty: Number(item.qty || 0),
            unitId: item.unit_id,
            unitCode: item.unit_code,
            unitName: item.unit_name,
            conversionFactor: Number(item.conversion_factor || 0),
            baseQty: Number(item.base_qty || 0),
            rate: Number(item.rate || 0),
            discountAmount: Number(item.discount_amount || 0),
            taxGroupId: item.tax_group_id === null
                ? null
                : Number(item.tax_group_id),
            taxAmount: Number(item.tax_amount || 0),
            taxableAmount: Number(item.amount || 0),
            amount: Number(item.amount || 0),
            taxes: taxMap.get(item.purchase_item_id) || []
        }))
    };
}

// ============================================================
// GET PURCHASE LIST
//
// GET /inventory/purchases?outletId=1
// Optional:
//   supplierId
//   status
//   fromDate
//   toDate
//   search
// ============================================================

exports.getPurchases = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
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

        const params = [outletId];
        const conditions = ['p.outlet_id = ?'];

        if (req.query.supplierId) {
            const supplierId = Number(req.query.supplierId);
            if (!Number.isInteger(supplierId) || supplierId <= 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid supplierId'
                });
            }
            conditions.push('p.supplier_id = ?');
            params.push(supplierId);
        }

        if (req.query.status) {
            const allowedStatuses = ['DRAFT', 'POSTED', 'CANCELLED'];
            const status = String(req.query.status).toUpperCase();
            if (!allowedStatuses.includes(status)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid purchase status'
                });
            }
            conditions.push('p.status = ?');
            params.push(status);
        }

        if (req.query.fromDate) {
            conditions.push('p.purchase_date >= ?');
            params.push(String(req.query.fromDate));
        }

        if (req.query.toDate) {
            conditions.push('p.purchase_date <= ?');
            params.push(String(req.query.toDate));
        }

        if (req.query.search) {
            const search = `%${String(req.query.search).trim()}%`;
            conditions.push(`
                (
                    p.purchase_no LIKE ?
                    OR p.supplier_invoice_no LIKE ?
                    OR s.supplier_name LIKE ?
                    OR s.supplier_code LIKE ?
                )
            `);
            params.push(search, search, search, search);
        }

        const [rows] = await connection.query(
            `
            SELECT
                p.purchase_id,
                p.purchase_uuid,
                p.outlet_id,
                p.supplier_id,
                s.supplier_code,
                s.supplier_name,
                p.purchase_no,
                p.purchase_date,
                p.status,
                p.supplier_invoice_no,
                p.subtotal,
                p.tax_amount,
                p.discount_amount,
                p.grand_total,
                p.paid_amount,
                p.balance_amount,
                p.remarks
            FROM purchase p
            INNER JOIN supplier s
                ON s.supplier_id = p.supplier_id
            WHERE ${conditions.join(' AND ')}
            ORDER BY p.purchase_date DESC, p.purchase_id DESC
            `,
            params
        );

        return res.json({
            success: true,
            purchases: rows.map(row => ({
                purchaseId: row.purchase_id,
                purchaseUuid: row.purchase_uuid,
                outletId: row.outlet_id,
                supplierId: row.supplier_id,
                supplierCode: row.supplier_code,
                supplierName: row.supplier_name,
                purchaseNo: row.purchase_no,
                purchaseDate: row.purchase_date,
                status: row.status,
                supplierInvoiceNo: row.supplier_invoice_no,
                subtotal: Number(row.subtotal || 0),
                taxAmount: Number(row.tax_amount || 0),
                discountAmount: Number(row.discount_amount || 0),
                grandTotal: Number(row.grand_total || 0),
                paidAmount: Number(row.paid_amount || 0),
                balanceAmount: Number(row.balance_amount || 0),
                remarks: row.remarks
            }))
        });

    } catch (error) {
        console.error('Get purchases error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get purchases'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// GET PURCHASE DETAIL
//
// GET /inventory/purchases/:purchaseId?outletId=1
// ============================================================

exports.getPurchase = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const purchaseId = Number(req.params.purchaseId);
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(purchaseId) || purchaseId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseId'
            });
        }

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
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

        const purchase = await loadPurchase(
            connection,
            purchaseId,
            outletId
        );

        if (!purchase) {
            return res.status(404).json({
                success: false,
                message: 'Purchase not found'
            });
        }

        return res.json({
            success: true,
            purchase
        });

    } catch (error) {
        console.error('Get purchase error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get purchase'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// CREATE PURCHASE DRAFT
//
// POST /inventory/purchases
// ============================================================

exports.createPurchase = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            outletId,
            supplierId,
            purchaseDate,
            supplierInvoiceNo,
            remarks,
            items
        } = req.body;

        const parsedOutletId = Number(outletId);
        const parsedSupplierId = Number(supplierId);

        const normalizedDate =
            purchaseDate === undefined || purchaseDate === null || purchaseDate === ''
                ? new Date().toISOString().slice(0, 10)
                : String(purchaseDate);

        if (!Number.isInteger(parsedOutletId) || parsedOutletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!Number.isInteger(parsedSupplierId) || parsedSupplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid supplierId is required'
            });
        }



        if (!Array.isArray(items)) {
            return res.status(400).json({
                success: false,
                message: 'items must be an array'
            });
        }

        const outlet = await getAuthorizedOutlet(
            connection,
            parsedOutletId,
            req
        );

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        await connection.beginTransaction();

        const [suppliers] = await connection.query(
            `
            SELECT
                supplier_id,
                supplier_code,
                supplier_name
            FROM supplier
            WHERE supplier_id = ?
              AND company_id = ?
              AND is_active = TRUE
            LIMIT 1
            FOR UPDATE
            `,
            [parsedSupplierId, req.user.companyId]
        );

        if (suppliers.length === 0) {
            const error = new Error('Supplier not found');
            error.statusCode = 400;
            throw error;
        }

        

        const calculatedItems = [];

        for (const item of items) {
            const calculated = await validateAndCalculateItem(
                connection,
                item,
                parsedOutletId
            );
            calculatedItems.push(calculated);
        }

        const subtotal = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.amount,
                0
            )
        );

        const taxAmount = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.taxAmount,
                0
            )
        );

        const discountAmount = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.discountAmount,
                0
            )
        );

        const grandTotal = roundMoney(
            subtotal + taxAmount
        );

      const purchaseUuid = crypto.randomUUID();

      // Temporary unique value.
      // It will immediately be replaced with the final purchase number
      // generated from the database purchase_id.
      const temporaryPurchaseNo = `TMP-${purchaseUuid}`;
          
      const [purchaseResult] = await connection.query(
          `
          INSERT INTO purchase (
              purchase_uuid,
              outlet_id,
              supplier_id,
              purchase_no,
              purchase_date,
              status,
              supplier_invoice_no,
              subtotal,
              tax_amount,
              discount_amount,
              grand_total,
              paid_amount,
              balance_amount,
              remarks,
              created_by
          ) VALUES (?, ?, ?, ?, ?, 'DRAFT', ?, ?, ?, ?, ?, 0, ?, ?, ?)
          `,
          [
              purchaseUuid,
              parsedOutletId,
              parsedSupplierId,
              temporaryPurchaseNo,
              normalizedDate,
              supplierInvoiceNo === undefined || supplierInvoiceNo === null
                  ? null
                  : String(supplierInvoiceNo).trim() || null,
              subtotal,
              taxAmount,
              discountAmount,
              grandTotal,
              grandTotal,
              remarks === undefined || remarks === null
                  ? null
                  : String(remarks).trim() || null,
              req.user.userId
          ]
      );
      
      const purchaseId = purchaseResult.insertId;
      
      const generatedPurchaseNo = formatPurchaseNo(purchaseId,outletId);
      
      await connection.query(
          `
          UPDATE purchase
          SET purchase_no = ?
          WHERE purchase_id = ?
          `,
          [
              generatedPurchaseNo,
              purchaseId
          ]
      );
        
        for (const item of calculatedItems) {
            const [itemResult] = await connection.query(
                `
                INSERT INTO purchase_item (
                    purchase_id,
                    raw_material_id,
                    batch_no,
                    expiry_date,
                    qty,
                    unit_id,
                    conversion_factor,
                    base_qty,
                    rate,
                    discount_amount,
                    tax_group_id,
                    tax_amount,
                    amount
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `,
                [
                    purchaseId,
                    item.rawMaterialId,
                    item.batchNo,
                    item.expiryDate,
                    item.qty,
                    item.unitId,
                    item.conversionFactor,
                    item.baseQty,
                    item.rate,
                    item.discountAmount,
                    item.taxGroupId,
                    item.taxAmount,
                    item.amount
                ]
            );

            const purchaseItemId = itemResult.insertId;

            for (const tax of item.taxRows) {
                await connection.query(
                    `
                    INSERT INTO purchase_item_tax (
                        purchase_item_id,
                        tax_group_id,
                        tax_rate_id,
                        tax_name,
                        tax_type,
                        rate,
                        taxable_amount,
                        tax_amount
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `,
                    [
                        purchaseItemId,
                        tax.taxGroupId,
                        tax.taxRateId,
                        tax.taxName,
                        tax.taxType,
                        tax.rate,
                        tax.taxableAmount,
                        tax.taxAmount
                    ]
                );
            }
        }

        await connection.commit();

        const purchase = await loadPurchase(
            connection,
            purchaseId,
            parsedOutletId
        );

        return res.status(201).json({
            success: true,
            message: 'Purchase draft created successfully',
            purchase
        });

    } catch (error) {
        try {
            await connection.rollback();
        } catch (rollbackError) {
            console.error('Purchase rollback error:', rollbackError);
        }

        console.error('Create purchase error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to create purchase'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// UPDATE PURCHASE DRAFT
//
// PUT /inventory/purchases/:purchaseId
// ============================================================

exports.updatePurchase = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const purchaseId = Number(req.params.purchaseId);

        if (!Number.isInteger(purchaseId) || purchaseId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseId'
            });
        }

        const {
              outletId,
              supplierId,
              purchaseDate,
              supplierInvoiceNo,
              remarks,
              items
        } = req.body;

        const parsedOutletId = Number(outletId);
        const parsedSupplierId = Number(supplierId);
        
        const normalizedDate =
            purchaseDate === undefined || purchaseDate === null || purchaseDate === ''
                ? new Date().toISOString().slice(0, 10)
                : String(purchaseDate);

        if (!Number.isInteger(parsedOutletId) || parsedOutletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!Number.isInteger(parsedSupplierId) || parsedSupplierId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid supplierId is required'
            });
        }

       

        if (!Array.isArray(items)) {
            return res.status(400).json({
                success: false,
                message: 'items must be an array'
            });
        }

        const outlet = await getAuthorizedOutlet(
            connection,
            parsedOutletId,
            req
        );

        if (!outlet) {
            return res.status(403).json({
                success: false,
                message: 'Outlet access denied'
            });
        }

        await connection.beginTransaction();

        const [purchases] = await connection.query(
            `
            SELECT
                purchase_id,
                status,
                purchase_no
            FROM purchase
            WHERE purchase_id = ?
              AND outlet_id = ?
            LIMIT 1
            FOR UPDATE
            `,
            [purchaseId, parsedOutletId]
        );

        if (purchases.length === 0) {
            const error = new Error('Purchase not found');
            error.statusCode = 404;
            throw error;
        }

        if (purchases[0].status !== 'DRAFT') {
            const error = new Error(
                'Only DRAFT purchases can be updated'
            );
            error.statusCode = 400;
            throw error;
        }

        const [suppliers] = await connection.query(
            `
            SELECT
                supplier_id
            FROM supplier
            WHERE supplier_id = ?
              AND company_id = ?
              AND is_active = TRUE
            LIMIT 1
            FOR UPDATE
            `,
            [parsedSupplierId, req.user.companyId]
        );

        if (suppliers.length === 0) {
            const error = new Error('Supplier not found');
            error.statusCode = 400;
            throw error;
        }


        const calculatedItems = [];

        for (const item of items) {
            const calculated = await validateAndCalculateItem(
                connection,
                item,
                parsedOutletId
            );
            calculatedItems.push(calculated);
        }

        const subtotal = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.amount,
                0
            )
        );

        const taxAmount = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.taxAmount,
                0
            )
        );

        const discountAmount = roundMoney(
            calculatedItems.reduce(
                (sum, item) => sum + item.discountAmount,
                0
            )
        );

        const grandTotal = roundMoney(
            subtotal + taxAmount
        );

        await connection.query(
            `
            UPDATE purchase
            SET
                supplier_id = ?,
                purchase_date = ?,
                supplier_invoice_no = ?,
                subtotal = ?,
                tax_amount = ?,
                discount_amount = ?,
                grand_total = ?,
                paid_amount = 0,
                balance_amount = ?,
                remarks = ?
            WHERE purchase_id = ?
            `,
            [
                parsedSupplierId,
                normalizedDate,
                supplierInvoiceNo === undefined || supplierInvoiceNo === null
                    ? null
                    : String(supplierInvoiceNo).trim() || null,
                subtotal,
                taxAmount,
                discountAmount,
                grandTotal,
                grandTotal,
                remarks === undefined || remarks === null
                    ? null
                    : String(remarks).trim() || null,
                purchaseId
            ]
        );

        await connection.query(
            `
            DELETE FROM purchase_item
            WHERE purchase_id = ?
            `,
            [purchaseId]
        );

        for (const item of calculatedItems) {
            const [itemResult] = await connection.query(
                `
                INSERT INTO purchase_item (
                    purchase_id,
                    raw_material_id,
                    batch_no,
                    expiry_date,
                    qty,
                    unit_id,
                    conversion_factor,
                    base_qty,
                    rate,
                    discount_amount,
                    tax_group_id,
                    tax_amount,
                    amount
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `,
                [
                    purchaseId,
                    item.rawMaterialId,
                    item.batchNo,
                    item.expiryDate,
                    item.qty,
                    item.unitId,
                    item.conversionFactor,
                    item.baseQty,
                    item.rate,
                    item.discountAmount,
                    item.taxGroupId,
                    item.taxAmount,
                    item.amount
                ]
            );

            const purchaseItemId = itemResult.insertId;

            for (const tax of item.taxRows) {
                await connection.query(
                    `
                    INSERT INTO purchase_item_tax (
                        purchase_item_id,
                        tax_group_id,
                        tax_rate_id,
                        tax_name,
                        tax_type,
                        rate,
                        taxable_amount,
                        tax_amount
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `,
                    [
                        purchaseItemId,
                        tax.taxGroupId,
                        tax.taxRateId,
                        tax.taxName,
                        tax.taxType,
                        tax.rate,
                        tax.taxableAmount,
                        tax.taxAmount
                    ]
                );
            }
        }

        await connection.commit();

        const purchase = await loadPurchase(
            connection,
            purchaseId,
            parsedOutletId
        );

        return res.json({
            success: true,
            message: 'Purchase draft updated successfully',
            purchase
        });

    } catch (error) {
        try {
            await connection.rollback();
        } catch (rollbackError) {
            console.error('Purchase rollback error:', rollbackError);
        }

        console.error('Update purchase error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to update purchase'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// POST PURCHASE
//
// POST /inventory/purchases/:purchaseId/post
//
// Converts a DRAFT purchase into POSTED and increases stock using
// purchase_item.base_qty (base inventory quantity).
//
// Inventory valuation is based on pre-tax taxable purchase value.
// Recoverable GST is kept separate in purchase_item_tax and is not
// added to stock value.
// ============================================================

exports.postPurchase = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const purchaseId = Number(req.params.purchaseId);
        const outletId = Number(req.body.outletId);

        if (!Number.isInteger(purchaseId) || purchaseId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseId'
            });
        }

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
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

        await connection.beginTransaction();

        const [purchaseRows] = await connection.query(
            `
            SELECT
                purchase_id,
                outlet_id,
                supplier_id,
                purchase_no,
                purchase_date,
                status,
                subtotal,
                tax_amount,
                discount_amount,
                grand_total,
                paid_amount,
                balance_amount
            FROM purchase
            WHERE purchase_id = ?
              AND outlet_id = ?
            LIMIT 1
            FOR UPDATE
            `,
            [purchaseId, outletId]
        );

        if (purchaseRows.length === 0) {
            throw Object.assign(
                new Error('Purchase not found'),
                { statusCode: 404 }
            );
        }

        const purchase = purchaseRows[0];

        if (purchase.status !== 'DRAFT') {
            throw Object.assign(
                new Error(
                    `Only DRAFT purchases can be posted. Current status: ${purchase.status}`
                ),
                { statusCode: 400 }
            );
        }

        const [items] = await connection.query(
            `
            SELECT
                pi.purchase_item_id,
                pi.purchase_id,
                pi.raw_material_id,
                rm.material_code,
                rm.material_name,
                pi.qty,
                pi.unit_id,
                u.unit_code,
                u.unit_name,
                pi.conversion_factor,
                pi.base_qty,
                pi.rate,
                pi.discount_amount,
                pi.tax_group_id,
                pi.tax_amount,
                pi.amount
            FROM purchase_item pi
            INNER JOIN raw_material rm
                ON rm.raw_material_id = pi.raw_material_id
            INNER JOIN unit u
                ON u.unit_id = pi.unit_id
            WHERE pi.purchase_id = ?
            ORDER BY pi.purchase_item_id
            FOR UPDATE
            `,
            [purchaseId]
        );

        if (items.length === 0) {
            throw Object.assign(
                new Error('Purchase has no items'),
                { statusCode: 400 }
            );
        }

        const stockRows = [];

        for (const item of items) {
            const baseQty = Number(item.base_qty || 0);
            const amount = Number(item.amount || 0);

            if (!Number.isFinite(baseQty) || baseQty <= 0) {
                throw Object.assign(
                    new Error(
                        `Invalid base quantity for purchase item ${item.purchase_item_id}`
                    ),
                    { statusCode: 400 }
                );
            }

            const unitCost = baseQty > 0
                ? amount / baseQty
                : 0;

            const [balanceRows] = await connection.query(
                `
                SELECT
                    stock_balance_id,
                    current_qty,
                    average_rate
                FROM stock_balance
                WHERE outlet_id = ?
                  AND raw_material_id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [outletId, item.raw_material_id]
            );

            let oldQty = 0;
            let oldAverageRate = 0;

            if (balanceRows.length > 0) {
                oldQty = Number(balanceRows[0].current_qty || 0);
                oldAverageRate = Number(balanceRows[0].average_rate || 0);
            }

            const newQty = oldQty + baseQty;

            const newAverageRate = newQty > 0
                ? ((oldQty * oldAverageRate) + (baseQty * unitCost)) / newQty
                : unitCost;

            let balanceQty;

            if (balanceRows.length === 0) {
                const [insertResult] = await connection.query(
                    `
                    INSERT INTO stock_balance (
                        outlet_id,
                        raw_material_id,
                        current_qty,
                        average_rate
                    ) VALUES (?, ?, ?, ?)
                    `,
                    [
                        outletId,
                        item.raw_material_id,
                        newQty,
                        newAverageRate
                    ]
                );

                balanceQty = newQty;

                stockRows.push({
                    stockBalanceId: insertResult.insertId,
                    rawMaterialId: item.raw_material_id,
                    materialCode: item.material_code,
                    materialName: item.material_name,
                    qtyIn: baseQty,
                    rate: unitCost,
                    amount,
                    balanceQty,
                    averageRate: newAverageRate
                });
            } else {
                await connection.query(
                    `
                    UPDATE stock_balance
                    SET
                        current_qty = ?,
                        average_rate = ?
                    WHERE stock_balance_id = ?
                    `,
                    [
                        newQty,
                        newAverageRate,
                        balanceRows[0].stock_balance_id
                    ]
                );

                balanceQty = newQty;

                stockRows.push({
                    stockBalanceId: balanceRows[0].stock_balance_id,
                    rawMaterialId: item.raw_material_id,
                    materialCode: item.material_code,
                    materialName: item.material_name,
                    qtyIn: baseQty,
                    rate: unitCost,
                    amount,
                    balanceQty,
                    averageRate: newAverageRate
                });
            }

            const purchaseDate = purchase.purchase_date instanceof Date
                ? purchase.purchase_date.toISOString().slice(0, 10)
                : String(purchase.purchase_date).slice(0, 10);

            await connection.query(
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
                ) VALUES (?, ?, ?, CONCAT(?, ' 00:00:00'), 'PURCHASE', 'PURCHASE', ?, ?, 0, ?, ?, ?, ?, ?)
                `,
                [
                    crypto.randomUUID(),
                    outletId,
                    item.raw_material_id,
                    purchaseDate,
                    purchaseId,
                    baseQty,
                    unitCost,
                    amount,
                    balanceQty,
                    `Purchase ${purchase.purchase_no}`,
                    req.user.userId
                ]
            );
        }

        await connection.query(
            `
            UPDATE purchase
            SET status = 'POSTED'
            WHERE purchase_id = ?
              AND outlet_id = ?
              AND status = 'DRAFT'
            `,
            [purchaseId, outletId]
        );

        await connection.commit();

        const postedPurchase = await loadPurchase(
            connection,
            purchaseId,
            outletId
        );

        return res.json({
            success: true,
            message: 'Purchase posted successfully',
            purchase: postedPurchase,
            stock: stockRows
        });

    } catch (error) {
        try {
            await connection.rollback();
        } catch (rollbackError) {
            console.error('Post purchase rollback error:', rollbackError);
        }

        console.error('Post purchase error:', error);

        return res.status(error.statusCode || 500).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to post purchase'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// DELETE PURCHASE DRAFT
// DELETE /inventory/purchases/:purchaseId?outletId=1
//
// Only DRAFT purchases can be deleted.
// POSTED purchases must remain because they affect stock
// and supplier ledger.
// ============================================================

exports.deletePurchase = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const purchaseId = Number(req.params.purchaseId);
        const outletId = Number(req.query.outletId);

        if (!Number.isInteger(purchaseId) || purchaseId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseId'
            });
        }

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
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

        await connection.beginTransaction();

        const [purchases] = await connection.query(
            `
            SELECT
                purchase_id,
                status
            FROM purchase
            WHERE purchase_id = ?
              AND outlet_id = ?
            LIMIT 1
            FOR UPDATE
            `,
            [purchaseId, outletId]
        );

        if (purchases.length === 0) {
            throw Object.assign(
                new Error('Purchase not found'),
                { statusCode: 404 }
            );
        }

        if (purchases[0].status !== 'DRAFT') {
            throw Object.assign(
                new Error('Only DRAFT purchases can be deleted'),
                { statusCode: 400 }
            );
        }

        await connection.query(
            `
            DELETE pit
            FROM purchase_item_tax pit
            INNER JOIN purchase_item pi
                ON pi.purchase_item_id = pit.purchase_item_id
            WHERE pi.purchase_id = ?
            `,
            [purchaseId]
        );

        await connection.query(
            `
            DELETE FROM purchase_item
            WHERE purchase_id = ?
            `,
            [purchaseId]
        );

        await connection.query(
            `
            DELETE FROM purchase
            WHERE purchase_id = ?
              AND outlet_id = ?
            `,
            [purchaseId, outletId]
        );

        await connection.commit();

        return res.json({
            success: true,
            message: 'Purchase draft deleted successfully'
        });

    } catch (error) {
        try {
            await connection.rollback();
        } catch (rollbackError) {
            console.error(
                'Delete purchase rollback error:',
                rollbackError
            );
        }

        console.error(
            'Delete purchase error:',
            error
        );

        return res.status(
            error.statusCode || 500
        ).json({
            success: false,
            message:
                error.statusCode
                    ? error.message
                    : 'Unable to delete purchase'
        });

    } finally {
        connection.release();
    }
};