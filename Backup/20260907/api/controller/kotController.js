const db =  require('../database');

const crypto = require('crypto');


/*
 * ============================================================
 * Generate next KOT number
 * ============================================================
 */

async function getNextKotNo(
    connection,
    outletId
) {

    const [rows] = await connection.query(
        `
        SELECT kot_no
        FROM kot
        WHERE outlet_id = ?
        ORDER BY kot_id DESC
        LIMIT 1
        FOR UPDATE
        `,
        [outletId]
    );


    let nextNo = 1;


    if (rows.length > 0) {

        const lastNo =
            parseInt(
                rows[0].kot_no,
                10
            );

        if (!isNaN(lastNo)) {
            nextNo = lastNo + 1;
        }
    }


    return String(nextNo);
}


/*
 * ============================================================
 * POST /api/orders/:orderId/kot
 *
 * Generate KOT(s) for unsent order items.
 *
 * If items belong to different kitchen stations,
 * one KOT will be created for each station.
 * ============================================================
 */

exports.createKOT = async (req, res) => {

    const connection =
        await db.getConnection();

    try {

        const orderId =
            Number(req.params.orderId);


        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }


        await connection.beginTransaction();


        // ----------------------------------------------------
        // 1. Get and lock order
        // ----------------------------------------------------

        const [orders] =
            await connection.query(
                `
                SELECT
                    o.*

                FROM orders o

                INNER JOIN outlet ot
                    ON ot.outlet_id = o.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = o.outlet_id

                WHERE o.order_id = ?
                  AND ot.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    orderId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (orders.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }


        const order = orders[0];


        // ----------------------------------------------------
        // 2. Validate order status
        // ----------------------------------------------------

        if (
            [
                'CANCELLED',
                'VOID',
                'PAID'
            ].includes(
                order.order_status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot create KOT for ${order.order_status} order`
            });
        }


        // ----------------------------------------------------
        // 3. Get unsent order items
        // ----------------------------------------------------

        /*
         * We only send OPEN items.
         *
         * Existing SENT_TO_KITCHEN / PREPARING /
         * READY / SERVED items are not sent again.
         */

        const [items] =
            await connection.query(
                `
                SELECT
                    order_item_id,
                    order_item_uuid,
                    line_no,

                    menu_item_id,
                    variant_id,

                    item_name,
                    variant_name,

                    qty,

                    kitchen_station_id,

                    special_instruction,
                    status

                FROM order_item

                WHERE order_id = ?

                  AND status = 'OPEN'

                  AND qty > 0

                ORDER BY
                    line_no

                FOR UPDATE
                `,
                [orderId]
            );


        if (items.length === 0) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'There are no unsent items for KOT'
            });
        }


        // ----------------------------------------------------
        // 4. Validate kitchen station
        // ----------------------------------------------------

        for (const item of items) {

            if (!item.kitchen_station_id) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,

                    message:
                        `Kitchen station is not assigned for ${item.item_name}`,

                    orderItemId:
                        item.order_item_id
                });
            }


            const [stations] =
                await connection.query(
                    `
                    SELECT
                        kitchen_station_id,
                        station_name

                    FROM kitchen_station

                    WHERE kitchen_station_id = ?

                      AND outlet_id = ?

                      AND is_active = TRUE

                    LIMIT 1
                    `,
                    [
                        item.kitchen_station_id,
                        order.outlet_id
                    ]
                );


            if (stations.length === 0) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,

                    message:
                        `Invalid kitchen station for ${item.item_name}`,

                    orderItemId:
                        item.order_item_id
                });
            }
        }


        // ----------------------------------------------------
        // 5. Group items by kitchen station
        // ----------------------------------------------------

        const stationGroups = {};


        for (const item of items) {

            const stationId =
                item.kitchen_station_id;


            if (!stationGroups[stationId]) {

                stationGroups[stationId] = [];
            }


            stationGroups[stationId]
                .push(item);
        }


        const createdKots = [];


        // ----------------------------------------------------
        // 6. Create KOT for each station
        // ----------------------------------------------------

        for (
            const [
                stationId,
                stationItems
            ]
            of Object.entries(
                stationGroups
            )
        ) {

            const kotUuid =
                crypto.randomUUID();


            const kotNo =
                await getNextKotNo(
                    connection,
                    order.outlet_id
                );


            // -----------------------------------------------
            // Create KOT header
            // -----------------------------------------------

            const [kotResult] =
                await connection.query(
                    `
                    INSERT INTO kot
                    (
                        kot_uuid,
                        outlet_id,
                        order_id,
                        kot_no,
                        kot_date,
                        kitchen_station_id,
                        status,
                        printed_count,
                        created_by
                    )

                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        ?,
                        NOW(),
                        ?,
                        'NEW',
                        0,
                        ?
                    )
                    `,
                    [
                        kotUuid,
                        order.outlet_id,
                        orderId,
                        kotNo,
                        Number(stationId),
                        req.user.userId
                    ]
                );


            const kotId =
                kotResult.insertId;


            // -----------------------------------------------
            // Insert KOT items
            // -----------------------------------------------

            for (const item of stationItems) {

                await connection.query(
                    `
                    INSERT INTO kot_item
                    (
                        kot_id,
                        order_item_id,
                        qty,
                        item_name,
                        variant_name,
                        instruction,
                        status
                    )

                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        'NEW'
                    )
                    `,
                    [
                        kotId,

                        item.order_item_id,

                        item.qty,

                        item.item_name,

                        item.variant_name,

                        item.special_instruction
                    ]
                );


                // -------------------------------------------
                // Mark order item as sent to kitchen
                // -------------------------------------------

                await connection.query(
                    `
                    UPDATE order_item

                    SET
                        status = 'SENT_TO_KITCHEN'

                    WHERE order_item_id = ?
                    `,
                    [
                        item.order_item_id
                    ]
                );
            }


            createdKots.push({
                kotId,
                kotUuid,
                kotNo,
                kitchenStationId:
                    Number(stationId),

                itemCount:
                    stationItems.length
            });
        }


        // ----------------------------------------------------
        // 7. Update order status
        // ----------------------------------------------------

        /*
         * At this point the order has been sent
         * to kitchen.
         */

        await connection.query(
            `
            UPDATE orders

            SET
                order_status = 'PREPARING',
                updated_by = ?

            WHERE order_id = ?
            `,
            [
                req.user.userId,
                orderId
            ]
        );


        await connection.commit();


        return res.status(201).json({
            success: true,

            message:
                'KOT created successfully',

            orderId,

            kots: createdKots
        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Create KOT error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create KOT'
        });

    } finally {

        connection.release();
    }
};


