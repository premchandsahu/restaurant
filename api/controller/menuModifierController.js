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

function nonNegativeInteger(value, fieldName, fallback) {
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

function nullableInteger(value, fieldName) {
    if (value === undefined || value === null || value === '') return null;
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) {
        throw apiError(400, `${fieldName} must be a positive integer or null`);
    }
    return n;
}

function groupFields(body, existing = null) {
    const groupName = String(
        body.groupName ?? existing?.group_name ?? ''
    ).trim();

    const selectionType = String(
        body.selectionType ?? existing?.selection_type ?? 'MULTIPLE'
    ).trim().toUpperCase();

    if (!groupName) throw apiError(400, 'groupName is required');
    if (groupName.length > 100) {
        throw apiError(400, 'groupName cannot exceed 100 characters');
    }
    if (!['SINGLE', 'MULTIPLE'].includes(selectionType)) {
        throw apiError(400, 'selectionType must be SINGLE or MULTIPLE');
    }

    const minSelection = nonNegativeInteger(
        body.minSelection,
        'minSelection',
        existing ? Number(existing.min_selection) : 0
    );

    let maxSelection = nonNegativeInteger(
        body.maxSelection,
        'maxSelection',
        existing ? Number(existing.max_selection) : (selectionType === 'SINGLE' ? 1 : 99)
    );

    if (selectionType === 'SINGLE') maxSelection = 1;
    if (minSelection > maxSelection) {
        throw apiError(400, 'minSelection cannot exceed maxSelection');
    }

    const displayOrder = nonNegativeInteger(
        body.displayOrder,
        'displayOrder',
        existing ? Number(existing.display_order) : 0
    );

    const isActive = body.isActive === undefined
        ? (existing ? booleanValue(existing.is_active, true) : true)
        : booleanValue(body.isActive, true);

    return { groupName, selectionType, minSelection, maxSelection, displayOrder, isActive };
}

function optionFields(body, existing = null) {
    const optionName = String(
        body.optionName ?? existing?.option_name ?? ''
    ).trim();

    if (!optionName) throw apiError(400, 'optionName is required');
    if (optionName.length > 150) {
        throw apiError(400, 'optionName cannot exceed 150 characters');
    }

    const extraRate = body.extraRate === undefined || body.extraRate === null || body.extraRate === ''
        ? (existing ? Number(existing.extra_rate) : 0)
        : Number(body.extraRate);

    if (!Number.isFinite(extraRate) || extraRate < 0) {
        throw apiError(400, 'extraRate must be a non-negative number');
    }

    const taxGroupId = body.taxGroupId === undefined
        ? (existing ? (existing.tax_group_id == null ? null : Number(existing.tax_group_id)) : null)
        : nullableInteger(body.taxGroupId, 'taxGroupId');

    const displayOrder = nonNegativeInteger(
        body.displayOrder,
        'displayOrder',
        existing ? Number(existing.display_order) : 0
    );

    const isActive = body.isActive === undefined
        ? (existing ? booleanValue(existing.is_active, true) : true)
        : booleanValue(body.isActive, true);

    return { optionName, extraRate, taxGroupId, displayOrder, isActive };
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

async function getGroupForOutlet(db, groupId, outletId) {
    const [rows] = await db.query(
        `SELECT modifier_group_id, outlet_id, group_name, selection_type,
                min_selection, max_selection, display_order, is_active
         FROM modifier_group
         WHERE modifier_group_id = ? AND outlet_id = ?
         LIMIT 1`,
        [groupId, outletId]
    );
    return rows[0] || null;
}

async function validateTaxGroup(db, taxGroupId) {
    if (taxGroupId == null) return;
    const [rows] = await db.query(
        'SELECT tax_group_id FROM tax_group WHERE tax_group_id = ? LIMIT 1',
        [taxGroupId]
    );
    if (rows.length === 0) throw apiError(400, 'Invalid taxGroupId');
}

// GET /menu/modifier-groups?outletId=1
// Returns active and inactive groups/options for the master editor.
exports.getModifierGroups = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.query.outletId, 'outletId');

        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const [groups] = await db.query(
            `SELECT modifier_group_id, outlet_id, group_name, selection_type,
                    min_selection, max_selection, display_order, is_active
             FROM modifier_group
             WHERE outlet_id = ?
             ORDER BY display_order, group_name`,
            [outletId]
        );

        let options = [];
        if (groups.length > 0) {
            const ids = groups.map(g => g.modifier_group_id);
            const placeholders = ids.map(() => '?').join(',');
            [options] = await db.query(
                `SELECT modifier_option_id, modifier_group_id, option_name,
                        extra_rate, tax_group_id, display_order, is_active
                 FROM modifier_option
                 WHERE modifier_group_id IN (${placeholders})
                 ORDER BY display_order, option_name`,
                ids
            );
        }

        const optionsByGroup = new Map();
        for (const option of options) {
            const key = String(option.modifier_group_id);
            if (!optionsByGroup.has(key)) optionsByGroup.set(key, []);
            optionsByGroup.get(key).push(option);
        }

        const result = groups.map(group => ({
            ...group,
            options: optionsByGroup.get(String(group.modifier_group_id)) || []
        }));

        return res.json({ success: true, groups: result });
    } catch (error) {
        console.error('Get modifier groups error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to get modifier groups'
        });
    } finally {
        if (db) db.release();
    }
};

