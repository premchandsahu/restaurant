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

        const includeInactive = req.query.includeInactive === '1' ? 1 : 0;
        const outletId = req.query.outletId ? Number(req.query.outletId) : null;
        if (outletId !== null && (!Number.isSafeInteger(outletId) || outletId <= 0)) {
          return res.status(400).json({ success: false, message: 'Invalid outletId' });
        }

        const [stations] =
            await connection.query(
                `
                SELECT
                    ks.kitchen_station_id,
                    ks.outlet_id,
                    ks.station_code,
                    ks.station_name,
                    ks.printer_id,
                    ks.display_order,
                    ks.is_active

                FROM kitchen_station ks

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       ks.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       ks.outlet_id

                WHERE
                     (? = 1 OR ks.is_active = TRUE)
                    AND ot.company_id = ?
                    AND uo.user_id = ?
                    AND (? IS NULL OR ks.outlet_id = ?)

                ORDER BY
                    ks.outlet_id,
                    ks.display_order,
                    ks.kitchen_station_id
                `,
                [
                     includeInactive,
                     req.user.companyId,
                     req.user.userId,
                     outletId,
                     outletId
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



async function kitchenStationHasOutletAccess(connection, req, outletId) {
  const [rows] = await connection.query(
    `SELECT ot.outlet_id
     FROM outlet ot
     INNER JOIN user_outlet uo ON uo.outlet_id = ot.outlet_id
     WHERE ot.outlet_id = ?
       AND ot.company_id = ?
       AND uo.user_id = ?
     LIMIT 1`,
    [outletId, req.user.companyId, req.user.userId]
  );
  return rows.length > 0;
}

function parseKitchenStationBoolean(value, fallback = true) {
  if (value === undefined || value === null) return fallback;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const text = String(value).toLowerCase();
  return text === '1' || text === 'true';
}

function parseKitchenStationPayload(body) {
  const outletId = Number(body.outletId);
  const stationCode = String(body.stationCode || '').trim();
  const stationName = String(body.stationName || '').trim();
  const displayOrder = body.displayOrder === undefined
    ? 0
    : Number(body.displayOrder);
  const printerId = body.printerId === '' || body.printerId === undefined || body.printerId === null
    ? null
    : Number(body.printerId);
  const isActive = parseKitchenStationBoolean(body.isActive, true);

  if (!Number.isSafeInteger(outletId) || outletId <= 0) {
    return { error: 'Valid outletId is required' };
  }
  if (!stationCode || stationCode.length > 50) {
    return { error: 'Station code is required and must not exceed 50 characters' };
  }
  if (!stationName || stationName.length > 100) {
    return { error: 'Station name is required and must not exceed 100 characters' };
  }
  if (!Number.isSafeInteger(displayOrder) || displayOrder < 0) {
    return { error: 'displayOrder must be a whole number 0 or greater' };
  }
  if (printerId !== null && (!Number.isSafeInteger(printerId) || printerId <= 0)) {
    return { error: 'printerId must be a positive whole number or null' };
  }

  return {
    value: {
      outletId,
      stationCode,
      stationName,
      printerId,
      displayOrder,
      isActive: isActive ? 1 : 0,
    },
  };
}

exports.createKitchenStation = async (req, res) => {
  let connection;
  try {
    const parsed = parseKitchenStationPayload(req.body || {});
    if (parsed.error) {
      return res.status(400).json({ success: false, message: parsed.error });
    }
    const station = parsed.value;
    connection = await db.getConnection();

    if (!(await kitchenStationHasOutletAccess(connection, req, station.outletId))) {
      return res.status(403).json({ success: false, message: 'Outlet access denied' });
    }

    const [result] = await connection.query(
      `INSERT INTO kitchen_station
         (outlet_id, station_code, station_name, printer_id, display_order, is_active)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        station.outletId,
        station.stationCode,
        station.stationName,
        station.printerId,
        station.displayOrder,
        station.isActive,
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Kitchen station created successfully',
      kitchenStationId: result.insertId,
    });
  } catch (error) {
    console.error('Create kitchen station error:', error);
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ success: false, message: 'A station with this code already exists' });
    }
    return res.status(500).json({ success: false, message: 'Unable to create kitchen station' });
  } finally {
    if (connection) connection.release();
  }
};

exports.updateKitchenStation = async (req, res) => {
  let connection;
  try {
    const stationId = Number(req.params.stationId);
    const parsed = parseKitchenStationPayload(req.body || {});
    if (!Number.isSafeInteger(stationId) || stationId <= 0) {
      return res.status(400).json({ success: false, message: 'Invalid stationId' });
    }
    if (parsed.error) {
      return res.status(400).json({ success: false, message: parsed.error });
    }
    const station = parsed.value;
    connection = await db.getConnection();

    if (!(await kitchenStationHasOutletAccess(connection, req, station.outletId))) {
      return res.status(403).json({ success: false, message: 'Outlet access denied' });
    }

    const [existing] = await connection.query(
      `SELECT kitchen_station_id
       FROM kitchen_station
       WHERE kitchen_station_id = ? AND outlet_id = ?
       LIMIT 1`,
      [stationId, station.outletId]
    );
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Kitchen station not found for this outlet' });
    }

    await connection.query(
      `UPDATE kitchen_station
       SET station_code = ?,
           station_name = ?,
           printer_id = ?,
           display_order = ?,
           is_active = ?
       WHERE kitchen_station_id = ? AND outlet_id = ?`,
      [
        station.stationCode,
        station.stationName,
        station.printerId,
        station.displayOrder,
        station.isActive,
        stationId,
        station.outletId,
      ]
    );

    return res.json({ success: true, message: 'Kitchen station updated successfully' });
  } catch (error) {
    console.error('Update kitchen station error:', error);
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ success: false, message: 'A station with this code already exists' });
    }
    return res.status(500).json({ success: false, message: 'Unable to update kitchen station' });
  } finally {
    if (connection) connection.release();
  }
};

exports.getMenuItemStationMappings = async (req, res) => {
  let connection;
  try {
    const outletId = Number(req.query.outletId);
    if (!Number.isSafeInteger(outletId) || outletId <= 0) {
      return res.status(400).json({ success: false, message: 'Valid outletId is required' });
    }
    connection = await db.getConnection();

    if (!(await kitchenStationHasOutletAccess(connection, req, outletId))) {
      return res.status(403).json({ success: false, message: 'Outlet access denied' });
    }

    const [mappings] = await connection.query(
      `SELECT menu_item_id, kitchen_station_id
       FROM menu_item_kitchen_station
       WHERE outlet_id = ?
       ORDER BY menu_item_id, kitchen_station_id`,
      [outletId]
    );

    return res.json({ success: true, mappings });
  } catch (error) {
    console.error('Get menu item station mappings error:', error);
    return res.status(500).json({ success: false, message: 'Unable to load menu item station mappings' });
  } finally {
    if (connection) connection.release();
  }
};

exports.saveMenuItemStationMappings = async (req, res) => {
  let connection;
  let transactionStarted = false;
  try {
    const outletId = Number(req.body?.outletId);
    const menuItemId = Number(req.params.menuItemId);
    const stationIdsRaw = req.body?.kitchenStationIds;

    if (!Number.isSafeInteger(outletId) || outletId <= 0 ||
        !Number.isSafeInteger(menuItemId) || menuItemId <= 0 ||
        !Array.isArray(stationIdsRaw)) {
      return res.status(400).json({
        success: false,
        message: 'Valid outletId, menuItemId and kitchenStationIds array are required',
      });
    }

    const stationIds = stationIdsRaw.map(Number);
    if (stationIds.some(id => !Number.isSafeInteger(id) || id <= 0) ||
        new Set(stationIds).size !== stationIds.length) {
      return res.status(400).json({ success: false, message: 'Kitchen station IDs must be valid and unique' });
    }

    connection = await db.getConnection();
    if (!(await kitchenStationHasOutletAccess(connection, req, outletId))) {
      return res.status(403).json({ success: false, message: 'Outlet access denied' });
    }

    const [items] = await connection.query(
      `SELECT menu_item_id
       FROM menu_item
       WHERE menu_item_id = ? AND outlet_id = ?
       LIMIT 1`,
      [menuItemId, outletId]
    );
    if (items.length === 0) {
      return res.status(404).json({ success: false, message: 'Menu item not found for this outlet' });
    }

    if (stationIds.length > 0) {
      const [stations] = await connection.query(
        `SELECT kitchen_station_id
         FROM kitchen_station
         WHERE outlet_id = ?
           AND is_active = TRUE
           AND kitchen_station_id IN (?)`,
        [outletId, stationIds]
      );
      if (stations.length !== stationIds.length) {
        return res.status(400).json({
          success: false,
          message: 'One or more selected stations are inactive or belong to another outlet',
        });
      }
    }

    await connection.beginTransaction();
    transactionStarted = true;

    await connection.query(
      `DELETE FROM menu_item_kitchen_station
       WHERE outlet_id = ? AND menu_item_id = ?`,
      [outletId, menuItemId]
    );

    for (const stationId of stationIds) {
      await connection.query(
        `INSERT INTO menu_item_kitchen_station
           (outlet_id, menu_item_id, kitchen_station_id)
         VALUES (?, ?, ?)`,
        [outletId, menuItemId, stationId]
      );
    }

    await connection.commit();
    transactionStarted = false;

    return res.json({
      success: true,
      message: 'Menu item kitchen station mappings saved successfully',
      outletId,
      menuItemId,
      kitchenStationIds: stationIds,
    });
  } catch (error) {
    if (connection && transactionStarted) await connection.rollback();
    console.error('Save menu item station mappings error:', error);
    return res.status(500).json({ success: false, message: 'Unable to save menu item station mappings' });
  } finally {
    if (connection) connection.release();
  }
};
