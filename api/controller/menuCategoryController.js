const conn = require('../database');

function apiError(statusCode, message) {
    const error = new Error(message);
    error.statusCode = statusCode;
    return error;
}

function positiveInteger(value, fieldName) {
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) {
        throw apiError(400, `${fieldName} must be a positive integer`);
    }
    return n;
}

function nullableInteger(value, fieldName) {
    if (value === undefined || value === null || value === '') return null;
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) {
        throw apiError(400, `${fieldName} must be a positive integer or null`);
    }
    return n;
}

function nonNegativeInteger(value, fieldName, fallback = 0) {
    const n = value === undefined || value === null || value === ''
        ? fallback
        : Number(value);
    if (!Number.isInteger(n) || n < 0) {
        throw apiError(400, `${fieldName} must be a non-negative integer`);
    }
    return n;
}

function booleanValue(value, fallback = true) {
    if (value === undefined || value === null || value === '') return fallback;
    if (typeof value === 'boolean') return value;
    if (typeof value === 'number') return value !== 0;
    return ['1', 'true', 'yes', 'y'].includes(String(value).toLowerCase());
}

async function hasOutletAccess(db, req, outletId) {
    const [rows] = await db.query(
        `SELECT 1
         FROM user_outlet uo
         INNER JOIN outlet o ON o.outlet_id = uo.outlet_id
         WHERE uo.user_id = ?
           AND uo.outlet_id = ?
           AND o.company_id = ?
           AND o.is_active = TRUE
         LIMIT 1`,
        [req.user.userId, outletId, req.user.companyId]
    );
    return rows.length > 0;
}

function categoryFields(body, existing = null) {
    const categoryCode = String(
        body.categoryCode ?? existing?.category_code ?? ''
    ).trim();
    const categoryName = String(
        body.categoryName ?? existing?.category_name ?? ''
    ).trim();

    if (!categoryCode) throw apiError(400, 'categoryCode is required');
    if (categoryCode.length > 50) {
        throw apiError(400, 'categoryCode cannot exceed 50 characters');
    }
    if (!categoryName) throw apiError(400, 'categoryName is required');
    if (categoryName.length > 150) {
        throw apiError(400, 'categoryName cannot exceed 150 characters');
    }

    const parentCategoryId = body.parentCategoryId === undefined
        ? (existing?.parent_category_id == null ? null : Number(existing.parent_category_id))
        : nullableInteger(body.parentCategoryId, 'parentCategoryId');

    const displayOrder = nonNegativeInteger(
        body.displayOrder,
        'displayOrder',
        existing ? Number(existing.display_order || 0) : 0
    );

    const isActive = body.isActive === undefined
        ? (existing ? booleanValue(existing.is_active, true) : true)
        : booleanValue(body.isActive, true);

    return { categoryCode, categoryName, parentCategoryId, displayOrder, isActive };
}

async function validateParentCategory(db, outletId, parentCategoryId, categoryId = null) {
    if (parentCategoryId == null) return;
    if (categoryId != null && parentCategoryId === categoryId) {
        throw apiError(400, 'A category cannot be its own parent');
    }

    const [parents] = await db.query(
        `SELECT menu_category_id, parent_category_id
         FROM menu_category
         WHERE menu_category_id = ? AND outlet_id = ?
         LIMIT 1`,
        [parentCategoryId, outletId]
    );
    if (parents.length === 0) {
        throw apiError(400, 'Parent category must belong to the same outlet');
    }

    // Prevent circular parent relationships when editing an existing category.
    if (categoryId != null) {
        let currentId = parentCategoryId;
        const visited = new Set();
        while (currentId != null) {
            if (currentId === categoryId) {
                throw apiError(400, 'This parent selection would create a category cycle');
            }
            if (visited.has(currentId)) {
                throw apiError(400, 'The selected parent already contains a category cycle');
            }
            visited.add(currentId);
            const [rows] = await db.query(
                `SELECT parent_category_id
                 FROM menu_category
                 WHERE menu_category_id = ? AND outlet_id = ?
                 LIMIT 1`,
                [currentId, outletId]
            );
            if (rows.length === 0 || rows[0].parent_category_id == null) break;
            currentId = Number(rows[0].parent_category_id);
        }
    }
}

// GET /menu/category-master?outletId=1
// Master endpoint returns active and inactive rows so inactive categories can be reactivated.
exports.getCategories = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.query.outletId, 'outletId');

        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const [categories] = await db.query(
            `SELECT
                c.menu_category_id,
                c.outlet_id,
                c.category_code,
                c.category_name,
                c.parent_category_id,
                p.category_name AS parent_category_name,
                c.display_order,
                c.is_active
             FROM menu_category c
             LEFT JOIN menu_category p
                ON p.menu_category_id = c.parent_category_id
               AND p.outlet_id = c.outlet_id
             WHERE c.outlet_id = ?
             ORDER BY c.display_order, c.category_name`,
            [outletId]
        );

        return res.json({ success: true, categories });
    } catch (error) {
        console.error('Get menu category master error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to get menu categories'
        });
    } finally {
        if (db) db.release();
    }
};

// POST /menu/category-master
exports.createCategory = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');

        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const fields = categoryFields(req.body);
        await validateParentCategory(db, outletId, fields.parentCategoryId);

        const [result] = await db.query(
            `INSERT INTO menu_category
                (outlet_id, category_code, category_name, parent_category_id, display_order, is_active)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [outletId, fields.categoryCode, fields.categoryName,
             fields.parentCategoryId, fields.displayOrder, fields.isActive ? 1 : 0]
        );

        return res.status(201).json({
            success: true,
            message: 'Menu category created successfully',
            categoryId: result.insertId
        });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ success: false, message: 'Category code already exists for this outlet' });
        }
        console.error('Create menu category error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to create menu category'
        });
    } finally {
        if (db) db.release();
    }
};

// PUT /menu/category-master/:categoryId
exports.updateCategory = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        const categoryId = positiveInteger(req.params.categoryId, 'categoryId');

        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const [existingRows] = await db.query(
            `SELECT menu_category_id, outlet_id, category_code, category_name,
                    parent_category_id, display_order, is_active
             FROM menu_category
             WHERE menu_category_id = ? AND outlet_id = ?
             LIMIT 1`,
            [categoryId, outletId]
        );
        if (existingRows.length === 0) {
            throw apiError(404, 'Menu category not found');
        }

        const fields = categoryFields(req.body, existingRows[0]);
        await validateParentCategory(db, outletId, fields.parentCategoryId, categoryId);

        await db.query(
            `UPDATE menu_category
             SET category_code = ?, category_name = ?, parent_category_id = ?,
                 display_order = ?, is_active = ?
             WHERE menu_category_id = ? AND outlet_id = ?`,
            [fields.categoryCode, fields.categoryName, fields.parentCategoryId,
             fields.displayOrder, fields.isActive ? 1 : 0, categoryId, outletId]
        );

        return res.json({ success: true, message: 'Menu category updated successfully' });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ success: false, message: 'Category code already exists for this outlet' });
        }
        console.error('Update menu category error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to update menu category'
        });
    } finally {
        if (db) db.release();
    }
};