// POST /menu/modifier-groups
exports.createModifierGroup = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const fields = groupFields(req.body);
        const [result] = await db.query(
            `INSERT INTO modifier_group
                (outlet_id, group_name, selection_type, min_selection,
                 max_selection, display_order, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [outletId, fields.groupName, fields.selectionType, fields.minSelection,
             fields.maxSelection, fields.displayOrder, fields.isActive ? 1 : 0]
        );

        return res.status(201).json({
            success: true,
            message: 'Modifier group created successfully',
            modifierGroupId: result.insertId
        });
    } catch (error) {
        console.error('Create modifier group error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to create modifier group'
        });
    } finally {
        if (db) db.release();
    }
};

// PUT /menu/modifier-groups/:groupId
exports.updateModifierGroup = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        const groupId = positiveInteger(req.params.groupId, 'groupId');
        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const existing = await getGroupForOutlet(db, groupId, outletId);
        if (!existing) throw apiError(404, 'Modifier group not found');
        const fields = groupFields(req.body, existing);

        await db.query(
            `UPDATE modifier_group
             SET group_name = ?, selection_type = ?, min_selection = ?,
                 max_selection = ?, display_order = ?, is_active = ?
             WHERE modifier_group_id = ? AND outlet_id = ?`,
            [fields.groupName, fields.selectionType, fields.minSelection,
             fields.maxSelection, fields.displayOrder, fields.isActive ? 1 : 0,
             groupId, outletId]
        );

        return res.json({ success: true, message: 'Modifier group updated successfully' });
    } catch (error) {
        console.error('Update modifier group error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to update modifier group'
        });
    } finally {
        if (db) db.release();
    }
};

// POST /menu/modifier-groups/:groupId/options
exports.createModifierOption = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        const groupId = positiveInteger(req.params.groupId, 'groupId');
        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const group = await getGroupForOutlet(db, groupId, outletId);
        if (!group) throw apiError(404, 'Modifier group not found');

        const fields = optionFields(req.body);
        await validateTaxGroup(db, fields.taxGroupId);

        const [result] = await db.query(
            `INSERT INTO modifier_option
                (modifier_group_id, option_name, extra_rate, tax_group_id,
                 display_order, is_active)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [groupId, fields.optionName, fields.extraRate, fields.taxGroupId,
             fields.displayOrder, fields.isActive ? 1 : 0]
        );

        return res.status(201).json({
            success: true,
            message: 'Modifier option created successfully',
            modifierOptionId: result.insertId
        });
    } catch (error) {
        console.error('Create modifier option error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to create modifier option'
        });
    } finally {
        if (db) db.release();
    }
};

