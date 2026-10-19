const conn =  require('../database');



const TAX_TYPES = ['CGST', 'SGST', 'IGST', 'CESS', 'OTHER'];

function getBodyValue(body, camelCase, snakeCase) {
    if (body[camelCase] !== undefined) {
        return body[camelCase];
    }
    return body[snakeCase];
}

function parseTinyInt(value, defaultValue = null) {
    if (value === undefined || value === null) {
        return defaultValue;
    }

    if (value === true || value === 1 || value === '1') {
        return 1;
    }

    if (value === false || value === 0 || value === '0') {
        return 0;
    }

    if (typeof value === 'string') {
        const normalized = value.trim().toLowerCase();

        if (normalized === 'true') return 1;
        if (normalized === 'false') return 0;
    }

    return null;
}

function parsePositiveId(value) {
    const id = Number(value);

    return Number.isSafeInteger(id) && id > 0
        ? id
        : null;
}

function parseTaxRate(value) {
    if (
        value === undefined ||
        value === null ||
        String(value).trim() === ''
    ) {
        return null;
    }

    const rate = Number(value);

    if (
        !Number.isFinite(rate) ||
        rate < 0 ||
        rate > 9999.9999
    ) {
        return null;
    }

    return rate;
}


// ==================================================
// GET TAX GROUPS
// GET /tax/groups
// ==================================================

exports.getTaxGroups = async (req, res) => {
     const db=await conn.getConnection();
    try {

        const sql = `
            SELECT
                tg.tax_group_id,
                tg.tax_group_code,
                tg.tax_group_name,

                tr.tax_rate_id,
                tr.tax_name,
                tr.tax_type,
                tr.rate,
                tr.is_inclusive,
                tr.is_active

            FROM tax_group tg

            LEFT JOIN tax_rate tr
                ON tr.tax_group_id =
                   tg.tax_group_id
                AND tr.is_active = 1

            WHERE tg.is_active = 1

            ORDER BY
                tg.tax_group_id,
                tr.tax_type
        `;


        const [rows] =
            await db.query(sql);


        // ------------------------------------------
        // Convert flat SQL result into
        // taxGroup -> rates structure
        // ------------------------------------------

        const taxGroups = [];


        for (const row of rows) {

            let group =
                taxGroups.find(
                    g =>
                        g.tax_group_id ===
                        row.tax_group_id
                );


            if (!group) {

                group = {

                    tax_group_id:
                        row.tax_group_id,

                    tax_group_code:
                        row.tax_group_code,

                    tax_group_name:
                        row.tax_group_name,

                    rates: []
                };


                taxGroups.push(group);
            }


            // LEFT JOIN can produce NULL
            // when a group has no active rates

            if (row.tax_rate_id !== null) {

                group.rates.push({

                    tax_rate_id:
                        row.tax_rate_id,

                    tax_name:
                        row.tax_name,

                    tax_type:
                        row.tax_type,

                    rate:
                        row.rate,

                    is_inclusive:
                        row.is_inclusive,

                    is_active:
                        row.is_active
                });
            }
        }


        return res.json({

            success: true,

            taxGroups
        });


    } catch (error) {

        console.error(
            'Get tax groups error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get tax groups'
        });
    }
};


// ==================================================
// GET SINGLE TAX GROUP
// GET /tax/groups/:taxGroupId
// ==================================================

