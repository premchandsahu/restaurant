db = require('../database');
const crypto = require('crypto');


// ============================================================
// HELPER: CHECK OUTLET ACCESS
// ============================================================

async function getAuthorizedOutlet(
    connection,
    outletId,
    req
) {
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

    return rows.length > 0
        ? rows[0]
        : null;
}


// ============================================================
// GET UNITS
//
// GET /inventory/units
// ============================================================

exports.getUnits = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const [rows] = await connection.query(
            `
            SELECT
                unit_id,
                unit_code,
                unit_name,
                decimal_places

            FROM unit

            ORDER BY
                unit_name
            `
        );

        return res.json({
            success: true,
            units: rows.map(row => ({
                unitId: row.unit_id,
                unitCode: row.unit_code,
                unitName: row.unit_name,
                decimalPlaces: Number(row.decimal_places || 0)
            }))
        });

    } catch (error) {
        console.error(
            'Get inventory units error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get inventory units'
        });

    } finally {
        connection.release();
    }
};


// Add the following handlers immediately after exports.getUnits
// in controller/inventoryController.js.
// Existing GET /inventory/units remains unchanged.

// ============================================================
// CREATE UNIT
// POST /inventory/units
// ============================================================
exports.createUnit = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const unitCode = String(req.body.unitCode || '').trim();
        const unitName = String(req.body.unitName || '').trim();
        const decimalPlaces = req.body.decimalPlaces === undefined
            ? 3
            : Number(req.body.decimalPlaces);

        if (!unitCode) {
            return res.status(400).json({
                success: false,
                message: 'unitCode is required'
            });
        }
        if (unitCode.length > 20) {
            return res.status(400).json({
                success: false,
                message: 'unitCode cannot exceed 20 characters'
            });
        }
        if (!unitName) {
            return res.status(400).json({
                success: false,
                message: 'unitName is required'
            });
        }
        if (unitName.length > 50) {
            return res.status(400).json({
                success: false,
                message: 'unitName cannot exceed 50 characters'
            });
        }
        if (!Number.isInteger(decimalPlaces) || decimalPlaces < 0 || decimalPlaces > 10) {
            return res.status(400).json({
                success: false,
                message: 'decimalPlaces must be a whole number between 0 and 10'
            });
        }

        try {
            const [result] = await connection.query(
                `INSERT INTO unit (unit_code, unit_name, decimal_places)
                 VALUES (?, ?, ?)`,
                [unitCode, unitName, decimalPlaces]
            );

            return res.status(201).json({
                success: true,
                message: 'Unit created successfully',
                unit: {
                    unitId: result.insertId,
                    unitCode,
                    unitName,
                    decimalPlaces
                }
            });
        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message: 'Unit code already exists'
                });
            }
            throw error;
        }
    } catch (error) {
        console.error('Create unit error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to create unit'
        });
    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE UNIT
// PUT /inventory/units/:unitId
// ============================================================
exports.updateUnit = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const unitId = Number(req.params.unitId);
        if (!Number.isInteger(unitId) || unitId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid unitId'
            });
        }

        const [units] = await connection.query(
            `SELECT unit_id, unit_code, unit_name, decimal_places
             FROM unit WHERE unit_id = ? LIMIT 1`,
            [unitId]
        );

        if (units.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Unit not found'
            });
        }

        const existing = units[0];
        const unitCode = String(
            req.body.unitCode ?? existing.unit_code
        ).trim();
        const unitName = String(
            req.body.unitName ?? existing.unit_name
        ).trim();
        const decimalPlaces = req.body.decimalPlaces === undefined
            ? Number(existing.decimal_places ?? 3)
            : Number(req.body.decimalPlaces);

        if (!unitCode) {
            return res.status(400).json({
                success: false,
                message: 'unitCode is required'
            });
        }
        if (unitCode.length > 20) {
            return res.status(400).json({
                success: false,
                message: 'unitCode cannot exceed 20 characters'
            });
        }
        if (!unitName) {
            return res.status(400).json({
                success: false,
                message: 'unitName is required'
            });
        }
        if (unitName.length > 50) {
            return res.status(400).json({
                success: false,
                message: 'unitName cannot exceed 50 characters'
            });
        }
        if (!Number.isInteger(decimalPlaces) || decimalPlaces < 0 || decimalPlaces > 10) {
            return res.status(400).json({
                success: false,
                message: 'decimalPlaces must be a whole number between 0 and 10'
            });
        }

        try {
            await connection.query(
                `UPDATE unit
                 SET unit_code = ?, unit_name = ?, decimal_places = ?
                 WHERE unit_id = ?`,
                [unitCode, unitName, decimalPlaces, unitId]
            );
        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message: 'Unit code already exists'
                });
            }
            throw error;
        }

        return res.json({
            success: true,
            message: 'Unit updated successfully'
        });
    } catch (error) {
        console.error('Update unit error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to update unit'
        });
    } finally {
        connection.release();
    }
};


