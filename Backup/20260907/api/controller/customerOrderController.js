const crypto = require('crypto');
9

const pool =  require('../database');

function generateSessionToken() {
    return crypto.randomBytes(32).toString('hex');
}


 exports.createTableSession = async (req, res) => {
    const connection = await pool.getConnection();

    try {
        const outletId = Number(req.body.outlet_id);
        const tableId = Number(req.body.table_id);

        if (!outletId || !tableId) {
            return res.status(400).json({
                success: false,
                message: 'outlet_id and table_id are required'
            });
        }

        await connection.beginTransaction();

        /*
         * Verify that the table belongs to the outlet.
         */
        const [tables] = await connection.query(
            `
            SELECT
                table_id,
                outlet_id,
                table_code,
                table_name,
                status,
                is_active
            FROM restaurant_table
            WHERE table_id = ?
              AND outlet_id = ?
              AND is_active = 1
            FOR UPDATE
            `,
            [tableId, outletId]
        );

        if (tables.length === 0) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Restaurant table not found'
            });
        }

        /*
         * Check whether an active session already exists.
         *
         * Multiple customers scanning the same table QR
         * should use the same table session.
         */
        const [existing] = await connection.query(
            `
            SELECT *
            FROM table_order_session
            WHERE outlet_id = ?
              AND table_id = ?
              AND status = 'ACTIVE'
            ORDER BY session_id DESC
            LIMIT 1
            FOR UPDATE
            `,
            [outletId, tableId]
        );

        if (existing.length > 0) {
            await connection.commit();

            return res.json({
                success: true,
                existing: true,
                session: existing[0],
                table: tables[0]
            });
        }

       const sessionUuid = crypto.randomUUID();
        const sessionToken = generateSessionToken();

        const [result] = await connection.query(
            `
            INSERT INTO table_order_session (
                session_uuid,
                outlet_id,
                table_id,
                session_token,
                status
            )
            VALUES (?, ?, ?, ?, 'ACTIVE')
            `,
            [
                sessionUuid,
                outletId,
                tableId,
                sessionToken
            ]
        );

        await connection.commit();

        res.status(201).json({
            success: true,
            existing: false,
            session: {
                session_id: result.insertId,
                session_uuid: sessionUuid,
                outlet_id: outletId,
                table_id: tableId,
                session_token: sessionToken,
                status: 'ACTIVE'
            },
            table: tables[0]
        });

    } catch (error) {
        await connection.rollback();

        console.error(
            'createTableSession error:',
            error
        );

        res.status(500).json({
            success: false,
            message: 'Unable to create table session'
        });

    } finally {
        connection.release();
    }
};

exports.getTableByToken = async (req, res) => {
     const connection = await pool.getConnection();
    const token = req.params.token;

    if (!token) {
        return res.status(400).json({
            success: false,
            message: 'Invalid table token'
        });
    }

    try {
        const [rows] = await connection.query(
            `
            SELECT
                s.session_id,
                s.session_uuid,
                s.session_token,
                s.status AS session_status,

                s.outlet_id,
                s.table_id,

                t.table_code,
                t.table_name,
                t.capacity,

                o.outlet_name

            FROM table_order_session s

            INNER JOIN restaurant_table t
                ON t.table_id = s.table_id

            INNER JOIN outlet o
                ON o.outlet_id = s.outlet_id

            WHERE s.session_token = ?
              AND s.status = 'ACTIVE'
              AND t.is_active = 1

            LIMIT 1
            `,
            [token]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Invalid or expired table QR'
            });
        }

        const row = rows[0];

        res.json({
            success: true,

            outlet: {
                outlet_id: row.outlet_id,
                outlet_name: row.outlet_name
            },

            table: {
                table_id: row.table_id,
                table_code: row.table_code,
                table_name: row.table_name,
                capacity: row.capacity
            },

            session: {
                session_id: row.session_id,
                session_uuid: row.session_uuid,
                session_token: row.session_token,
                status: row.session_status
            }
        });

    } catch (error) {
        console.error(
            'getTableByToken error:',
            error
        );

        res.status(500).json({
            success: false,
            message: 'Unable to load table'
        });
    }
};

