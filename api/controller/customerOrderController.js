
const crypto = require('crypto');
9

const pool =  require('../database');

const {
    createOrderInternal,
    addOrderItemInternal,
    recalculateOrder
} = require('./orderController');


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



exports.createCustomerOrder = async (req, res) => {

    const connection = await pool.getConnection();

    try {

        const {
                customerSessionToken,
                customerId = null,
                guestCount = 1,
                remarks = null,
                items = []
        } = req.body;

        // ----------------------------------------
        // Basic validation
        // ----------------------------------------

        if (!customerSessionToken) {
            return res.status(400).json({
            success: false,
            message: 'customerSessionToken is required'
            });
        }

        if (!Array.isArray(items) || items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'At least one item is required'
            });
        }

        await connection.beginTransaction();

       // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,
                cs.customer_id,
                cs.customer_name,
                cs.customer_phone,
                cs.status AS customer_session_status,
        
                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status,
                ts.expires_at,
        
                o.company_id
        
            FROM customer_order_session cs
        
            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id
        
            INNER JOIN outlet o
                ON o.outlet_id = ts.outlet_id
        
            WHERE cs.session_token = ?
        
            FOR UPDATE
            `,
            [customerSessionToken]
        );

        if (sessions.length === 0) {
        
            await connection.rollback();
        
            return res.status(404).json({
                success: false,
                message: 'Invalid customer session'
            });
        }

        const session = sessions[0];

        // ----------------------------------------
        // 2. Check session status
        // ----------------------------------------

        // ----------------------------------------
        // 2. Check customer session status
        // ----------------------------------------

        if (session.customer_session_status !== 'ACTIVE') {
        
            await connection.rollback();
        
            return res.status(400).json({
                success: false,
                message: 'This customer session is no longer active'
            });
        }

        // ----------------------------------------
        // 3. Check table session status
        // ----------------------------------------

        if (session.table_session_status !== 'ACTIVE') {
        
            await connection.rollback();
        
            return res.status(400).json({
                success: false,
                message: 'This table QR session is no longer active'
            });
        }

        // ----------------------------------------
        // 3. Check expiry
        // ----------------------------------------

        if (
            session.expires_at &&
            new Date(session.expires_at) <= new Date()
        ) {
        
            await connection.query(
                `
                UPDATE table_order_session
                SET
                    status = 'EXPIRED',
                    closed_at = NOW()
                WHERE session_id = ?
                `,
                [session.table_session_id]
            );
        
            await connection.query(
                `
                UPDATE customer_order_session
                SET
                    status = 'EXPIRED',
                    closed_at = NOW()
                WHERE customer_session_id = ?
                `,
                [session.customer_session_id]
            );
        
            await connection.commit();
        
            return res.status(400).json({
                success: false,
                message: 'This table QR session has expired'
            });
        }



        // ----------------------------------------
        // 4. Resolve customer
        // ----------------------------------------

        let finalCustomerId = session.customer_id || null;

        if (customerId !== null && customerId !== undefined) {
        
            const requestedCustomerId = Number(customerId);
        
            if (!requestedCustomerId) {
            
                await connection.rollback();
            
                return res.status(400).json({
                    success: false,
                    message: 'Invalid customerId'
                });
            }
        
            const [customers] = await connection.query(
                `
                SELECT customer_id
                FROM customer
                WHERE customer_id = ?
                LIMIT 1
                `,
                [requestedCustomerId]
            );
        
            if (customers.length === 0) {
            
                await connection.rollback();
            
                return res.status(400).json({
                    success: false,
                    message: 'Invalid customerId'
                });
            }
        
            if (
                session.customer_id !== null &&
                Number(session.customer_id) !== requestedCustomerId
            ) {
            
                await connection.rollback();
            
                return res.status(400).json({
                    success: false,
                    message: 'customerId does not match customer session'
                });
            }
        
            finalCustomerId = requestedCustomerId;
        }
        // ----------------------------------------
        // 4. Resolve SYSTEM_QR user
        // ----------------------------------------

        const systemUserId =
            await getQrSystemUser(
                connection,
                session.company_id
            );

        // ----------------------------------------
        // 5. Validate customer if supplied
        // ----------------------------------------

        if (customerId) {

            const [customers] =
                await connection.query(
                    `
                    SELECT
                        c.customer_id
                    FROM customer c
                    WHERE c.customer_id = ?
                    LIMIT 1
                    `,
                    [customerId]
                );

            if (customers.length === 0) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,
                    message: 'Invalid customerId'
                });
            }
        }

        // ----------------------------------------
        // 6. Create QR order
        // ----------------------------------------

        const order =
            await createOrderInternal(
                connection,
                {
                    outletId: session.outlet_id,

                    terminalId: null,

                    orderType: 'QR_ORDER',

                    tableId: session.table_id,

                    customerId: finalCustomerId,

                    reservationId: null,
                    waiterId: null,
                    captainId: null,

                    guestCount:
                        Number(guestCount) > 0
                            ? Number(guestCount)
                            : 1,

                    parentOrderId: null,

                    remarks: remarks || null,

                    orderSource: 'QR',

                    tableSessionId:
                        session.table_session_id,
                    customerSessionId:
                        session.customer_session_id,
                    userId: systemUserId,

                    companyId:
                        session.company_id
                }
            );

        const orderId = order.orderId;

        // ----------------------------------------
        // 7. Add order items
        // ----------------------------------------

        for (const item of items) {

            if (!item.menuItemId) {
                throw new Error(
                    'menuItemId is required'
                );
            }

            if (
                !item.qty ||
                Number(item.qty) <= 0
            ) {
                throw new Error(
                    'Invalid item quantity'
                );
            }

            await addOrderItemInternal(
                connection,
                {
                    orderId,

                    menuItemId:
                        Number(item.menuItemId),

                    variantId:
                        item.variantId
                            ? Number(item.variantId)
                            : null,

                    qty:
                        Number(item.qty),

                    specialInstruction:
                        item.specialInstruction ||
                        null,

                    modifiers:
                        Array.isArray(item.modifiers)
                            ? item.modifiers
                            : [],

                    userId:
                        systemUserId,

                    companyId:
                        session.company_id
                }
            );
        }

        // ----------------------------------------
        // 8. Final recalculation
        // ----------------------------------------

        await recalculateOrder(
            connection,
            orderId,
            systemUserId
        );

        // ----------------------------------------
        // 9. Update session activity
        // ----------------------------------------

       await connection.query(
            `
            UPDATE customer_order_session
            SET last_activity_at = CURRENT_TIMESTAMP
            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        await connection.query(
            `
            UPDATE table_order_session
            SET updated_at = CURRENT_TIMESTAMP
            WHERE session_id = ?
            `,
            [session.table_session_id]
        );

        // ----------------------------------------
        // 10. Commit
        // ----------------------------------------

        await connection.commit();

        // ----------------------------------------
        // 11. Return complete order
        // ----------------------------------------

        return res.status(201).json({
            success: true,
            message: 'Customer order created successfully',

            customer_session: {
                customer_session_id:
                    session.customer_session_id,
            
                customer_name:
                    session.customer_name,
            
                customer_phone:
                    session.customer_phone
            },
        
            table: {
                table_id:
                    session.table_id
            },
        
            orderId: orderId,
        
            order
        });

    } catch (error) {

        try {
            await connection.rollback();
        } catch (_) {}

        console.error(
            'createCustomerOrder error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: error.message ||
                'Failed to create customer order'
        });

    } finally {

        connection.release();
    }
};