exports.getTaxGroup = async (req, res) => {
 const db=await conn.getConnection();
    try {

        const taxGroupId =
            Number(
                req.params.taxGroupId
            );


        if (!taxGroupId) {

            return res.status(400).json({

                success: false,

                message:
                    'Invalid tax group id'
            });
        }


        const sql = `
            SELECT
                tg.tax_group_id,
                tg.tax_group_code,
                tg.tax_group_name,

                tr.tax_rate_id,
                tr.tax_name,
                tr.tax_type,
                tr.rate,
                tr.is_inclusive,
                tr.is_active

            FROM tax_group tg

            LEFT JOIN tax_rate tr
                ON tr.tax_group_id =
                   tg.tax_group_id
                AND tr.is_active = 1

            WHERE
                tg.tax_group_id = ?
                AND tg.is_active = 1

            ORDER BY
                tr.tax_type
        `;


        const [rows] =
            await db.query(
                sql,
                [taxGroupId]
            );


        if (rows.length === 0) {

            return res.status(404).json({

                success: false,

                message:
                    'Tax group not found'
            });
        }


        const firstRow =
            rows[0];


        const taxGroup = {

            tax_group_id:
                firstRow.tax_group_id,

            tax_group_code:
                firstRow.tax_group_code,

            tax_group_name:
                firstRow.tax_group_name,

            rates: []
        };


        for (const row of rows) {

            if (row.tax_rate_id !== null) {

                taxGroup.rates.push({

                    tax_rate_id:
                        row.tax_rate_id,

                    tax_name:
                        row.tax_name,

                    tax_type:
                        row.tax_type,

                    rate:
                        row.rate,

                    is_inclusive:
                        row.is_inclusive,

                    is_active:
                        row.is_active
                });
            }
        }


        return res.json({

            success: true,

            taxGroup
        });


    } catch (error) {

        console.error(
            'Get tax group error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get tax group'
        });
    }
};


// ==================================================
// GET TAX RATES
// GET /tax/groups/:taxGroupId/rates
// ==================================================

exports.getTaxRates = async (req, res) => {
 const db=await conn.getConnection();
    try {

        const taxGroupId =
            Number(
                req.params.taxGroupId
            );


        if (!taxGroupId) {

            return res.status(400).json({

                success: false,

                message:
                    'Invalid tax group id'
            });
        }


        const sql = `
            SELECT
                tax_rate_id,
                tax_group_id,
                tax_name,
                tax_type,
                rate,
                is_inclusive,
                is_active

            FROM tax_rate

            WHERE
                tax_group_id = ?
                AND is_active = 1

            ORDER BY
                tax_type
        `;


        const [rows] =
            await db.query(
                sql,
                [taxGroupId]
            );


        return res.json({

            success: true,

            taxRates: rows
        });


    } catch (error) {

        console.error(
            'Get tax rates error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get tax rates'
        });
    }
};

// ==================================================
// TAX GROUP MASTER - GET ALL GROUPS AND RATES
// GET /tax/groups/master
// Includes inactive groups and rates.
// ==================================================

exports.getTaxGroupsForMaster = async (req, res) => {
    let db;

    try {
        db = await conn.getConnection();

        const [rows] = await db.query(`
            SELECT
                tg.tax_group_id,
                tg.tax_group_code,
                tg.tax_group_name,
                tg.is_active AS group_is_active,

                tr.tax_rate_id,
                tr.tax_name,
                tr.tax_type,
                tr.rate,
                tr.is_inclusive,
                tr.is_active AS rate_is_active

            FROM tax_group tg

            LEFT JOIN tax_rate tr
                ON tr.tax_group_id = tg.tax_group_id

            ORDER BY
                tg.tax_group_name,
                tr.tax_type,
                tr.tax_rate_id
        `);

        const groupsById = new Map();

        for (const row of rows) {
            const key = String(row.tax_group_id);

            if (!groupsById.has(key)) {
                groupsById.set(key, {
                    tax_group_id: row.tax_group_id,
                    tax_group_code: row.tax_group_code,
                    tax_group_name: row.tax_group_name,
                    is_active: row.group_is_active,
                    rates: [],
                });
            }

            if (
                row.tax_rate_id !== null &&
                row.tax_rate_id !== undefined
            ) {
                groupsById.get(key).rates.push({
                    tax_rate_id: row.tax_rate_id,
                    tax_name: row.tax_name,
                    tax_type: row.tax_type,
                    rate: row.rate,
                    is_inclusive: row.is_inclusive,
                    is_active: row.rate_is_active,
                });
            }
        }

        return res.json({
            success: true,
            taxGroups: Array.from(groupsById.values()),
        });
    } catch (error) {
        console.error('Get tax groups for master error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get tax groups',
        });
    } finally {
        if (db) db.release();
    }
};


// ==================================================
// CREATE TAX GROUP
// POST /tax/groups
// ==================================================