/*
 * ============================================================
 * GET /api/orders/:orderId/kot
 *
 * Get all KOTs belonging to an order.
 * ============================================================
 */

exports.getOrderKOTs = async (
    req,
    res
) => {
  const connection =
        await db.getConnection();
    try {

        const orderId =
            Number(req.params.orderId);


        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }


        // ----------------------------------------------------
        // Verify order access
        // ----------------------------------------------------

        const [orders] =
            await connection.query(
                `
                SELECT
                    o.order_id,
                    o.outlet_id

                FROM orders o

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       o.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       o.outlet_id

                WHERE o.order_id = ?

                  AND ot.company_id = ?

                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    orderId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (orders.length === 0) {

            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }


        // ----------------------------------------------------
        // KOT headers
        // ----------------------------------------------------

        const [kots] =
            await connection.query(
                `
                SELECT
                    k.kot_id,
                    k.kot_uuid,
                    k.outlet_id,
                    k.order_id,
                    k.kot_no,
                    k.kot_date,

                    k.kitchen_station_id,

                    ks.station_code,
                    ks.station_name,

                    k.status,
                    k.printed_count,

                    k.created_by,
                    k.updated_at

                FROM kot k

                LEFT JOIN kitchen_station ks
                    ON ks.kitchen_station_id =
                       k.kitchen_station_id

                WHERE k.order_id = ?

                ORDER BY
                    k.kot_id
                `,
                [orderId]
            );


        // ----------------------------------------------------
        // KOT items
        // ----------------------------------------------------

        for (const kot of kots) {

            const [items] =
                await connection.query(
                    `
                    SELECT
                        kot_item_id,
                        kot_id,
                        order_item_id,
                        qty,
                        item_name,
                        variant_name,
                        instruction,
                        status,
                        started_at,
                        ready_at,
                        served_at

                    FROM kot_item

                    WHERE kot_id = ?

                    ORDER BY kot_item_id
                    `,
                    [kot.kot_id]
                );


            kot.items = items;
        }


        return res.json({
            success: true,

            orderId,

            kots
        });


    } catch (error) {

        console.error(
            'Get order KOT error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get order KOTs'
        });
    }
};


/*
 * ============================================================
 * GET /api/kot/station/:stationId
 *
 * Get active KOTs for a kitchen station.
 *
 * Used by Kitchen Display System (KDS).
 * ============================================================
 */

exports.getStationKOTs = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const stationId =
            Number(req.params.stationId);

        if (!stationId) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid stationId'
            });
        }


        // ----------------------------------------------------
        // Verify station access
        // ----------------------------------------------------

        const [stations] =
            await connection.query(
                `
                SELECT
                    ks.kitchen_station_id,
                    ks.outlet_id,
                    ks.station_code,
                    ks.station_name

                FROM kitchen_station ks

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       ks.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       ks.outlet_id

                WHERE
                    ks.kitchen_station_id = ?

                    AND ks.is_active = TRUE

                    AND ot.company_id = ?

                    AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    stationId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (stations.length === 0) {

            return res.status(404).json({
                success: false,
                message:
                    'Kitchen station not found'
            });
        }


        const station =
            stations[0];


        // ----------------------------------------------------
        // Get active KOTs
        // ----------------------------------------------------

        const [kots] =
            await connection.query(
                `
                SELECT
                    k.kot_id,
                    k.kot_uuid,
                    k.outlet_id,
                    k.order_id,
                    k.kot_no,
                    k.kot_date,

                    k.kitchen_station_id,

                    ks.station_code,
                    ks.station_name,

                    k.status,
                    k.printed_count,

                    k.created_by,
                    k.updated_at

                FROM kot k

                INNER JOIN kitchen_station ks
                    ON ks.kitchen_station_id =
                       k.kitchen_station_id

                WHERE
                    k.kitchen_station_id = ?

                    AND k.outlet_id = ?

                    AND k.status IN
                    (
                        'NEW',
                        'ACCEPTED',
                        'PREPARING',
                        'READY'
                    )

                ORDER BY
                    k.kot_id
                `,
                [
                    stationId,
                    station.outlet_id
                ]
            );


        // ----------------------------------------------------
        // Get KOT items
        // ----------------------------------------------------

        for (const kot of kots) {

            const [items] =
                await connection.query(
                    `
                    SELECT
                        kot_item_id,
                        kot_id,
                        order_item_id,
                        qty,
                        item_name,
                        variant_name,
                        instruction,
                        status,
                        started_at,
                        ready_at,
                        served_at

                    FROM kot_item

                    WHERE kot_id = ?

                    ORDER BY kot_item_id
                    `,
                    [kot.kot_id]
                );


            kot.items = items;
        }


        // ----------------------------------------------------
        // Response
        // ----------------------------------------------------

        return res.json({
            success: true,

            station: {
                kitchenStationId:
                    station.kitchen_station_id,

                stationCode:
                    station.station_code,

                stationName:
                    station.station_name,

                outletId:
                    station.outlet_id
            },

            kots
        });


    } catch (error) {

        console.error(
            'Get station KOT error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get station KOTs'
        });

    } finally {

        connection.release();
    }
};