async function getQrSystemUser(connection, companyId) {

    const [users] = await connection.query(
        `
        SELECT
            u.user_id
        FROM app_user u
        INNER JOIN role r
            ON r.role_id = u.role_id
        WHERE u.company_id = ?
          AND u.username = 'SYSTEM_QR'
          AND r.role_code = 'SYSTEM'
          AND u.is_active = TRUE
        LIMIT 1
        `,
        [companyId]
    );

    if (users.length === 0) {
        throw new Error(
            'QR system user is not configured for this company'
        );
    }

    return users[0].user_id;
}

exports.getMyOrders = async (req, res) => {
    const connection = await pool.getConnection();

    try {
        const customerSessionToken = req.params.token;

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'Customer session token is required'
            });
        }

        // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,
                cs.customer_id,
                cs.customer_name,
                cs.customer_phone,
                cs.status AS customer_session_status,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status,

                t.table_code,
                t.table_name

            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id

            INNER JOIN restaurant_table t
                ON t.table_id = ts.table_id

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

        // ----------------------------------------
        // 2. Get customer's orders
        // ----------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                o.order_id,
                o.order_uuid,
                o.order_no,
                o.order_date,
                o.order_time,
                o.order_type,
                o.order_source,
                o.order_status,

                o.table_id,
                o.logical_table_id,

                lt.logical_code,
                lt.logical_name,

                o.guest_count,
                o.remarks,

                o.subtotal,
                o.item_discount,
                o.bill_discount,
                o.taxable_amount,
                o.tax_amount,
                o.rounding_amount,
                o.grand_total,
                o.paid_amount,
                o.balance_amount,

                o.created_at,
                o.updated_at

            FROM orders o

            LEFT JOIN logical_table lt
                ON lt.logical_table_id = o.logical_table_id

            WHERE o.customer_session_id = ?

            ORDER BY
                o.order_id DESC
            `,
            [session.customer_session_id]
        );

        // ----------------------------------------
        // 3. Get order items
        // ----------------------------------------

        for (const order of orders) {

            const [items] = await connection.query(
                `
                SELECT
                    oi.order_item_id,
                    oi.line_no,

                    oi.menu_item_id,
                    oi.variant_id,

                    oi.item_name,
                    oi.variant_name,

                    oi.qty,
                    oi.rate,

                    oi.gross_amount,
                    oi.discount_amount,
                    oi.taxable_amount,
                    oi.tax_amount,
                    oi.net_amount,

                    oi.status,
                    oi.special_instruction,

                    oi.created_at

                FROM order_item oi

                WHERE oi.order_id = ?

                ORDER BY
                    oi.line_no
                `,
                [order.order_id]
            );

            // ----------------------------------------
            // 4. Get modifiers for each item
            // ----------------------------------------

            for (const item of items) {

                const [modifiers] = await connection.query(
                    `
                    SELECT
                        oim.order_item_modifier_id,
                        oim.modifier_group_id,
                        oim.modifier_option_id,
                        oim.modifier_name,
                        oim.qty,
                        oim.rate,
                        oim.amount

                    FROM order_item_modifier oim

                    WHERE oim.order_item_id = ?

                    ORDER BY
                        oim.order_item_modifier_id
                    `,
                    [item.order_item_id]
                );

                item.modifiers = modifiers;
            }

            order.items = items;
        }

        // ----------------------------------------
        // 5. Update customer activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE customer_order_session
            SET last_activity_at = CURRENT_TIMESTAMP
            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        // ----------------------------------------
        // 6. Return customer-safe response
        // ----------------------------------------

        return res.json({
            success: true,

            customer_session: {
                customer_session_id:
                    session.customer_session_id,

                customer_name:
                    session.customer_name
            },

            table: {
                table_id:
                    session.table_id,

                table_code:
                    session.table_code,

                table_name:
                    session.table_name
            },

            orders
        });

    } catch (error) {

        console.error(
            'getMyOrders error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get customer orders'
        });

    } finally {

        connection.release();
    }
};

exports.addItemsToCustomerOrder = async (req, res) => {

    const connection = await pool.getConnection();

    try {

        const {
            customerSessionToken,
            orderId,
            items = []
        } = req.body;

        // ----------------------------------------
        // Basic validation
        // ----------------------------------------

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'customerSessionToken is required'
            });
        }

        if (!orderId || Number(orderId) <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid orderId is required'
            });
        }

        if (!Array.isArray(items) || items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'At least one item is required'
            });
        }

        await connection.beginTransaction();

        // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,
                cs.customer_id,
                cs.customer_name,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status,
                ts.expires_at,

                o.company_id

            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id

            INNER JOIN outlet o
                ON o.outlet_id = ts.outlet_id

            WHERE cs.session_token = ?
              AND cs.status = 'ACTIVE'

            LIMIT 1

            FOR UPDATE
            `,
            [customerSessionToken]
        );

        if (sessions.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Customer session is invalid or expired'
            });
        }

        const session = sessions[0];

        // ----------------------------------------
        // 2. Validate table session
        // ----------------------------------------

        if (session.table_session_status !== 'ACTIVE') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'This table session is no longer active'
            });
        }

        // ----------------------------------------
        // 3. Check table session expiry
        // ----------------------------------------

        if (
            session.expires_at &&
            new Date(session.expires_at) <= new Date()
        ) {

            await connection.query(
                `
                UPDATE table_order_session
                SET
                    status = 'EXPIRED',
                    closed_at = NOW()
                WHERE session_id = ?
                `,
                [session.table_session_id]
            );

            await connection.query(
                `
                UPDATE customer_order_session
                SET
                    status = 'EXPIRED',
                    closed_at = NOW()
                WHERE customer_session_id = ?
                `,
                [session.customer_session_id]
            );

            await connection.commit();

            return res.status(400).json({
                success: false,
                message: 'This table session has expired'
            });
        }

        // ----------------------------------------
        // 4. Resolve QR system user
        // ----------------------------------------

        const systemUserId =
            await getQrSystemUser(
                connection,
                session.company_id
            );

        // ----------------------------------------
        // 5. Lock and validate customer's order
        // ----------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                order_id,
                order_uuid,
                order_no,
                outlet_id,
                table_id,
                logical_table_id,
                table_session_id,
                customer_session_id,
                order_type,
                order_source,
                order_status

            FROM orders

            WHERE order_id = ?
              AND customer_session_id = ?
              AND table_session_id = ?
              AND outlet_id = ?

            LIMIT 1

            FOR UPDATE
            `,
            [
                Number(orderId),
                session.customer_session_id,
                session.table_session_id,
                session.outlet_id
            ]
        );

        if (orders.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order not found for this customer session'
            });
        }

        const order = orders[0];

        // ----------------------------------------
        // 6. Check order status
        // ----------------------------------------

        const blockedStatuses = [
            'PAID',
            'CANCELLED',
            'VOID',
            'MERGED',
            'BILLED'
        ];

        if (blockedStatuses.includes(order.order_status)) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Items cannot be added to an order with status ${order.order_status}`
            });
        }

        // ----------------------------------------
        // 7. Add new items
        // ----------------------------------------

        for (const item of items) {

            if (!item.menuItemId) {
                throw new Error(
                    'menuItemId is required'
                );
            }

            if (
                !item.qty ||
                Number(item.qty) <= 0
            ) {
                throw new Error(
                    'Invalid item quantity'
                );
            }

            await addOrderItemInternal(
                connection,
                {
                    orderId: order.order_id,

                    menuItemId:
                        Number(item.menuItemId),

                    variantId:
                        item.variantId
                            ? Number(item.variantId)
                            : null,

                    qty:
                        Number(item.qty),

                    specialInstruction:
                        item.specialInstruction ||
                        null,

                    modifiers:
                        Array.isArray(item.modifiers)
                            ? item.modifiers
                            : [],

                    userId:
                        systemUserId,

                    companyId:
                        session.company_id
                }
            );
        }

        // ----------------------------------------
        // 8. Recalculate order
        // ----------------------------------------

        await recalculateOrder(
            connection,
            order.order_id,
            systemUserId
        );

        // ----------------------------------------
        // 9. Update customer activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE customer_order_session
            SET
                last_activity_at = CURRENT_TIMESTAMP
            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        // ----------------------------------------
        // 10. Update table session activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE table_order_session
            SET
                updated_at = CURRENT_TIMESTAMP
            WHERE session_id = ?
            `,
            [session.table_session_id]
        );

        // ----------------------------------------
        // 11. Commit
        // ----------------------------------------

        await connection.commit();

        // ----------------------------------------
        // 12. Return
        // ----------------------------------------

        return res.status(200).json({
            success: true,
            message: 'Items added to order successfully',
            orderId: order.order_id
        });

    } catch (error) {

        try {
            await connection.rollback();
        } catch (_) {}

        console.error(
            'addItemsToCustomerOrder error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                error.message ||
                'Failed to add items to customer order'
        });

    } finally {

        connection.release();
    }
};

exports.getCustomerOrderStatus = async (req, res) => {
    const connection = await pool.getConnection();

    try {
        const customerSessionToken = req.params.token;

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'Customer session token is required'
            });
        }

        // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.customer_name,
                cs.table_session_id,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status

            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id

            WHERE cs.session_token = ?
              AND cs.status = 'ACTIVE'

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

        if (session.table_session_status !== 'ACTIVE') {
            return res.status(400).json({
                success: false,
                message: 'This table session is no longer active'
            });
        }

        // ----------------------------------------
        // 2. Get customer's orders
        // ----------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                o.order_id,
                o.order_no,
                o.order_status,

                o.table_id,
                o.logical_table_id,

                lt.logical_code,
                lt.logical_name,

                o.subtotal,
                o.item_discount,
                o.bill_discount,
                o.taxable_amount,
                o.tax_amount,
                o.rounding_amount,
                o.grand_total,
                o.paid_amount,
                o.balance_amount,

                o.bill_requested,
                o.bill_requested_at,
                
                o.created_at,
                o.updated_at

            FROM orders o

            LEFT JOIN logical_table lt
                ON lt.logical_table_id = o.logical_table_id

            WHERE o.customer_session_id = ?
                 AND o.order_status NOT IN ('CANCELLED', 'VOID', 'MERGED')
            ORDER BY o.order_id DESC
            `,
            [session.customer_session_id]
        );

        // ----------------------------------------
        // 3. Get item status
        // ----------------------------------------

        for (const order of orders) {

            const [items] = await connection.query(
                `
                SELECT
                    oi.order_item_id,
                    oi.line_no,

                    oi.menu_item_id,
                    oi.variant_id,

                    oi.item_name,
                    oi.variant_name,

                    oi.qty,
                    oi.status,
                    oi.special_instruction

                FROM order_item oi

                WHERE oi.order_id = ?

                ORDER BY oi.line_no
                `,
                [order.order_id]
            );

            order.items = items;
        }

        // ----------------------------------------
        // 4. Update activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE customer_order_session
            SET last_activity_at = CURRENT_TIMESTAMP
            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        // ----------------------------------------
        // 5. Return status
        // ----------------------------------------

        return res.json({
            success: true,

            customer_session: {
                customer_session_id:
                    session.customer_session_id,

                customer_name:
                    session.customer_name
            },

            table: {
                table_id:
                    session.table_id
            },

            orders
        });

    } catch (error) {

        console.error(
            'getCustomerOrderStatus error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get customer order status'
        });

    } finally {
        connection.release();
    }
};