exports.createTaxGroup = async (req, res) => {
    const body = req.body || {};

    const code = String(
        getBodyValue(body, 'taxGroupCode', 'tax_group_code') ?? ''
    ).trim();

    const name = String(
        getBodyValue(body, 'taxGroupName', 'tax_group_name') ?? ''
    ).trim();

    const activeRaw = getBodyValue(body, 'isActive', 'is_active');
    const isActive = parseTinyInt(activeRaw, 1);

    if (!code || code.length > 50) {
        return res.status(400).json({
            success: false,
            message: 'Tax group code is required and must not exceed 50 characters',
        });
    }

    if (!name || name.length > 100) {
        return res.status(400).json({
            success: false,
            message: 'Tax group name is required and must not exceed 100 characters',
        });
    }

    if (isActive === null) {
        return res.status(400).json({
            success: false,
            message: 'Invalid isActive value',
        });
    }

    let db;

    try {
        db = await conn.getConnection();

        const [result] = await db.query(
            `INSERT INTO tax_group
                (tax_group_code, tax_group_name, is_active)
             VALUES (?, ?, ?)`,
            [code, name, isActive]
        );

        return res.status(201).json({
            success: true,
            message: 'Tax group created successfully',
            taxGroupId: result.insertId,
        });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message: 'Tax group code already exists',
            });
        }

        console.error('Create tax group error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to create tax group',
        });
    } finally {
        if (db) db.release();
    }
};


// ==================================================
// UPDATE TAX GROUP
// PUT /tax/groups/:taxGroupId
// ==================================================

exports.updateTaxGroup = async (req, res) => {
    const taxGroupId = parsePositiveId(req.params.taxGroupId);
    const body = req.body || {};

    if (!taxGroupId) {
        return res.status(400).json({
            success: false,
            message: 'Invalid tax group id',
        });
    }

    const code = String(
        getBodyValue(body, 'taxGroupCode', 'tax_group_code') ?? ''
    ).trim();

    const name = String(
        getBodyValue(body, 'taxGroupName', 'tax_group_name') ?? ''
    ).trim();

    const activeRaw = getBodyValue(body, 'isActive', 'is_active');
    const isActive = parseTinyInt(activeRaw, null);

    if (!code || code.length > 50) {
        return res.status(400).json({
            success: false,
            message: 'Tax group code is required and must not exceed 50 characters',
        });
    }

    if (!name || name.length > 100) {
        return res.status(400).json({
            success: false,
            message: 'Tax group name is required and must not exceed 100 characters',
        });
    }

    if (
        activeRaw !== undefined &&
        activeRaw !== null &&
        isActive === null
    ) {
        return res.status(400).json({
            success: false,
            message: 'Invalid isActive value',
        });
    }

    let db;

    try {
        db = await conn.getConnection();

        const [existing] = await db.query(
            'SELECT tax_group_id FROM tax_group WHERE tax_group_id = ?',
            [taxGroupId]
        );

        if (existing.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Tax group not found',
            });
        }

        await db.query(
            `UPDATE tax_group
             SET tax_group_code = ?,
                 tax_group_name = ?,
                 is_active = COALESCE(?, is_active)
             WHERE tax_group_id = ?`,
            [code, name, isActive, taxGroupId]
        );

        return res.json({
            success: true,
            message: 'Tax group updated successfully',
        });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message: 'Tax group code already exists',
            });
        }

        console.error('Update tax group error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to update tax group',
        });
    } finally {
        if (db) db.release();
    }
};


// ==================================================
// CREATE TAX RATE
// POST /tax/groups/:taxGroupId/rates
// ==================================================