// ============================================================
// GET INVENTORY CATEGORIES
//
// GET /inventory/categories
// ============================================================

exports.getCategories = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const [rows] = await connection.query(
            `
            SELECT
                inventory_category_id,
                category_code,
                category_name

            FROM inventory_category

            WHERE company_id = ?

            ORDER BY
                category_name
            `,
            [
                req.user.companyId
            ]
        );

        return res.json({
            success: true,
            categories: rows.map(row => ({
                inventoryCategoryId: row.inventory_category_id,
                categoryCode: row.category_code,
                categoryName: row.category_name
            }))
        });

    } catch (error) {
        console.error(
            'Get inventory categories error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get inventory categories'
        });

    } finally {
        connection.release();
    }
};



// ============================================================
// INVENTORY CATEGORY MASTER CRUD ADDITIONS
// Paste these two handlers into the existing inventoryController.js,
// immediately after exports.getCategories (or another suitable location).
// Existing exports.getCategories remains unchanged.
// ============================================================

exports.createInventoryCategory = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const code = String(req.body.categoryCode || '').trim();
        const name = String(req.body.categoryName || '').trim();

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'categoryCode is required'
            });
        }
        if (code.length > 50) {
            return res.status(400).json({
                success: false,
                message: 'categoryCode cannot exceed 50 characters'
            });
        }
        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'categoryName is required'
            });
        }
        if (name.length > 150) {
            return res.status(400).json({
                success: false,
                message: 'categoryName cannot exceed 150 characters'
            });
        }

        try {
            const [result] = await connection.query(
                `INSERT INTO inventory_category
                    (company_id, category_code, category_name)
                 VALUES (?, ?, ?)`,
                [req.user.companyId, code, name]
            );

            return res.status(201).json({
                success: true,
                message: 'Inventory category created successfully',
                category: {
                    inventoryCategoryId: result.insertId,
                    categoryCode: code,
                    categoryName: name
                }
            });
        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message: 'Category code already exists for this company'
                });
            }
            throw error;
        }
    } catch (error) {
        console.error('Create inventory category error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to create inventory category'
        });
    } finally {
        connection.release();
    }
};

exports.updateInventoryCategory = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const categoryId = Number(req.params.categoryId);
        if (!Number.isSafeInteger(categoryId) || categoryId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid categoryId'
            });
        }

        const [rows] = await connection.query(
            `SELECT inventory_category_id, category_code, category_name
             FROM inventory_category
             WHERE inventory_category_id = ? AND company_id = ?
             LIMIT 1`,
            [categoryId, req.user.companyId]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Inventory category not found'
            });
        }

        const existing = rows[0];
        const code = String(
            req.body.categoryCode ?? existing.category_code
        ).trim();
        const name = String(
            req.body.categoryName ?? existing.category_name
        ).trim();

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'categoryCode is required'
            });
        }
        if (code.length > 50) {
            return res.status(400).json({
                success: false,
                message: 'categoryCode cannot exceed 50 characters'
            });
        }
        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'categoryName is required'
            });
        }
        if (name.length > 150) {
            return res.status(400).json({
                success: false,
                message: 'categoryName cannot exceed 150 characters'
            });
        }

        try {
            await connection.query(
                `UPDATE inventory_category
                 SET category_code = ?, category_name = ?
                 WHERE inventory_category_id = ? AND company_id = ?`,
                [code, name, categoryId, req.user.companyId]
            );
        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message: 'Category code already exists for this company'
                });
            }
            throw error;
        }

        return res.json({
            success: true,
            message: 'Inventory category updated successfully'
        });
    } catch (error) {
        console.error('Update inventory category error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unable to update inventory category'
        });
    } finally {
        connection.release();
    }
};