exports.requestBill = async (req, res) => {

    const connection = await pool.getConnection();

    try {

        const {
            customerSessionToken,
            orderId
        } = req.body;

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'customerSessionToken is required'
            });
        }

        if (!orderId || Number(orderId) <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid orderId is required'
            });
        }

        await connection.beginTransaction();

        // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status

            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id

            WHERE cs.session_token = ?
              AND cs.status = 'ACTIVE'

            LIMIT 1

            FOR UPDATE
            `,
            [customerSessionToken]
        );

        if (sessions.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Customer session is invalid or expired'
            });
        }

        const session = sessions[0];

        if (session.table_session_status !== 'ACTIVE') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'This table session is no longer active'
            });
        }

        // ----------------------------------------
        // 2. Lock customer's order
        // ----------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                order_id,
                order_status,
                customer_session_id,
                table_session_id,
                bill_requested,
                grand_total,
                paid_amount,
                balance_amount

            FROM orders

            WHERE order_id = ?
              AND customer_session_id = ?
              AND table_session_id = ?
              AND outlet_id = ?

            LIMIT 1

            FOR UPDATE
            `,
            [
                Number(orderId),
                session.customer_session_id,
                session.table_session_id,
                session.outlet_id
            ]
        );

        if (orders.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order not found for this customer session'
            });
        }

        const order = orders[0];

        // ----------------------------------------
        // 3. Validate order status
        // ----------------------------------------

        if (
            order.order_status === 'CANCELLED' ||
            order.order_status === 'VOID' ||
            order.order_status === 'MERGED'
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Bill cannot be requested for order with status ${order.order_status}`
            });
        }

        if (order.order_status === 'PAID') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'This order is already paid'
            });
        }

        if (order.order_status === 'BILLED') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'Bill has already been generated for this order'
            });
        }

        // ----------------------------------------
        // 4. Request bill
        // ----------------------------------------

        await connection.query(
            `
            UPDATE orders

            SET
                bill_requested = 1,
                bill_requested_at = CURRENT_TIMESTAMP

            WHERE order_id = ?
            `,
            [order.order_id]
        );

        // ----------------------------------------
        // 5. Update customer activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE customer_order_session

            SET
                last_activity_at = CURRENT_TIMESTAMP

            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        await connection.commit();

        return res.json({
            success: true,
            message: 'Bill requested successfully',
            orderId: order.order_id,
            billRequested: true
        });

    } catch (error) {

        try {
            await connection.rollback();
        } catch (_) {}

        console.error(
            'requestBill error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                error.message ||
                'Unable to request bill'
        });

    } finally {
        connection.release();
    }
};

exports.cancelCustomerOrderItem = async (req, res) => {

    const connection = await pool.getConnection();

    try {

        const {
            customerSessionToken,
            orderId,
            orderItemId,
            reason = null
        } = req.body;

        // ----------------------------------------
        // Basic validation
        // ----------------------------------------

        if (!customerSessionToken) {
            return res.status(400).json({
                success: false,
                message: 'customerSessionToken is required'
            });
        }

        if (!orderId || Number(orderId) <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid orderId is required'
            });
        }

        if (!orderItemId || Number(orderItemId) <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid orderItemId is required'
            });
        }

        await connection.beginTransaction();

        // ----------------------------------------
        // 1. Validate customer session
        // ----------------------------------------

        const [sessions] = await connection.query(
            `
            SELECT
                cs.customer_session_id,
                cs.table_session_id,

                ts.outlet_id,
                ts.table_id,
                ts.status AS table_session_status,
                ot.company_id
            FROM customer_order_session cs

            INNER JOIN table_order_session ts
                ON ts.session_id = cs.table_session_id
            INNER JOIN outlet  ot on ot.outlet_id=ts.outlet_id
            WHERE cs.session_token = ?
              AND cs.status = 'ACTIVE'

            LIMIT 1

            FOR UPDATE
            `,
            [customerSessionToken]
        );

        if (sessions.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Customer session is invalid or expired'
            });
        }

        const session = sessions[0];

        if (session.table_session_status !== 'ACTIVE') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'This table session is no longer active'
            });
        }

        // ----------------------------------------
        // 2. Validate customer's order
        // ----------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                order_id,
                order_status

            FROM orders

            WHERE order_id = ?
              AND customer_session_id = ?
              AND table_session_id = ?
              AND outlet_id = ?

            LIMIT 1

            FOR UPDATE
            `,
            [
                Number(orderId),
                session.customer_session_id,
                session.table_session_id,
                session.outlet_id
            ]
        );

        if (orders.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order not found for this customer session'
            });
        }

        const order = orders[0];

        // ----------------------------------------
        // 3. Check order status
        // ----------------------------------------

        if (
            order.order_status === 'BILLED' ||
            order.order_status === 'PAID' ||
            order.order_status === 'CANCELLED' ||
            order.order_status === 'VOID' ||
            order.order_status === 'MERGED'
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Item cannot be cancelled when order status is ${order.order_status}`
            });
        }

        // ----------------------------------------
        // 4. Lock order item
        // ----------------------------------------

        const [items] = await connection.query(
            `
            SELECT
                order_item_id,
                order_id,
                qty,
                status,
                item_name

            FROM order_item

            WHERE order_item_id = ?
              AND order_id = ?

            LIMIT 1

            FOR UPDATE
            `,
            [
                Number(orderItemId),
                Number(orderId)
            ]
        );

        if (items.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order item not found'
            });
        }

        const item = items[0];

        // ----------------------------------------
        // 5. Only OPEN items can be cancelled
        // ----------------------------------------

        if (item.status !== 'OPEN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Item "${item.item_name}" cannot be cancelled because it is already ${item.status}`
            });
        }

        // ----------------------------------------
        // 6. Cancel item
        // ----------------------------------------

        await connection.query(
            `
            UPDATE order_item

            SET
                status = 'CANCELLED',
                cancelled_reason = ?

            WHERE order_item_id = ?
              AND order_id = ?
            `,
            [
                reason || 'Cancelled by customer',
                Number(orderItemId),
                Number(orderId)
            ]
        );

        // ----------------------------------------
        // 7. Recalculate order
        // ----------------------------------------
        console.log("company")
        console.log(session.company_id)
        const [systemUsers] = await connection.query(
            `
            SELECT
                u.user_id

            FROM app_user u

            INNER JOIN role r
                ON r.role_id = u.role_id

            WHERE u.company_id = ?
              AND u.username = 'SYSTEM_QR'
              AND r.role_code = 'SYSTEM'
              AND u.is_active = TRUE

            LIMIT 1
            `,
            [session.company_id]
        );

        /*
         * We don't actually need a new system user lookup
         * if your existing controller already has the helper.
         */

        const systemUserId =
            await getQrSystemUser(
                connection,
                session.company_id
            );

        await recalculateOrder(
            connection,
            Number(orderId),
            systemUserId
        );

        // ----------------------------------------
        // 8. Update customer activity
        // ----------------------------------------

        await connection.query(
            `
            UPDATE customer_order_session

            SET
                last_activity_at = CURRENT_TIMESTAMP

            WHERE customer_session_id = ?
            `,
            [session.customer_session_id]
        );

        await connection.commit();

        return res.json({
            success: true,
            message: 'Order item cancelled successfully',
            orderId: Number(orderId),
            orderItemId: Number(orderItemId)
        });

    } catch (error) {

        try {
            await connection.rollback();
        } catch (_) {}

        console.error(
            'cancelCustomerOrderItem error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                error.message ||
                'Unable to cancel order item'
        });

    } finally {
        connection.release();
    }
};