exports.createCustomerSession = async (req, res) => {
    const connection = await pool.getConnection();

    try {
        const tableSessionToken =
            req.body.table_session_token;

        const customerName =
            req.body.customer_name || null;

        const customerPhone =
            req.body.customer_phone || null;

        if (!tableSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'table_session_token is required'
            });
        }

        await connection.beginTransaction();

        // Find active table session
        const [sessions] = await connection.query(
            `
            SELECT
                session_id,
                session_uuid,
                outlet_id,
                table_id,
                session_token,
                status
            FROM table_order_session
            WHERE session_token = ?
              AND status = 'ACTIVE'
            LIMIT 1
            FOR UPDATE
            `,
            [tableSessionToken]
        );

        if (sessions.length === 0) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Invalid or expired table session'
            });
        }

        const tableSession = sessions[0];

        const sessionUuid = crypto.randomUUID();
        const sessionToken = generateSessionToken();

        const [result] = await connection.query(
            `
            INSERT INTO customer_order_session (
                session_uuid,
                table_session_id,
                customer_name,
                customer_phone,
                session_token,
                status
            )
            VALUES (?, ?, ?, ?, ?, 'ACTIVE')
            `,
            [
                sessionUuid,
                tableSession.session_id,
                customerName,
                customerPhone,
                sessionToken
            ]
        );

        await connection.commit();

        res.status(201).json({
            success: true,

            customer_session: {
                customer_session_id: result.insertId,
                session_uuid: sessionUuid,
                table_session_id:
                    tableSession.session_id,
                session_token: sessionToken,
                customer_name: customerName,
                customer_phone: customerPhone,
                status: 'ACTIVE'
            },

            table: {
                outlet_id: tableSession.outlet_id,
                table_id: tableSession.table_id
            }
        });

    } catch (error) {
        await connection.rollback();

        console.error(
            'createCustomerSession error:',
            error
        );

        res.status(500).json({
            success: false,
            message: 'Unable to create customer session'
        });

    } finally {
        connection.release();
    }
};


