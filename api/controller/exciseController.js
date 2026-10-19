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
// GET LICENSE HOLDERS
//
// GET /excise/license-holders?outletId=1
//
// Optional:
//     active=true
// ============================================================

exports.getLicenseHolders = async (req, res) => {
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

        const activeQuery = req.query.active;

        const params = [
            req.user.companyId,
            outletId
        ];

        let activeCondition = '';

        if (
            activeQuery !== undefined &&
            activeQuery !== null &&
            activeQuery !== ''
        ) {
            const active =
                String(activeQuery).toLowerCase() === 'true';

            activeCondition = `
                AND elh.status = ?
            `;

            params.push(
                active
                    ? 'ACTIVE'
                    : 'CANCELLED'
            );
        }

        const [rows] = await connection.query(
            `
            SELECT
                elh.id,
                elh.company_id,
                elh.outlet_id,
                elh.customer_id,
                elh.license_no,
                elh.license_type,
                elh.holder_name,
                elh.address1,
                elh.address2,
                elh.city,
                elh.state,
                elh.pincode,
                elh.phone,
                elh.email,
                elh.valid_from,
                elh.valid_to,
                elh.status,
                elh.remarks,
                elh.created_by,
                elh.updated_by,
                elh.created_at,
                elh.updated_at
            FROM excise_license_holder elh
            WHERE elh.company_id = ?
              AND elh.outlet_id = ?
            ${activeCondition}
            ORDER BY
                elh.holder_name
            `,
            params
        );

        return res.json({
            success: true,
            licenseHolders: rows.map(row => ({
                id: row.id,
                companyId: row.company_id,
                outletId: row.outlet_id,
                customerId:
                    row.customer_id === null
                        ? null
                        : Number(row.customer_id),

                licenseNo: row.license_no,
                licenseType: row.license_type,
                holderName: row.holder_name,

                address1: row.address1,
                address2: row.address2,
                city: row.city,
                state: row.state,
                pincode: row.pincode,

                phone: row.phone,
                email: row.email,

                validFrom: row.valid_from,
                validTo: row.valid_to,

                status: row.status,

                remarks: row.remarks
            }))
        });

    } catch (error) {
        console.error(
            'Get excise license holders error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get excise license holders'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// GET SINGLE LICENSE HOLDER
//
// GET /excise/license-holders/:holderId?outletId=1
// ============================================================

exports.getLicenseHolder = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const holderId = Number(req.params.holderId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!Number.isInteger(holderId) || holderId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid license holder id'
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

        const [rows] = await connection.query(
            `
            SELECT
                id,
                company_id,
                outlet_id,
                customer_id,
                license_no,
                license_type,
                holder_name,
                address1,
                address2,
                city,
                state,
                pincode,
                phone,
                email,
                valid_from,
                valid_to,
                status,
                remarks
            FROM excise_license_holder
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                holderId,
                req.user.companyId,
                outletId
            ]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Excise license holder not found'
            });
        }

        const row = rows[0];

        return res.json({
            success: true,
            licenseHolder: {
                id: row.id,
                companyId: row.company_id,
                outletId: row.outlet_id,

                customerId:
                    row.customer_id === null
                        ? null
                        : Number(row.customer_id),

                licenseNo: row.license_no,
                licenseType: row.license_type,
                holderName: row.holder_name,

                address1: row.address1,
                address2: row.address2,
                city: row.city,
                state: row.state,
                pincode: row.pincode,

                phone: row.phone,
                email: row.email,

                validFrom: row.valid_from,
                validTo: row.valid_to,

                status: row.status,
                remarks: row.remarks
            }
        });

    } catch (error) {
        console.error(
            'Get excise license holder error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get excise license holder'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// CREATE LICENSE HOLDER
//
// POST /excise/license-holders
// ============================================================

exports.createLicenseHolder = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            outletId,
            customerId = null,
            licenseNo,
            licenseType = null,
            holderName,

            address1 = null,
            address2 = null,
            city = null,
            state = null,
            pincode = null,

            phone = null,
            email = null,

            validFrom = null,
            validTo = null,

            status = 'ACTIVE',
            remarks = null
        } = req.body;

        const parsedOutletId = Number(outletId);

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
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

        const cleanLicenseNo =
            String(licenseNo || '').trim();

        const cleanHolderName =
            String(holderName || '').trim();

        if (!cleanLicenseNo) {
            return res.status(400).json({
                success: false,
                message: 'licenseNo is required'
            });
        }

        if (!cleanHolderName) {
            return res.status(400).json({
                success: false,
                message: 'holderName is required'
            });
        }

        const validStatuses = [
            'ACTIVE',
            'EXPIRED',
            'SUSPENDED',
            'CANCELLED'
        ];

        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status'
            });
        }

        if (
            validFrom &&
            validTo &&
            String(validFrom) > String(validTo)
        ) {
            return res.status(400).json({
                success: false,
                message: 'validFrom cannot be after validTo'
            });
        }

        // ------------------------------------------------------
        // Prevent duplicate licence number within outlet
        // ------------------------------------------------------

        const [existing] = await connection.query(
            `
            SELECT id
            FROM excise_license_holder
            WHERE company_id = ?
              AND outlet_id = ?
              AND license_no = ?
            LIMIT 1
            `,
            [
                req.user.companyId,
                parsedOutletId,
                cleanLicenseNo
            ]
        );

        if (existing.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'This license number already exists for the outlet'
            });
        }

        const parsedCustomerId =
            customerId === null ||
            customerId === undefined ||
            customerId === ''
                ? null
                : Number(customerId);

        if (
            parsedCustomerId !== null &&
            (!Number.isInteger(parsedCustomerId) ||
                parsedCustomerId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid customerId'
            });
        }

        const [result] = await connection.query(
            `
            INSERT INTO excise_license_holder (
                company_id,
                outlet_id,
                customer_id,
                license_no,
                license_type,
                holder_name,
                address1,
                address2,
                city,
                state,
                pincode,
                phone,
                email,
                valid_from,
                valid_to,
                status,
                remarks,
                created_by,
                updated_by
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `,
            [
                req.user.companyId,
                parsedOutletId,
                parsedCustomerId,
                cleanLicenseNo,
                licenseType
                    ? String(licenseType).trim()
                    : null,
                cleanHolderName,

                address1,
                address2,
                city,
                state,
                pincode,

                phone,
                email,

                validFrom || null,
                validTo || null,

                status,
                remarks,

                req.user.userId,
                req.user.userId
            ]
        );

        return res.status(201).json({
            success: true,
            message: 'Excise license holder created successfully',
            id: result.insertId
        });

    } catch (error) {
        console.error(
            'Create excise license holder error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to create excise license holder'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE LICENSE HOLDER
//
// PUT /excise/license-holders/:holderId
// ============================================================

exports.updateLicenseHolder = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const holderId = Number(req.params.holderId);

        const {
            outletId,
            customerId = null,
            licenseNo,
            licenseType = null,
            holderName,

            address1 = null,
            address2 = null,
            city = null,
            state = null,
            pincode = null,

            phone = null,
            email = null,

            validFrom = null,
            validTo = null,

            status = 'ACTIVE',
            remarks = null
        } = req.body;

        const parsedOutletId = Number(outletId);

        if (!Number.isInteger(holderId) || holderId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid license holder id'
            });
        }

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
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

        const cleanLicenseNo =
            String(licenseNo || '').trim();

        const cleanHolderName =
            String(holderName || '').trim();

        if (!cleanLicenseNo) {
            return res.status(400).json({
                success: false,
                message: 'licenseNo is required'
            });
        }

        if (!cleanHolderName) {
            return res.status(400).json({
                success: false,
                message: 'holderName is required'
            });
        }

        const validStatuses = [
            'ACTIVE',
            'EXPIRED',
            'SUSPENDED',
            'CANCELLED'
        ];

        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status'
            });
        }

        if (
            validFrom &&
            validTo &&
            String(validFrom) > String(validTo)
        ) {
            return res.status(400).json({
                success: false,
                message: 'validFrom cannot be after validTo'
            });
        }

        const parsedCustomerId =
            customerId === null ||
            customerId === undefined ||
            customerId === ''
                ? null
                : Number(customerId);

        if (
            parsedCustomerId !== null &&
            (!Number.isInteger(parsedCustomerId) ||
                parsedCustomerId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid customerId'
            });
        }

        // ------------------------------------------------------
        // Verify record exists for authorized outlet
        // ------------------------------------------------------

        const [holders] = await connection.query(
            `
            SELECT id
            FROM excise_license_holder
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                holderId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        if (holders.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Excise license holder not found'
            });
        }

        // ------------------------------------------------------
        // Duplicate license check
        // ------------------------------------------------------

        const [existing] = await connection.query(
            `
            SELECT id
            FROM excise_license_holder
            WHERE company_id = ?
              AND outlet_id = ?
              AND license_no = ?
              AND id <> ?
            LIMIT 1
            `,
            [
                req.user.companyId,
                parsedOutletId,
                cleanLicenseNo,
                holderId
            ]
        );

        if (existing.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'This license number already exists for the outlet'
            });
        }

        await connection.query(
            `
            UPDATE excise_license_holder
            SET
                customer_id = ?,
                license_no = ?,
                license_type = ?,
                holder_name = ?,
                address1 = ?,
                address2 = ?,
                city = ?,
                state = ?,
                pincode = ?,
                phone = ?,
                email = ?,
                valid_from = ?,
                valid_to = ?,
                status = ?,
                remarks = ?,
                updated_by = ?
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            `,
            [
                parsedCustomerId,
                cleanLicenseNo,
                licenseType
                    ? String(licenseType).trim()
                    : null,
                cleanHolderName,

                address1,
                address2,
                city,
                state,
                pincode,

                phone,
                email,

                validFrom || null,
                validTo || null,

                status,
                remarks,

                req.user.userId,

                holderId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        return res.json({
            success: true,
            message: 'Excise license holder updated successfully'
        });

    } catch (error) {
        console.error(
            'Update excise license holder error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to update excise license holder'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// GET EXCISE ITEMS
//
// GET /excise/items?outletId=1
//
// Optional:
//     active=true|false
//     category=IMFL|BEER|WINE|COUNTRY_LIQUOR|IMPORTED_LIQUOR|OTHER
// ============================================================

exports.getExciseItems = async (req, res) => {
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

        const params = [
            req.user.companyId,
            outletId
        ];

        let conditions = `
            ei.company_id = ?
            AND ei.outlet_id = ?
        `;

        // ------------------------------------------------------
        // Active filter
        // ------------------------------------------------------

        if (
            req.query.active !== undefined &&
            req.query.active !== null &&
            req.query.active !== ''
        ) {
            const active =
                String(req.query.active).toLowerCase() === 'true';

            conditions += `
                AND ei.active = ?
            `;

            params.push(active ? 1 : 0);
        }

        // ------------------------------------------------------
        // Category filter
        // ------------------------------------------------------

        if (
            req.query.category !== undefined &&
            req.query.category !== null &&
            String(req.query.category).trim() !== ''
        ) {
            conditions += `
                AND ei.liquor_category = ?
            `;

            params.push(
                String(req.query.category).trim().toUpperCase()
            );
        }

        const [rows] = await connection.query(
            `
            SELECT
                ei.id,
                ei.company_id,
                ei.outlet_id,

                ei.raw_material_id,
                ei.menu_item_id,
                ei.menu_item_variant_id,

                ei.item_name,
                ei.brand_name,
                ei.liquor_category,

                ei.pack_size_ml,
                ei.excise_unit_factor,
                ei.excise_code,

                ei.active,

                ei.created_at,
                ei.updated_at

            FROM excise_item ei

            WHERE ${conditions}

            ORDER BY
                ei.liquor_category,
                ei.brand_name,
                ei.item_name,
                ei.pack_size_ml
            `,
            params
        );

        return res.json({
            success: true,
            items: rows.map(row => ({
                id: row.id,

                companyId: row.company_id,
                outletId: row.outlet_id,

                rawMaterialId:
                    row.raw_material_id === null
                        ? null
                        : Number(row.raw_material_id),

                menuItemId:
                    row.menu_item_id === null
                        ? null
                        : Number(row.menu_item_id),

                menuItemVariantId:
                    row.menu_item_variant_id === null
                        ? null
                        : Number(row.menu_item_variant_id),

                itemName: row.item_name,
                brandName: row.brand_name,
                liquorCategory: row.liquor_category,

                packSizeMl:
                    Number(row.pack_size_ml || 0),

                exciseUnitsPerPack:
                    Number(row.excise_unit_factor || 0),

                exciseCode: row.excise_code,

                active: Boolean(row.active),

                createdAt: row.created_at,
                updatedAt: row.updated_at
            }))
        });

    } catch (error) {
        console.error(
            'Get excise items error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get excise items'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// GET SINGLE EXCISE ITEM
//
// GET /excise/items/:itemId?outletId=1
// ============================================================

exports.getExciseItem = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);
        const itemId = Number(req.params.itemId);

        if (!Number.isInteger(outletId) || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
            });
        }

        if (!Number.isInteger(itemId) || itemId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid excise item id'
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

        const [rows] = await connection.query(
            `
            SELECT
                id,
                company_id,
                outlet_id,

                raw_material_id,
                menu_item_id,
                menu_item_variant_id,

                item_name,
                brand_name,
                liquor_category,

                pack_size_ml,
                excise_unit_factor,
                excise_code,

                active
            FROM excise_item

            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?

            LIMIT 1
            `,
            [
                itemId,
                req.user.companyId,
                outletId
            ]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Excise item not found'
            });
        }

        const row = rows[0];

        return res.json({
            success: true,

            item: {
                id: row.id,

                companyId: row.company_id,
                outletId: row.outlet_id,

                rawMaterialId:
                    row.raw_material_id === null
                        ? null
                        : Number(row.raw_material_id),

                menuItemId:
                    row.menu_item_id === null
                        ? null
                        : Number(row.menu_item_id),

                menuItemVariantId:
                    row.menu_item_variant_id === null
                        ? null
                        : Number(row.menu_item_variant_id),

                itemName: row.item_name,
                brandName: row.brand_name,
                liquorCategory: row.liquor_category,

                packSizeMl:
                    Number(row.pack_size_ml || 0),

                exciseUnitsPerPack:
                    Number(row.excise_unit_factor || 0),

                exciseCode: row.excise_code,

                active: Boolean(row.active)
            }
        });

    } catch (error) {
        console.error(
            'Get excise item error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get excise item'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// CREATE EXCISE ITEM
//
// POST /excise/items
// ============================================================

exports.createExciseItem = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            outletId,

            rawMaterialId = null,
            menuItemId = null,
            menuItemVariantId = null,

            itemName,
            brandName = null,

            liquorCategory = 'IMFL',

            packSizeMl,
            exciseUnitsPerPack,

            exciseCode = null,

            active = true
        } = req.body;

        const parsedOutletId = Number(outletId);

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
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

        const cleanItemName =
            String(itemName || '').trim();

        const cleanBrandName =
            String(brandName || '').trim() || null;

        const cleanExciseCode =
            String(exciseCode || '').trim() || null;

        const category =
            String(liquorCategory || 'IMFL')
                .trim()
                .toUpperCase();

        const validCategories = [
            'IMFL',
            'BEER',
            'WINE',
            'COUNTRY_LIQUOR',
            'IMPORTED_LIQUOR',
            'OTHER'
        ];

        if (!cleanItemName) {
            return res.status(400).json({
                success: false,
                message: 'itemName is required'
            });
        }

        if (!validCategories.includes(category)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid liquorCategory'
            });
        }

        const parsedPackSizeMl = Number(packSizeMl);
        const parsedUnitsPerPack = Number(exciseUnitsPerPack);

        if (
            !Number.isFinite(parsedPackSizeMl) ||
            parsedPackSizeMl <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'packSizeMl must be greater than 0'
            });
        }

        if (
            !Number.isFinite(parsedUnitsPerPack) ||
            parsedUnitsPerPack <= 0
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'exciseUnitsPerPack must be greater than 0'
            });
        }

        const parsedRawMaterialId =
            rawMaterialId === null ||
            rawMaterialId === undefined ||
            rawMaterialId === ''
                ? null
                : Number(rawMaterialId);

        const parsedMenuItemId =
            menuItemId === null ||
            menuItemId === undefined ||
            menuItemId === ''
                ? null
                : Number(menuItemId);

        const parsedMenuItemVariantId =
            menuItemVariantId === null ||
            menuItemVariantId === undefined ||
            menuItemVariantId === ''
                ? null
                : Number(menuItemVariantId);

        if (
            parsedRawMaterialId === null &&
            parsedMenuItemId === null &&
            parsedMenuItemVariantId === null
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'At least one of rawMaterialId, menuItemId or menuItemVariantId is required'
            });
        }

        if (
            parsedRawMaterialId !== null &&
            (!Number.isInteger(parsedRawMaterialId) ||
                parsedRawMaterialId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid rawMaterialId'
            });
        }

        if (
            parsedMenuItemId !== null &&
            (!Number.isInteger(parsedMenuItemId) ||
                parsedMenuItemId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid menuItemId'
            });
        }

        if (
            parsedMenuItemVariantId !== null &&
            (!Number.isInteger(parsedMenuItemVariantId) ||
                parsedMenuItemVariantId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid menuItemVariantId'
            });
        }

        const parsedActive =
            active === true ||
            active === 1 ||
            String(active).toLowerCase() === 'true';

        // ------------------------------------------------------
        // Prevent duplicate pack mapping
        // ------------------------------------------------------

        const [existing] = await connection.query(
            `
            SELECT id
            FROM excise_item
            WHERE company_id = ?
              AND outlet_id = ?
              AND COALESCE(raw_material_id, 0) =
                  COALESCE(?, 0)
              AND COALESCE(menu_item_variant_id, 0) =
                  COALESCE(?, 0)
              AND pack_size_ml = ?
            LIMIT 1
            `,
            [
                req.user.companyId,
                parsedOutletId,
                parsedRawMaterialId,
                parsedMenuItemVariantId,
                parsedPackSizeMl
            ]
        );

        if (existing.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'This Excise item/pack mapping already exists'
            });
        }

        const [result] = await connection.query(
            `
            INSERT INTO excise_item
            (
                company_id,
                outlet_id,

                raw_material_id,
                menu_item_id,
                menu_item_variant_id,

                item_name,
                brand_name,
                liquor_category,

                pack_size_ml,
                excise_unit_factor,

                excise_code,
                active,

                created_by,
                updated_by
            )
            VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `,
            [
                req.user.companyId,
                parsedOutletId,

                parsedRawMaterialId,
                parsedMenuItemId,
                parsedMenuItemVariantId,

                cleanItemName,
                cleanBrandName,
                category,

                parsedPackSizeMl,
                parsedUnitsPerPack,

                cleanExciseCode,
                parsedActive ? 1 : 0,

                req.user.userId,
                req.user.userId
            ]
        );

        return res.status(201).json({
            success: true,
            message: 'Excise item created successfully',
            id: result.insertId
        });

    } catch (error) {
        console.error(
            'Create excise item error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to create excise item'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE EXCISE ITEM
//
// PUT /excise/items/:itemId
// ============================================================

exports.updateExciseItem = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const itemId = Number(req.params.itemId);

        const {
            outletId,

            rawMaterialId = null,
            menuItemId = null,
            menuItemVariantId = null,

            itemName,
            brandName = null,

            liquorCategory = 'IMFL',

            packSizeMl,
            exciseUnitsPerPack,

            exciseCode = null,

            active = true
        } = req.body;

        const parsedOutletId = Number(outletId);

        if (!Number.isInteger(itemId) || itemId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid excise item id'
            });
        }

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid outletId is required'
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

        const cleanItemName =
            String(itemName || '').trim();

        const cleanBrandName =
            String(brandName || '').trim() || null;

        const cleanExciseCode =
            String(exciseCode || '').trim() || null;

        const category =
            String(liquorCategory || 'IMFL')
                .trim()
                .toUpperCase();

        const validCategories = [
            'IMFL',
            'BEER',
            'WINE',
            'COUNTRY_LIQUOR',
            'IMPORTED_LIQUOR',
            'OTHER'
        ];

        if (!cleanItemName) {
            return res.status(400).json({
                success: false,
                message: 'itemName is required'
            });
        }

        if (!validCategories.includes(category)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid liquorCategory'
            });
        }

        const parsedPackSizeMl = Number(packSizeMl);
        const parsedUnitsPerPack = Number(exciseUnitsPerPack);

        if (
            !Number.isFinite(parsedPackSizeMl) ||
            parsedPackSizeMl <= 0
        ) {
            return res.status(400).json({
                success: false,
                message: 'packSizeMl must be greater than 0'
            });
        }

        if (
            !Number.isFinite(parsedUnitsPerPack) ||
            parsedUnitsPerPack <= 0
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'exciseUnitsPerPack must be greater than 0'
            });
        }

        const parsedRawMaterialId =
            rawMaterialId === null ||
            rawMaterialId === undefined ||
            rawMaterialId === ''
                ? null
                : Number(rawMaterialId);

        const parsedMenuItemId =
            menuItemId === null ||
            menuItemId === undefined ||
            menuItemId === ''
                ? null
                : Number(menuItemId);

        const parsedMenuItemVariantId =
            menuItemVariantId === null ||
            menuItemVariantId === undefined ||
            menuItemVariantId === ''
                ? null
                : Number(menuItemVariantId);

        if (
            parsedRawMaterialId === null &&
            parsedMenuItemId === null &&
            parsedMenuItemVariantId === null
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'At least one of rawMaterialId, menuItemId or menuItemVariantId is required'
            });
        }

        const parsedActive =
            active === true ||
            active === 1 ||
            String(active).toLowerCase() === 'true';

        // ------------------------------------------------------
        // Verify existing item
        // ------------------------------------------------------

        const [items] = await connection.query(
            `
            SELECT id
            FROM excise_item
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                itemId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        if (items.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Excise item not found'
            });
        }

        // ------------------------------------------------------
        // Duplicate check
        // ------------------------------------------------------

        const [existing] = await connection.query(
            `
            SELECT id
            FROM excise_item
            WHERE company_id = ?
              AND outlet_id = ?
              AND COALESCE(raw_material_id, 0) =
                  COALESCE(?, 0)
              AND COALESCE(menu_item_variant_id, 0) =
                  COALESCE(?, 0)
              AND pack_size_ml = ?
              AND id <> ?
            LIMIT 1
            `,
            [
                req.user.companyId,
                parsedOutletId,
                parsedRawMaterialId,
                parsedMenuItemVariantId,
                parsedPackSizeMl,
                itemId
            ]
        );

        if (existing.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'This Excise item/pack mapping already exists'
            });
        }

        await connection.query(
            `
            UPDATE excise_item
            SET
                raw_material_id = ?,
                menu_item_id = ?,
                menu_item_variant_id = ?,

                item_name = ?,
                brand_name = ?,
                liquor_category = ?,

                pack_size_ml = ?,
                excise_unit_factor = ?,

                excise_code = ?,
                active = ?,

                updated_by = ?

            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            `,
            [
                parsedRawMaterialId,
                parsedMenuItemId,
                parsedMenuItemVariantId,

                cleanItemName,
                cleanBrandName,
                category,

                parsedPackSizeMl,
                parsedUnitsPerPack,

                cleanExciseCode,
                parsedActive ? 1 : 0,

                req.user.userId,

                itemId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        return res.json({
            success: true,
            message: 'Excise item updated successfully'
        });

    } catch (error) {
        console.error(
            'Update excise item error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to update excise item'
        });

    } finally {
        connection.release();
    }
};



/*
============================================================
EXCISE POS ITEM MAPPING

GET    /excise/item-pos-mappings?outletId=1
POST   /excise/item-pos-mappings
PUT    /excise/item-pos-mappings/:mappingId

Maps POS item/variant to an Excise item and its volume.
============================================================
*/


// ============================================================
// GET POS-TO-EXCISE MAPPINGS
// ============================================================

exports.getItemPosMappings = async (req, res) => {
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

        const params = [
            req.user.companyId,
            outletId
        ];

        let activeCondition = '';

        if (
            req.query.active !== undefined &&
            req.query.active !== ''
        ) {
            const active =
                String(req.query.active).toLowerCase() === 'true';

            activeCondition = ' AND m.active = ? ';
            params.push(active ? 1 : 0);
        }

        const [rows] = await connection.query(
            `
            SELECT
                m.id AS mapping_id,
                m.company_id,
                m.outlet_id,
                m.excise_item_id,

                m.menu_item_id,
                m.menu_item_variant_id,
                m.pos_unit_size_ml,
                m.active,

                ei.item_name AS excise_item_name,
                ei.brand_name,
                ei.liquor_category,
                ei.pack_size_ml,

                mi.item_code,
                mi.item_name AS pos_item_name,

                v.variant_code,
                v.variant_name

            FROM excise_item_pos_mapping m

            INNER JOIN excise_item ei
                ON ei.id = m.excise_item_id
               AND ei.company_id = m.company_id
               AND ei.outlet_id = m.outlet_id

            INNER JOIN menu_item mi
                ON mi.menu_item_id = m.menu_item_id
               AND mi.outlet_id = m.outlet_id

            LEFT JOIN menu_item_variant v
                ON v.variant_id = m.menu_item_variant_id
               AND v.menu_item_id = m.menu_item_id

            WHERE m.company_id = ?
              AND m.outlet_id = ?
              ${activeCondition}

            ORDER BY
                ei.liquor_category,
                ei.item_name,
                mi.item_name,
                v.variant_name
            `,
            params
        );

        return res.json({
            success: true,
            mappings: rows.map(row => ({
                mappingId: Number(row.mapping_id),
                companyId: Number(row.company_id),
                outletId: Number(row.outlet_id),

                exciseItemId: Number(row.excise_item_id),
                exciseItemName: row.excise_item_name,
                brandName: row.brand_name,
                liquorCategory: row.liquor_category,
                packSizeMl: Number(row.pack_size_ml || 0),

                menuItemId: Number(row.menu_item_id),
                posItemCode: row.item_code,
                posItemName: row.pos_item_name,

                menuItemVariantId:
                    row.menu_item_variant_id === null
                        ? null
                        : Number(row.menu_item_variant_id),

                variantCode: row.variant_code,
                variantName: row.variant_name,

                posUnitSizeMl:
                    Number(row.pos_unit_size_ml || 0),

                active: Boolean(row.active)
            }))
        });

    } catch (error) {
        console.error('Get Excise POS mappings error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get Excise POS mappings'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// CREATE POS-TO-EXCISE MAPPING
// ============================================================

exports.createItemPosMapping = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const {
            outletId,
            exciseItemId,
            menuItemId,
            menuItemVariantId = null,
            posUnitSizeMl,
            active = true
        } = req.body;

        const parsedOutletId = Number(outletId);
        const parsedExciseItemId = Number(exciseItemId);
        const parsedMenuItemId = Number(menuItemId);

        const parsedVariantId =
            menuItemVariantId === null ||
            menuItemVariantId === ''
                ? null
                : Number(menuItemVariantId);

        const parsedVolume = Number(posUnitSizeMl);

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0 ||
            !Number.isInteger(parsedExciseItemId) ||
            parsedExciseItemId <= 0 ||
            !Number.isInteger(parsedMenuItemId) ||
            parsedMenuItemId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'Valid outletId, exciseItemId and menuItemId are required'
            });
        }

        if (
            parsedVariantId !== null &&
            (!Number.isInteger(parsedVariantId) ||
                parsedVariantId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid menuItemVariantId'
            });
        }

        if (!Number.isFinite(parsedVolume) || parsedVolume <= 0) {
            return res.status(400).json({
                success: false,
                message: 'posUnitSizeMl must be greater than zero'
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

        // Verify Excise item belongs to this company and outlet.
        const [exciseItems] = await connection.query(
            `
            SELECT id
            FROM excise_item
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
              AND active = 1
            LIMIT 1
            `,
            [
                parsedExciseItemId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        if (exciseItems.length === 0) {
            return res.status(400).json({
                success: false,
                message:
                    'Active Excise item not found for this outlet'
            });
        }

        // Verify POS item belongs to this outlet.
        const [menuItems] = await connection.query(
            `
            SELECT menu_item_id
            FROM menu_item
            WHERE menu_item_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                parsedMenuItemId,
                parsedOutletId
            ]
        );

        if (menuItems.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'POS menu item not found for this outlet'
            });
        }

        // If a variant is supplied, it must belong to this item.
        if (parsedVariantId !== null) {
            const [variants] = await connection.query(
                `
                SELECT variant_id
                FROM menu_item_variant
                WHERE variant_id = ?
                  AND menu_item_id = ?
                LIMIT 1
                `,
                [
                    parsedVariantId,
                    parsedMenuItemId
                ]
            );

            if (variants.length === 0) {
                return res.status(400).json({
                    success: false,
                    message:
                        'POS variant does not belong to the selected menu item'
                });
            }
        }

        // Explicit duplicate check also handles NULL variants.
        const [existing] = await connection.query(
            `
            SELECT id
            FROM excise_item_pos_mapping
            WHERE outlet_id = ?
              AND menu_item_id = ?
              AND menu_item_variant_id <=> ?
            LIMIT 1
            `,
            [
                parsedOutletId,
                parsedMenuItemId,
                parsedVariantId
            ]
        );

        if (existing.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'This POS item/variant already has a mapping'
            });
        }

        const parsedActive =
            active === true ||
            active === 1 ||
            String(active).toLowerCase() === 'true';

        const [result] = await connection.query(
            `
            INSERT INTO excise_item_pos_mapping
            (
                company_id,
                outlet_id,
                excise_item_id,
                menu_item_id,
                menu_item_variant_id,
                pos_unit_size_ml,
                active,
                created_by,
                updated_by
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            `,
            [
                req.user.companyId,
                parsedOutletId,
                parsedExciseItemId,
                parsedMenuItemId,
                parsedVariantId,
                parsedVolume,
                parsedActive ? 1 : 0,
                req.user.userId,
                req.user.userId
            ]
        );

        return res.status(201).json({
            success: true,
            message: 'POS-to-Excise mapping created successfully',
            mappingId: result.insertId
        });

    } catch (error) {
        console.error('Create Excise POS mapping error:', error);

        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message:
                    'This POS item/variant already has a mapping'
            });
        }

        return res.status(500).json({
            success: false,
            message: 'Unable to create POS-to-Excise mapping'
        });

    } finally {
        connection.release();
    }
};