exports.createTaxRate = async (req, res) => {
    const taxGroupId = parsePositiveId(req.params.taxGroupId);
    const body = req.body || {};

    if (!taxGroupId) {
        return res.status(400).json({
            success: false,
            message: 'Invalid tax group id',
        });
    }

    const taxName = String(
        getBodyValue(body, 'taxName', 'tax_name') ?? ''
    ).trim();

    const taxType = String(
        getBodyValue(body, 'taxType', 'tax_type') ?? ''
    ).trim().toUpperCase();

    const rate = parseTaxRate(body.rate);

    const inclusiveRaw = getBodyValue(
        body, 'isInclusive', 'is_inclusive'
    );

    const activeRaw = getBodyValue(
        body, 'isActive', 'is_active'
    );

    const isInclusive = parseTinyInt(inclusiveRaw, 0);
    const isActive = parseTinyInt(activeRaw, 1);

    if (!taxName || taxName.length > 100) {
        return res.status(400).json({
            success: false,
            message: 'Tax name is required and must not exceed 100 characters',
        });
    }

    if (!TAX_TYPES.includes(taxType)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid tax type. Use CGST, SGST, IGST, CESS or OTHER',
        });
    }

    if (rate === null) {
        return res.status(400).json({
            success: false,
            message: 'Rate must be between 0 and 9999.9999',
        });
    }

    if (isInclusive === null || isActive === null) {
        return res.status(400).json({
            success: false,
            message: 'Invalid isInclusive or isActive value',
        });
    }

    let db;

    try {
        db = await conn.getConnection();

        const [groups] = await db.query(
            'SELECT tax_group_id FROM tax_group WHERE tax_group_id = ?',
            [taxGroupId]
        );

        if (groups.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Tax group not found',
            });
        }

        const [result] = await db.query(
            `INSERT INTO tax_rate
                (tax_group_id, tax_name, tax_type, rate,
                 is_inclusive, is_active)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [
                taxGroupId,
                taxName,
                taxType,
                rate,
                isInclusive,
                isActive,
            ]
        );

        return res.status(201).json({
            success: true,
            message: 'Tax rate created successfully',
            taxRateId: result.insertId,
        });
    } catch (error) {
        console.error('Create tax rate error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to create tax rate',
        });
    } finally {
        if (db) db.release();
    }
};


// ==================================================
// UPDATE TAX RATE
// PUT /tax/rates/:taxRateId
// ==================================================

exports.updateTaxRate = async (req, res) => {
    const taxRateId = parsePositiveId(req.params.taxRateId);
    const body = req.body || {};

    if (!taxRateId) {
        return res.status(400).json({
            success: false,
            message: 'Invalid tax rate id',
        });
    }

    const taxName = String(
        getBodyValue(body, 'taxName', 'tax_name') ?? ''
    ).trim();

    const taxType = String(
        getBodyValue(body, 'taxType', 'tax_type') ?? ''
    ).trim().toUpperCase();

    const rate = parseTaxRate(body.rate);

    const inclusiveRaw = getBodyValue(
        body, 'isInclusive', 'is_inclusive'
    );

    const activeRaw = getBodyValue(
        body, 'isActive', 'is_active'
    );

    const isInclusive = parseTinyInt(inclusiveRaw, null);
    const isActive = parseTinyInt(activeRaw, null);

    if (!taxName || taxName.length > 100) {
        return res.status(400).json({
            success: false,
            message: 'Tax name is required and must not exceed 100 characters',
        });
    }

    if (!TAX_TYPES.includes(taxType)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid tax type',
        });
    }

    if (rate === null) {
        return res.status(400).json({
            success: false,
            message: 'Rate must be between 0 and 9999.9999',
        });
    }

    if (
        (inclusiveRaw !== undefined && inclusiveRaw !== null &&
            isInclusive === null) ||
        (activeRaw !== undefined && activeRaw !== null &&
            isActive === null)
    ) {
        return res.status(400).json({
            success: false,
            message: 'Invalid isInclusive or isActive value',
        });
    }

    let db;

    try {
        db = await conn.getConnection();

        const [existing] = await db.query(
            'SELECT tax_rate_id FROM tax_rate WHERE tax_rate_id = ?',
            [taxRateId]
        );

        if (existing.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Tax rate not found',
            });
        }

        await db.query(
            `UPDATE tax_rate
             SET tax_name = ?,
                 tax_type = ?,
                 rate = ?,
                 is_inclusive = COALESCE(?, is_inclusive),
                 is_active = COALESCE(?, is_active)
             WHERE tax_rate_id = ?`,
            [
                taxName,
                taxType,
                rate,
                isInclusive,
                isActive,
                taxRateId,
            ]
        );

        return res.json({
            success: true,
            message: 'Tax rate updated successfully',
        });
    } catch (error) {
        console.error('Update tax rate error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to update tax rate',
        });
    } finally {
        if (db) db.release();
    }
};