exports.getCustomerMenu = async (req, res) => {
    const db = await pool.getConnection();

    try {
        const customerSessionToken = req.params.token;

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'Customer session token is required'
            });
        }

        // --------------------------------------------------
        // 1. Validate customer session
        // --------------------------------------------------

        const [sessions] = await db.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,
                cs.customer_name,
                cs.customer_phone,
                cs.status AS customer_session_status,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status

            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id

            WHERE cs.session_token = ?
              AND cs.status = 'ACTIVE'
              AND ts.status = 'ACTIVE'

            LIMIT 1
            `,
            [customerSessionToken]
        );

        if (sessions.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Customer session is invalid or expired'
            });
        }

        const session = sessions[0];

        const outletId = session.outlet_id;
        const tableId = session.table_id;

        // --------------------------------------------------
        // 2. Get table information
        // --------------------------------------------------

        const [tables] = await db.query(
            `
            SELECT
                table_id,
                table_code,
                table_name,
                capacity
            FROM restaurant_table
            WHERE table_id = ?
              AND outlet_id = ?
              AND is_active = TRUE
            LIMIT 1
            `,
            [tableId, outletId]
        );

        if (tables.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Restaurant table not found'
            });
        }

        // --------------------------------------------------
        // 3. Get categories
        // --------------------------------------------------

        const [categories] = await db.query(
            `
            SELECT
                menu_category_id,
                category_code,
                category_name,
                parent_category_id,
                display_order

            FROM menu_category

            WHERE outlet_id = ?
              AND is_active = TRUE

            ORDER BY
                display_order,
                category_name
            `,
            [outletId]
        );

        // --------------------------------------------------
        // 4. Get available menu items
        // --------------------------------------------------

        const [items] = await db.query(
            `
            SELECT
                mi.menu_item_id,
                mi.menu_item_uuid,
                mi.menu_category_id,

                mi.item_code,
                mi.item_name,
                mi.description,
                mi.item_type,
                mi.base_rate,

                mi.is_veg,
                mi.is_egg,
                mi.is_spicy,

                mi.image_url

            FROM menu_item mi

            INNER JOIN menu_category mc
                ON mc.menu_category_id =
                   mi.menu_category_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE
              AND mi.is_available = TRUE
              AND mc.is_active = TRUE

            ORDER BY
                mc.display_order,
                mc.category_name,
                mi.item_name
            `,
            [outletId]
        );

        // --------------------------------------------------
        // 5. Get variants
        // --------------------------------------------------

        const [variants] = await db.query(
            `
            SELECT
                v.variant_id,
                v.variant_uuid,
                v.menu_item_id,
                v.variant_code,
                v.variant_name,
                v.rate,
                v.display_order,
                v.is_default

            FROM menu_item_variant v

            INNER JOIN menu_item mi
                ON mi.menu_item_id = v.menu_item_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE
              AND mi.is_available = TRUE
              AND v.is_active = TRUE

            ORDER BY
                v.display_order,
                v.variant_name
            `,
            [outletId]
        );

        // --------------------------------------------------
        // 6. Get modifier groups
        // --------------------------------------------------

        const [modifierGroups] = await db.query(
            `
            SELECT
                mim.menu_item_id,

                mg.modifier_group_id,
                mg.group_name,
                mg.selection_type,
                mg.min_selection,
                mg.max_selection,
                mg.display_order

            FROM menu_item_modifier mim

            INNER JOIN menu_item mi
                ON mi.menu_item_id =
                   mim.menu_item_id

            INNER JOIN modifier_group mg
                ON mg.modifier_group_id =
                   mim.modifier_group_id

            WHERE mi.outlet_id = ?
              AND mi.is_active = TRUE
              AND mi.is_available = TRUE
              AND mg.is_active = TRUE

            ORDER BY
                mg.display_order,
                mg.group_name
            `,
            [outletId]
        );

        // --------------------------------------------------
        // 7. Get modifier options
        // --------------------------------------------------

        const [modifierOptions] = await db.query(
            `
            SELECT
                mo.modifier_option_id,
                mo.modifier_group_id,
                mo.option_name,
                mo.extra_rate,
                mo.display_order

            FROM modifier_option mo

            INNER JOIN modifier_group mg
                ON mg.modifier_group_id =
                   mo.modifier_group_id

            WHERE mg.is_active = TRUE
              AND mo.is_active = TRUE

            ORDER BY
                mo.display_order,
                mo.option_name
            `
        );

        // --------------------------------------------------
        // 8. Build item structure
        // --------------------------------------------------

        const menu = categories.map(category => {

            const categoryItems = items
                .filter(
                    item =>
                        item.menu_category_id ===
                        category.menu_category_id
                )
                .map(item => {

                    const itemVariants = variants
                        .filter(
                            variant =>
                                variant.menu_item_id ===
                                item.menu_item_id
                        )
                        .map(variant => ({
                            variant_id: variant.variant_id,
                            variant_code: variant.variant_code,
                            variant_name: variant.variant_name,
                            rate: variant.rate,
                            is_default: variant.is_default
                        }));

                    const itemModifierGroups =
                        modifierGroups
                            .filter(
                                group =>
                                    group.menu_item_id ===
                                    item.menu_item_id
                            )
                            .map(group => {

                                const options =
                                    modifierOptions
                                        .filter(
                                            option =>
                                                option.modifier_group_id ===
                                                group.modifier_group_id
                                        )
                                        .map(option => ({
                                            modifier_option_id:
                                                option.modifier_option_id,

                                            option_name:
                                                option.option_name,

                                            extra_rate:
                                                option.extra_rate
                                        }));

                                return {
                                    modifier_group_id:
                                        group.modifier_group_id,

                                    group_name:
                                        group.group_name,

                                    selection_type:
                                        group.selection_type,

                                    min_selection:
                                        group.min_selection,

                                    max_selection:
                                        group.max_selection,

                                    options
                                };
                            });

                    return {
                        menu_item_id: item.menu_item_id,
                        item_code: item.item_code,
                        item_name: item.item_name,
                        description: item.description,
                        item_type: item.item_type,
                        base_rate: item.base_rate,

                        is_veg: item.is_veg,
                        is_egg: item.is_egg,
                        is_spicy: item.is_spicy,

                        image_url: item.image_url,

                        variants: itemVariants,
                        modifierGroups: itemModifierGroups
                    };
                });

            return {
                category_id:
                    category.menu_category_id,

                category_code:
                    category.category_code,

                category_name:
                    category.category_name,

                display_order:
                    category.display_order,

                items: categoryItems
            };
        });

        // --------------------------------------------------
        // 9. Update customer activity
        // --------------------------------------------------

        await db.query(
            `
            UPDATE customer_order_session
            SET last_activity_at = CURRENT_TIMESTAMP
            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        // --------------------------------------------------
        // 10. Return customer-safe menu
        // --------------------------------------------------

        return res.json({
            success: true,

            customer_session: {
                customer_session_id:
                    session.customer_session_id,

                customer_name:
                    session.customer_name,

                customer_phone:
                    session.customer_phone
            },

            table: {
                table_id: tables[0].table_id,
                table_code: tables[0].table_code,
                table_name: tables[0].table_name,
                capacity: tables[0].capacity
            },

            menu
        });

    } catch (error) {

        console.error(
            'Get customer menu error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get customer menu'
        });

    } finally {
        db.release();
    }
};