// PUT /menu/modifier-groups/:groupId/options/:optionId
exports.updateModifierOption = async (req, res) => {
    let db;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        const groupId = positiveInteger(req.params.groupId, 'groupId');
        const optionId = positiveInteger(req.params.optionId, 'optionId');
        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const group = await getGroupForOutlet(db, groupId, outletId);
        if (!group) throw apiError(404, 'Modifier group not found');

        const [options] = await db.query(
            `SELECT modifier_option_id, modifier_group_id, option_name,
                    extra_rate, tax_group_id, display_order, is_active
             FROM modifier_option
             WHERE modifier_option_id = ? AND modifier_group_id = ?
             LIMIT 1`,
            [optionId, groupId]
        );
        if (options.length === 0) throw apiError(404, 'Modifier option not found');

        const fields = optionFields(req.body, options[0]);
        await validateTaxGroup(db, fields.taxGroupId);

        await db.query(
            `UPDATE modifier_option
             SET option_name = ?, extra_rate = ?, tax_group_id = ?,
                 display_order = ?, is_active = ?
             WHERE modifier_option_id = ? AND modifier_group_id = ?`,
            [fields.optionName, fields.extraRate, fields.taxGroupId,
             fields.displayOrder, fields.isActive ? 1 : 0, optionId, groupId]
        );

        return res.json({ success: true, message: 'Modifier option updated successfully' });
    } catch (error) {
        console.error('Update modifier option error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to update modifier option'
        });
    } finally {
        if (db) db.release();
    }
};

// PUT /menu/items/:menuItemId/modifier-groups
// Body: { outletId: 1, modifierGroupIds: [1, 2] }
exports.setMenuItemModifierGroups = async (req, res) => {
    let db;
    let transactionStarted = false;
    try {
        db = await conn.getConnection();
        const outletId = positiveInteger(req.body.outletId, 'outletId');
        const menuItemId = positiveInteger(req.params.menuItemId, 'menuItemId');
        const rawIds = req.body.modifierGroupIds;

        if (!Array.isArray(rawIds)) {
            throw apiError(400, 'modifierGroupIds must be an array');
        }

        const modifierGroupIds = rawIds.map((value) => positiveInteger(value, 'modifierGroupIds entry'));
        if (new Set(modifierGroupIds.map(String)).size !== modifierGroupIds.length) {
            throw apiError(400, 'modifierGroupIds contains duplicate values');
        }

        if (!(await hasOutletAccess(db, req, outletId))) {
            return res.status(403).json({ success: false, message: 'You are not authorized for this outlet' });
        }

        const [items] = await db.query(
            `SELECT menu_item_id FROM menu_item
             WHERE menu_item_id = ? AND outlet_id = ? LIMIT 1`,
            [menuItemId, outletId]
        );
        if (items.length === 0) throw apiError(404, 'Menu item not found for this outlet');

        if (modifierGroupIds.length > 0) {
            const placeholders = modifierGroupIds.map(() => '?').join(',');
            const [groups] = await db.query(
                `SELECT modifier_group_id FROM modifier_group
                 WHERE outlet_id = ? AND modifier_group_id IN (${placeholders})`,
                [outletId, ...modifierGroupIds]
            );
            if (groups.length !== modifierGroupIds.length) {
                throw apiError(400, 'One or more modifier groups do not belong to this outlet');
            }
        }

        await db.beginTransaction();
        transactionStarted = true;

        await db.query(
            'DELETE FROM menu_item_modifier WHERE menu_item_id = ?',
            [menuItemId]
        );

        for (const groupId of modifierGroupIds) {
            await db.query(
                'INSERT INTO menu_item_modifier (menu_item_id, modifier_group_id) VALUES (?, ?)',
                [menuItemId, groupId]
            );
        }

        await db.commit();
        transactionStarted = false;

        return res.json({
            success: true,
            message: 'Menu item modifier groups updated successfully',
            menuItemId,
            modifierGroupIds
        });
    } catch (error) {
        if (db && transactionStarted) {
            try { await db.rollback(); } catch (_) {}
        }
        console.error('Set menu item modifier groups error:', error);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Unable to update menu item modifier groups'
        });
    } finally {
        if (db) db.release();
    }
};