// ============================================================
// UPDATE POS-TO-EXCISE MAPPING
// ============================================================

exports.updateItemPosMapping = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const mappingId = Number(req.params.mappingId);

        const {
            outletId,
            exciseItemId,
            menuItemId,
            menuItemVariantId = null,
            posUnitSizeMl,
            active = true
        } = req.body;

        const parsedOutletId = Number(outletId);
        const parsedExciseItemId = Number(exciseItemId);
        const parsedMenuItemId = Number(menuItemId);

        const parsedVariantId =
            menuItemVariantId === null ||
            menuItemVariantId === ''
                ? null
                : Number(menuItemVariantId);

        const parsedVolume = Number(posUnitSizeMl);

        if (!Number.isInteger(mappingId) || mappingId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid mappingId'
            });
        }

        if (
            !Number.isInteger(parsedOutletId) ||
            parsedOutletId <= 0 ||
            !Number.isInteger(parsedExciseItemId) ||
            parsedExciseItemId <= 0 ||
            !Number.isInteger(parsedMenuItemId) ||
            parsedMenuItemId <= 0
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'Valid outletId, exciseItemId and menuItemId are required'
            });
        }

        if (
            parsedVariantId !== null &&
            (!Number.isInteger(parsedVariantId) ||
                parsedVariantId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid menuItemVariantId'
            });
        }

        if (!Number.isFinite(parsedVolume) || parsedVolume <= 0) {
            return res.status(400).json({
                success: false,
                message: 'posUnitSizeMl must be greater than zero'
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

        const [existingMapping] = await connection.query(
            `
            SELECT id
            FROM excise_item_pos_mapping
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                mappingId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        if (existingMapping.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'POS-to-Excise mapping not found'
            });
        }

        const [exciseItems] = await connection.query(
            `
            SELECT id
            FROM excise_item
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
              AND active = 1
            LIMIT 1
            `,
            [
                parsedExciseItemId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        if (exciseItems.length === 0) {
            return res.status(400).json({
                success: false,
                message:
                    'Active Excise item not found for this outlet'
            });
        }

        const [menuItems] = await connection.query(
            `
            SELECT menu_item_id
            FROM menu_item
            WHERE menu_item_id = ?
              AND outlet_id = ?
            LIMIT 1
            `,
            [
                parsedMenuItemId,
                parsedOutletId
            ]
        );

        if (menuItems.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'POS menu item not found for this outlet'
            });
        }

        if (parsedVariantId !== null) {
            const [variants] = await connection.query(
                `
                SELECT variant_id
                FROM menu_item_variant
                WHERE variant_id = ?
                  AND menu_item_id = ?
                LIMIT 1
                `,
                [
                    parsedVariantId,
                    parsedMenuItemId
                ]
            );

            if (variants.length === 0) {
                return res.status(400).json({
                    success: false,
                    message:
                        'POS variant does not belong to the selected menu item'
                });
            }
        }

        const [duplicates] = await connection.query(
            `
            SELECT id
            FROM excise_item_pos_mapping
            WHERE outlet_id = ?
              AND menu_item_id = ?
              AND menu_item_variant_id <=> ?
              AND id <> ?
            LIMIT 1
            `,
            [
                parsedOutletId,
                parsedMenuItemId,
                parsedVariantId,
                mappingId
            ]
        );

        if (duplicates.length > 0) {
            return res.status(409).json({
                success: false,
                message:
                    'Another mapping already exists for this POS item/variant'
            });
        }

        const parsedActive =
            active === true ||
            active === 1 ||
            String(active).toLowerCase() === 'true';

        await connection.query(
            `
            UPDATE excise_item_pos_mapping
            SET
                excise_item_id = ?,
                menu_item_id = ?,
                menu_item_variant_id = ?,
                pos_unit_size_ml = ?,
                active = ?,
                updated_by = ?
            WHERE id = ?
              AND company_id = ?
              AND outlet_id = ?
            `,
            [
                parsedExciseItemId,
                parsedMenuItemId,
                parsedVariantId,
                parsedVolume,
                parsedActive ? 1 : 0,
                req.user.userId,
                mappingId,
                req.user.companyId,
                parsedOutletId
            ]
        );

        return res.json({
            success: true,
            message: 'POS-to-Excise mapping updated successfully'
        });

    } catch (error) {
        console.error('Update Excise POS mapping error:', error);

        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({
                success: false,
                message:
                    'Another mapping already exists for this POS item/variant'
            });
        }

        return res.status(500).json({
            success: false,
            message: 'Unable to update POS-to-Excise mapping'
        });

    } finally {
        connection.release();
    }
};