/*
 * ============================================================
 * PUT /api/kot/:kotId/status
 *
 * Change KOT status.
 * ============================================================
 */

exports.updateKOTStatus = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const kotId =
            Number(req.params.kotId);

        const {
            status
        } = req.body;


        if (!kotId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid kotId'
            });
        }


        const validStatuses = [
            'NEW',
            'ACCEPTED',
            'PREPARING',
            'READY',
            'SERVED',
            'CANCELLED'
        ];


        if (!validStatuses.includes(status)) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid KOT status'
            });
        }


        await connection.beginTransaction();


        // ----------------------------------------------------
        // Get KOT
        // ----------------------------------------------------

        const [kots] =
            await connection.query(
                `
                SELECT
                    k.*

                FROM kot k

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       k.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       k.outlet_id

                WHERE k.kot_id = ?

                  AND ot.company_id = ?

                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    kotId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (kots.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'KOT not found'
            });
        }


        const kot =
            kots[0];


        // ----------------------------------------------------
        // Update KOT
        // ----------------------------------------------------

        await connection.query(
            `
            UPDATE kot

            SET
                status = ?,
                updated_at = NOW()

            WHERE kot_id = ?
            `,
            [
                status,
                kotId
            ]
        );


        // ----------------------------------------------------
        // Update KOT item statuses
        // ----------------------------------------------------

        if (status === 'ACCEPTED') {

            await connection.query(
                `
                UPDATE kot_item

                SET
                    status = 'PREPARING',
                    started_at =
                        COALESCE(
                            started_at,
                            NOW()
                        )

                WHERE kot_id = ?

                  AND status = 'NEW'
                `,
                [kotId]
            );
        }


        if (status === 'PREPARING') {

            await connection.query(
                `
                UPDATE kot_item

                SET
                    status = 'PREPARING',
                    started_at =
                        COALESCE(
                            started_at,
                            NOW()
                        )

                WHERE kot_id = ?

                  AND status = 'NEW'
                `,
                [kotId]
            );
        }


        if (status === 'READY') {

            await connection.query(
                `
                UPDATE kot_item

                SET
                    status = 'READY',
                    ready_at =
                        COALESCE(
                            ready_at,
                            NOW()
                        )

                WHERE kot_id = ?

                  AND status IN
                  (
                    'NEW',
                    'PREPARING'
                  )
                `,
                [kotId]
            );
        }


        if (status === 'SERVED') {

            await connection.query(
                `
                UPDATE kot_item

                SET
                    status = 'SERVED',
                    served_at =
                        COALESCE(
                            served_at,
                            NOW()
                        )

                WHERE kot_id = ?

                  AND status = 'READY'
                `,
                [kotId]
            );
        }


        if (status === 'CANCELLED') {

            await connection.query(
                `
                UPDATE kot_item

                SET
                    status = 'CANCELLED'

                WHERE kot_id = ?

                  AND status NOT IN
                  (
                    'SERVED',
                    'CANCELLED'
                  )
                `,
                [kotId]
            );
        }


        await connection.commit();


        return res.json({
            success: true,

            message:
                'KOT status updated successfully',

            kotId,

            status
        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Update KOT status error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to update KOT status'
        });

    } finally {

        connection.release();
    }
};

/*
 * ============================================================
 * GET /kot/stations
 *
 * Get active kitchen stations accessible to logged-in user.
 * Used by Kitchen Display System (KDS).
 * ============================================================
 */

exports.getKitchenStations = async (
    req,
    res
) => {
  const connection =
        await db.getConnection();
    try {

        const [stations] =
            await connection.query(
                `
                SELECT
                    ks.kitchen_station_id,
                    ks.outlet_id,
                    ks.station_code,
                    ks.station_name,
                    ks.printer_id,
                    ks.display_order

                FROM kitchen_station ks

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       ks.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       ks.outlet_id

                WHERE
                    ks.is_active = TRUE

                    AND ot.company_id = ?

                    AND uo.user_id = ?

                ORDER BY
                    ks.outlet_id,
                    ks.display_order,
                    ks.kitchen_station_id
                `,
                [
                    req.user.companyId,
                    req.user.userId
                ]
            );


        return res.json({
            success: true,
            stations
        });


    } catch (error) {

        console.error(
            'Get kitchen stations error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get kitchen stations'
        });
    }
};