// ============================================================
// GET SUPPLIERS
//
// GET /inventory/suppliers
//
// Optional query:
//     active=true|false
// ============================================================

exports.getSuppliers = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const activeQuery =
            req.query.active;

        const params = [
            req.user.companyId
        ];

        let activeCondition = '';

        if (
            activeQuery !== undefined &&
            activeQuery !== null &&
            activeQuery !== ''
        ) {
            const active =
                String(activeQuery).toLowerCase() === 'true';

            activeCondition =
                ' AND s.is_active = ? ';

            params.push(active ? 1 : 0);
        }

        const [rows] = await connection.query(
            `
            SELECT
                s.supplier_id,
                s.supplier_uuid,
                s.supplier_code,
                s.supplier_name,
                s.mobile,
                s.email,
                s.gstin,
                s.address1,
                s.address2,
                s.city,
                s.state,
                s.pincode,
                s.opening_balance,
                s.is_active

            FROM supplier s

            WHERE s.company_id = ?
            ${activeCondition}

            ORDER BY
                s.supplier_name
            `,
            params
        );

        return res.json({
            success: true,
            suppliers: rows.map(row => ({
                supplierId: row.supplier_id,
                supplierUuid: row.supplier_uuid,
                supplierCode: row.supplier_code,
                supplierName: row.supplier_name,
                mobile: row.mobile,
                email: row.email,
                gstin: row.gstin,
                address1: row.address1,
                address2: row.address2,
                city: row.city,
                state: row.state,
                pincode: row.pincode,
                openingBalance:
                    Number(row.opening_balance || 0),
                isActive:
                    Boolean(row.is_active)
            }))
        });

    } catch (error) {
        console.error(
            'Get suppliers error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get suppliers'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// CREATE SUPPLIER
//
// POST /inventory/suppliers
// ============================================================

exports.createSupplier = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            supplierCode,
            supplierName,
            mobile = null,
            email = null,
            gstin = null,
            address1 = null,
            address2 = null,
            city = null,
            state = null,
            pincode = null,
            openingBalance = 0
        } = req.body;

        const code =
            String(supplierCode || '').trim();

        const name =
            String(supplierName || '').trim();

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'supplierCode is required'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'supplierName is required'
            });
        }

        const balance =
            Number(openingBalance || 0);

        if (!Number.isFinite(balance)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid openingBalance'
            });
        }

        const supplierUuid =
            crypto.randomUUID();

        try {
            const [result] = await connection.query(
                `
                INSERT INTO supplier
                (
                    supplier_uuid,
                    company_id,
                    supplier_code,
                    supplier_name,
                    mobile,
                    email,
                    gstin,
                    address1,
                    address2,
                    city,
                    state,
                    pincode,
                    opening_balance,
                    is_active
                )
                VALUES
                (
                    ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, TRUE
                )
                `,
                [
                    supplierUuid,
                    req.user.companyId,
                    code,
                    name,
                    mobile,
                    email,
                    gstin,
                    address1,
                    address2,
                    city,
                    state,
                    pincode,
                    balance
                ]
            );

            const supplierId =
                result.insertId;

            return res.status(201).json({
                success: true,
                message: 'Supplier created successfully',
                supplier: {
                    supplierId,
                    supplierUuid,
                    supplierCode: code,
                    supplierName: name,
                    mobile,
                    email,
                    gstin,
                    address1,
                    address2,
                    city,
                    state,
                    pincode,
                    openingBalance: balance,
                    isActive: true
                }
            });

        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message:
                        'Supplier code already exists'
                });
            }

            throw error;
        }

    } catch (error) {
        console.error(
            'Create supplier error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to create supplier'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE SUPPLIER
//
// PUT /inventory/suppliers/:supplierId
// ============================================================

exports.updateSupplier = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const supplierId =
            Number(req.params.supplierId);

        if (!supplierId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid supplierId'
            });
        }

        const [suppliers] = await connection.query(
            `
            SELECT *
            FROM supplier
            WHERE supplier_id = ?
              AND company_id = ?
            LIMIT 1
            `,
            [
                supplierId,
                req.user.companyId
            ]
        );

        if (suppliers.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Supplier not found'
            });
        }

        const supplier =
            suppliers[0];

        const {
            supplierCode = supplier.supplier_code,
            supplierName = supplier.supplier_name,
            mobile = supplier.mobile,
            email = supplier.email,
            gstin = supplier.gstin,
            address1 = supplier.address1,
            address2 = supplier.address2,
            city = supplier.city,
            state = supplier.state,
            pincode = supplier.pincode,
            openingBalance = supplier.opening_balance,
            isActive = supplier.is_active
        } = req.body;

        const code =
            String(supplierCode || '').trim();

        const name =
            String(supplierName || '').trim();

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'supplierCode is required'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'supplierName is required'
            });
        }

        const balance =
            Number(openingBalance || 0);

        if (!Number.isFinite(balance)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid openingBalance'
            });
        }

        const active =
            Number(isActive) ? 1 : 0;

        try {
            await connection.query(
                `
                UPDATE supplier

                SET
                    supplier_code = ?,
                    supplier_name = ?,
                    mobile = ?,
                    email = ?,
                    gstin = ?,
                    address1 = ?,
                    address2 = ?,
                    city = ?,
                    state = ?,
                    pincode = ?,
                    opening_balance = ?,
                    is_active = ?

                WHERE supplier_id = ?
                  AND company_id = ?
                `,
                [
                    code,
                    name,
                    mobile,
                    email,
                    gstin,
                    address1,
                    address2,
                    city,
                    state,
                    pincode,
                    balance,
                    active,
                    supplierId,
                    req.user.companyId
                ]
            );

        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message:
                        'Supplier code already exists'
                });
            }

            throw error;
        }

        return res.json({
            success: true,
            message: 'Supplier updated successfully'
        });

    } catch (error) {
        console.error(
            'Update supplier error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to update supplier'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// GET RAW MATERIALS
//
// GET /inventory/raw-materials?outletId=1
//
// Optional:
//     categoryId
//     search
//     active=true|false
// ============================================================

exports.getRawMaterials = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId =
            Number(req.query.outletId);

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outletId,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        const conditions = [
            'rm.outlet_id = ?'
        ];

        const params = [
            outletId
        ];

        if (req.query.categoryId) {
            const categoryId =
                Number(req.query.categoryId);

            if (!categoryId) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid categoryId'
                });
            }

            conditions.push(
                'rm.inventory_category_id = ?'
            );

            params.push(categoryId);
        }

        if (req.query.search) {
            const search =
                String(req.query.search).trim();

            if (search) {
                conditions.push(
                    `
                    (
                        rm.material_code LIKE ?
                        OR rm.material_name LIKE ?
                    )
                    `
                );

                const pattern =
                    `%${search}%`;

                params.push(pattern);
                params.push(pattern);
            }
        }

        if (
            req.query.active !== undefined
        ) {
            const active =
                String(req.query.active)
                    .toLowerCase() === 'true';

            conditions.push(
                'rm.is_active = ?'
            );

            params.push(
                active ? 1 : 0
            );
        }

        const [rows] = await connection.query(
            `
            SELECT
                rm.raw_material_id,
                rm.raw_material_uuid,
                rm.outlet_id,

                rm.inventory_category_id,
                ic.category_code,
                ic.category_name,
                        
                rm.tax_group_id,
                tg.tax_group_code,
                tg.tax_group_name,
                        
                rm.material_code,
                rm.material_name,

                rm.unit_id,
                u.unit_code,
                u.unit_name,
                u.decimal_places,

                rm.purchase_rate,
                rm.reorder_level,
                rm.reorder_qty,
                rm.is_active

            FROM raw_material rm

            LEFT JOIN inventory_category ic
            ON ic.inventory_category_id =
                 rm.inventory_category_id

            LEFT JOIN tax_group tg
                ON tg.tax_group_id = rm.tax_group_id

            INNER JOIN unit u
                ON u.unit_id = rm.unit_id

            WHERE ${conditions.join(' AND ')}

            ORDER BY
                rm.material_name
            `,
            params
        );

        return res.json({
            success: true,
            rawMaterials: rows.map(row => ({
                rawMaterialId:
                    row.raw_material_id,

                rawMaterialUuid:
                    row.raw_material_uuid,

                outletId:
                    row.outlet_id,

                inventoryCategoryId:
                    row.inventory_category_id,

                taxGroupId:
                    row.tax_group_id === null
                        ? null
                        : Number(row.tax_group_id),

                taxGroupCode:
                    row.tax_group_code,

                taxGroupName:
                    row.tax_group_name,


                    
                categoryCode:
                    row.category_code,

                categoryName:
                    row.category_name,

                materialCode:
                    row.material_code,

                materialName:
                    row.material_name,

                unitId:
                    row.unit_id,

                unitCode:
                    row.unit_code,

                unitName:
                    row.unit_name,

                decimalPlaces:
                    Number(row.decimal_places || 0),

                purchaseRate:
                    Number(row.purchase_rate || 0),

                reorderLevel:
                    Number(row.reorder_level || 0),

                reorderQty:
                    Number(row.reorder_qty || 0),

                isActive:
                    Boolean(row.is_active)
            }))
        });

    } catch (error) {
        console.error(
            'Get raw materials error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get raw materials'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// GET RAW MATERIAL BY ID
//
// GET /inventory/raw-materials/:rawMaterialId?outletId=1
// ============================================================

exports.getRawMaterial = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const rawMaterialId =
            Number(req.params.rawMaterialId);

        const outletId =
            Number(req.query.outletId);

        if (!rawMaterialId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid rawMaterialId'
            });
        }

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outletId,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        const [rows] = await connection.query(
            `
            SELECT
                rm.raw_material_id,
                rm.raw_material_uuid,
                rm.outlet_id,

                rm.inventory_category_id,
                ic.category_code,
                ic.category_name,

                rm.tax_group_id,
                tg.tax_group_code,
                tg.tax_group_name,

                rm.material_code,
                rm.material_name,

                rm.unit_id,
                u.unit_code,
                u.unit_name,
                u.decimal_places,

                rm.purchase_rate,
                rm.reorder_level,
                rm.reorder_qty,
                rm.is_active

            FROM raw_material rm

            LEFT JOIN inventory_category ic
                ON ic.inventory_category_id =
                   rm.inventory_category_id
            LEFT JOIN tax_group tg
                ON tg.tax_group_id = rm.tax_group_id
            INNER JOIN unit u
                ON u.unit_id = rm.unit_id

            WHERE rm.raw_material_id = ?
              AND rm.outlet_id = ?

            LIMIT 1
            `,
            [
                rawMaterialId,
                outletId
            ]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found'
            });
        }

        const row =
            rows[0];

        return res.json({
            success: true,
            rawMaterial: {
                rawMaterialId:
                    row.raw_material_id,

                rawMaterialUuid:
                    row.raw_material_uuid,

                outletId:
                    row.outlet_id,

                inventoryCategoryId:
                    row.inventory_category_id,

                categoryCode:
                    row.category_code,

                categoryName:
                    row.category_name,

                materialCode:
                    row.material_code,

                materialName:
                    row.material_name,

                unitId:
                    row.unit_id,

                unitCode:
                    row.unit_code,

                unitName:
                    row.unit_name,

                taxGroupId:
                    row.tax_group_id === null
                        ? null
                        : Number(row.tax_group_id),

                taxGroupCode:
                    row.tax_group_code,

                taxGroupName:
                    row.tax_group_name,

                decimalPlaces:
                    Number(row.decimal_places || 0),

                purchaseRate:
                    Number(row.purchase_rate || 0),

                reorderLevel:
                    Number(row.reorder_level || 0),

                reorderQty:
                    Number(row.reorder_qty || 0),

                isActive:
                    Boolean(row.is_active)
            }
        });

    } catch (error) {
        console.error(
            'Get raw material error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get raw material'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// CREATE RAW MATERIAL
//
// POST /inventory/raw-materials
// ============================================================

exports.createRawMaterial = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            outletId,
            inventoryCategoryId = null,
            taxGroupId = null,
            materialCode,
            materialName,
            unitId,
            purchaseRate: purchaseRateInput = 0,
            reorderLevel: reorderLevelInput = 0,
            reorderQty: reorderQtyInput = 0
        } = req.body;

        const outlet =
            Number(outletId);

        const categoryId =
            inventoryCategoryId === null ||
            inventoryCategoryId === undefined ||
            inventoryCategoryId === ''
                ? null
                : Number(inventoryCategoryId);

        const taxGroup =
            taxGroupId === null ||
            taxGroupId === undefined ||
            taxGroupId === ''
                ? null
                : Number(taxGroupId);


        const unit =
            Number(unitId);

        const code =
            String(materialCode || '').trim();

        const name =
            String(materialName || '').trim();

        if (!outlet) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'materialCode is required'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'materialName is required'
            });
        }

        if (!unit) {
            return res.status(400).json({
                success: false,
                message: 'unitId is required'
            });
        }

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        const purchaseRate =
            Number(purchaseRateInput || 0);

        const level =
            Number(reorderLevelInput || 0);

        const reorderQuantity =
            Number(reorderQtyInput || 0);

        if (
            !Number.isFinite(purchaseRate) ||
            purchaseRate < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseRate'
            });
        }

        if (
            !Number.isFinite(level) ||
            level < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid reorderLevel'
            });
        }

        if (
            !Number.isFinite(reorderQuantity) ||
            reorderQuantity < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid reorderQty'
            });
        }

        const [units] = await connection.query(
            `
            SELECT
                unit_id,
                unit_code,
                unit_name

            FROM unit

            WHERE unit_id = ?

            LIMIT 1
            `,
            [
                unit
            ]
        );

        if (units.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Unit not found'
            });
        }

        if (categoryId !== null) {
            const [categories] =
                await connection.query(
                    `
                    SELECT
                        inventory_category_id

                    FROM inventory_category

                    WHERE inventory_category_id = ?
                      AND company_id = ?

                    LIMIT 1
                    `,
                    [
                        categoryId,
                        req.user.companyId
                    ]
                );

            if (categories.length === 0) {
                return res.status(400).json({
                    success: false,
                    message:
                        'Inventory category not found'
                });
            }
        }


        if (taxGroup !== null) {
            const [taxGroups] =
                await connection.query(
                    `
                    SELECT
                        tax_group_id
                    FROM tax_group
                    WHERE tax_group_id = ?
                      AND is_active = TRUE
                    LIMIT 1
                    `,
                    [
                        taxGroup
                    ]
                );
            
            if (taxGroups.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Tax group not found or inactive'
                });
            }
        }

        const rawMaterialUuid =
            crypto.randomUUID();

        try {
            const [result] =
                await connection.query(
                    `
                    INSERT INTO raw_material
                    (
                        raw_material_uuid,
                        outlet_id,
                        inventory_category_id,
                        tax_group_id,
                        material_code,
                        material_name,
                        unit_id,
                        purchase_rate,
                        reorder_level,
                        reorder_qty,
                        is_active
                    )
                    VALUES
                    (
                        ?, ?, ?, ?, ?,?, ?, ?, ?, ?, TRUE
                    )
                    `,
                    [
                        rawMaterialUuid,
                        outlet,
                        categoryId,
                        taxGroup,
                        code,
                        name,
                        unit,
                        purchaseRate,
                        level,
                        reorderQuantity
                    ]
                );

            const rawMaterialId =
                result.insertId;

            return res.status(201).json({
                success: true,
                message:
                    'Raw material created successfully',
                rawMaterial: {
                    rawMaterialId,
                    rawMaterialUuid,
                    outletId: outlet,
                    inventoryCategoryId: categoryId,
                    taxGroupId: taxGroup,
                    materialCode: code,
                    materialName: name,
                    unitId: unit,
                    purchaseRate,
                    reorderLevel: level,
                    reorderQty: reorderQuantity,
                    isActive: true
                }
            });

        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message:
                        'Material code already exists for this outlet'
                });
            }

            throw error;
        }

    } catch (error) {
        console.error(
            'Create raw material error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create raw material'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE RAW MATERIAL
//
// PUT /inventory/raw-materials/:rawMaterialId
//
// outletId is not required in the body.
// The existing row determines the outlet and access is checked.
// ============================================================

exports.updateRawMaterial = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const rawMaterialId =
            Number(req.params.rawMaterialId);

        if (!rawMaterialId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid rawMaterialId'
            });
        }

        const [materials] =
            await connection.query(
                `
                SELECT
                    rm.*

                FROM raw_material rm

                WHERE rm.raw_material_id = ?

                LIMIT 1
                `,
                [
                    rawMaterialId
                ]
            );

        if (materials.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Raw material not found'
            });
        }

        const material =
            materials[0];

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                material.outlet_id,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        const {
            inventoryCategoryId =
                material.inventory_category_id,

            taxGroupId =
                 material.tax_group_id,

            materialCode =
                material.material_code,

            materialName =
                material.material_name,

            unitId =
                material.unit_id,

            purchaseRate =
                material.purchase_rate,

            reorderLevel =
                material.reorder_level,

            reorderQty =
                material.reorder_qty,

            isActive =
                material.is_active
        } = req.body;

        const categoryId =
            inventoryCategoryId === null ||
            inventoryCategoryId === undefined ||
            inventoryCategoryId === ''
                ? null
                : Number(inventoryCategoryId);

        const taxGroup =
            taxGroupId === null ||
            taxGroupId === undefined ||
            taxGroupId === ''
                ? null
                : Number(taxGroupId);


        const unit =
            Number(unitId);

        const code =
            String(materialCode || '').trim();

        const name =
            String(materialName || '').trim();

        const rate =
            Number(purchaseRate || 0);

        const level =
            Number(reorderLevel || 0);

        const reorderQuantity =
            Number(reorderQty || 0);

        if (!code) {
            return res.status(400).json({
                success: false,
                message: 'materialCode is required'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'materialName is required'
            });
        }

        if (taxGroup !== null) {
            const [taxGroups] =
                await connection.query(
                    `
                    SELECT
                        tax_group_id
                    FROM tax_group
                    WHERE tax_group_id = ?
                      AND is_active = TRUE
                    LIMIT 1
                    `,
                    [
                        taxGroup
                    ]
                );

    if (taxGroups.length === 0) {
        return res.status(400).json({
            success: false,
            message: 'Tax group not found or inactive'
        });
    }
}


        if (!unit) {
            return res.status(400).json({
                success: false,
                message: 'unitId is required'
            });
        }

        if (
            !Number.isFinite(rate) ||
            rate < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid purchaseRate'
            });
        }

        if (
            !Number.isFinite(level) ||
            level < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid reorderLevel'
            });
        }

        if (
            !Number.isFinite(reorderQuantity) ||
            reorderQuantity < 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid reorderQty'
            });
        }

        const [units] = await connection.query(
            `
            SELECT unit_id
            FROM unit
            WHERE unit_id = ?
            LIMIT 1
            `,
            [
                unit
            ]
        );

        if (units.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Unit not found'
            });
        }

        if (categoryId !== null) {
            const [categories] =
                await connection.query(
                    `
                    SELECT
                        inventory_category_id

                    FROM inventory_category

                    WHERE inventory_category_id = ?
                      AND company_id = ?

                    LIMIT 1
                    `,
                    [
                        categoryId,
                        req.user.companyId
                    ]
                );

            if (categories.length === 0) {
                return res.status(400).json({
                    success: false,
                    message:
                        'Inventory category not found'
                });
            }
        }

        const active =
            Number(isActive) ? 1 : 0;

        try {
            await connection.query(
                `
                UPDATE raw_material

                SET
                    inventory_category_id = ?,
                    tax_group_id = ?,
                    material_code = ?,
                    material_name = ?,
                    unit_id = ?,
                    purchase_rate = ?,
                    reorder_level = ?,
                    reorder_qty = ?,
                    is_active = ?

                WHERE raw_material_id = ?
                  AND outlet_id = ?
                `,
                [
                    categoryId,
                    taxGroup,
                    code,
                    name,
                    unit,
                    rate,
                    level,
                    reorderQuantity,
                    active,
                    rawMaterialId,
                    material.outlet_id
                ]
            );

        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') {
                return res.status(409).json({
                    success: false,
                    message:
                        'Material code already exists for this outlet'
                });
            }

            throw error;
        }

        return res.json({
            success: true,
            message:
                'Raw material updated successfully'
        });

    } catch (error) {
        console.error(
            'Update raw material error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to update raw material'
        });

    } finally {
        connection.release();
    }
};
