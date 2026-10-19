const db =  require('../database');
const crypto = require('crypto');


/*
 * POST /api/orders
 *
 * Creates a new restaurant order.
 *
 * Expected body:
 *
 * {
 *   "outletId": 1,
 *   "terminalId": null,
 *   "orderType": "DINE_IN",
 *   "tableId": 1,
 *   "customerId": null,
 *   "guestCount": 2,
 *   "waiterId": null,
 *   "captainId": null,
 *   "remarks": ""
 * }
 */




/*
 * ============================================================
 * POST /api/orders/:sourceOrderId/merge
 *
 * Merge SOURCE order into TARGET order.
 *
 * Example:
 * POST /api/orders/23/merge
 *
 * {
 *     "targetOrderId": 20
 * }
 *
 * Rules:
 * - Both orders must belong to same outlet
 * - Both orders must belong to same physical table
 * - Source and target must be different
 * - Neither order may be BILLED, PAID, CANCELLED, VOID or MERGED
 * - Target remains the active order
 * - Source becomes MERGED
 * - Source logical table becomes AVAILABLE
 * - Physical table remains OCCUPIED
 * ============================================================
 */

/*
 * ============================================================
 * POST /api/orders/:sourceOrderId/merge
 *
 * Merge SOURCE order into TARGET order.
 *
 * Example:
 * POST /api/orders/23/merge
 *
 * {
 *     "targetOrderId": 20
 * }
 *
 * IMPORTANT:
 * order_item primary key is:
 *     (order_id, line_no)
 *
 * Therefore source order items are first assigned temporary
 * negative line numbers, then moved to the target order with
 * new sequential line numbers.
 *
 * order_item_id is NEVER changed.
 *
 * This preserves:
 *
 * order_item_modifier.order_item_id
 * kot_item.order_item_id
 *
 * ============================================================
 */


// ============================================================
// GET /api/orders/qr/pending
//
// Returns QR orders having one or more order items that are
// still OPEN and therefore waiting to be sent to kitchen.
//
// This supports incremental QR ordering:
//
// First order:
//   4 Roti -> OPEN -> notification -> KOT -> SENT_TO_KITCHEN
//
// Later customer adds:
//   2 Roti -> new OPEN item -> notification -> KOT
//
// No existing KOT logic is changed.
// ============================================================

exports.getPendingQROrders = async (req, res) => {
    const connection = await db.getConnection();

    try {

        const outletId = Number(req.query.outletId);

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const [orders] = await connection.query(
            `
            SELECT

                o.order_id,
                o.order_uuid,
                o.order_no,

                o.outlet_id,

                o.order_type,
                o.order_source,
                o.order_status,

                o.table_id,
                rt.table_code,
                rt.table_name,

                o.logical_table_id,
                lt.logical_code,
                lt.logical_name,

                o.customer_session_id,

                cos.customer_name,
                cos.customer_phone,

                o.guest_count,

                o.grand_total,
                o.paid_amount,
                o.balance_amount,

                COUNT(oi.order_item_id) AS pending_line_count,

                COALESCE(
                    SUM(oi.qty),
                    0
                ) AS pending_item_qty,

                MIN(oi.created_at) AS first_pending_at,

                MAX(oi.created_at) AS last_pending_at

            FROM orders o

            INNER JOIN outlet ot
                ON ot.outlet_id = o.outlet_id

            INNER JOIN user_outlet uo
                ON uo.outlet_id = o.outlet_id
               AND uo.user_id = ?

            INNER JOIN restaurant_table rt
                ON rt.table_id = o.table_id

            LEFT JOIN logical_table lt
                ON lt.logical_table_id = o.logical_table_id

            LEFT JOIN customer_order_session cos
                ON cos.customer_session_id =
                   o.customer_session_id

            INNER JOIN order_item oi
                ON oi.order_id = o.order_id
               AND oi.status = 'OPEN'

            WHERE o.outlet_id = ?

              AND ot.company_id = ?

              AND o.order_type = 'QR_ORDER'

              AND o.order_source = 'QR'

              AND o.order_status NOT IN
              (
                  'PAID',
                  'CANCELLED',
                  'VOID',
                  'MERGED',
                  'BILLED'
              )

            GROUP BY

                o.order_id,
                o.order_uuid,
                o.order_no,

                o.outlet_id,

                o.order_type,
                o.order_source,
                o.order_status,

                o.table_id,
                rt.table_code,
                rt.table_name,

                o.logical_table_id,
                lt.logical_code,
                lt.logical_name,

                o.customer_session_id,

                cos.customer_name,
                cos.customer_phone,

                o.guest_count,

                o.grand_total,
                o.paid_amount,
                o.balance_amount

            ORDER BY
                first_pending_at ASC
            `,

            [
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        return res.json({
            success: true,
            outletId,
            count: orders.length,
            pendingOrders: orders
        });

    } catch (error) {

        console.error(
            'Get pending QR orders error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get pending QR orders'
        });

    } finally {

        connection.release();
    }
};

exports.mergeOrders = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const sourceOrderId =
            Number(req.params.sourceOrderId);

        const targetOrderId =
            Number(req.body.targetOrderId);


        // ----------------------------------------------------
        // Validate IDs
        // ----------------------------------------------------

        if (!sourceOrderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid sourceOrderId'
            });

        }

        if (!targetOrderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid targetOrderId'
            });

        }

        if (sourceOrderId === targetOrderId) {

            return res.status(400).json({
                success: false,
                message:
                    'Source and target orders cannot be the same'
            });

        }


        await connection.beginTransaction();


        // ----------------------------------------------------
        // Lock orders in deterministic order
        // ----------------------------------------------------

        const firstOrderId =
            Math.min(
                sourceOrderId,
                targetOrderId
            );

        const secondOrderId =
            Math.max(
                sourceOrderId,
                targetOrderId
            );


        const [orders] =
            await connection.query(
                `
                SELECT
                    o.*,

                    rt.table_code,
                    rt.table_name,

                    lt.logical_code,
                    lt.logical_name

                FROM orders o

                LEFT JOIN restaurant_table rt
                    ON rt.table_id = o.table_id

                LEFT JOIN logical_table lt
                    ON lt.logical_table_id =
                       o.logical_table_id

                INNER JOIN outlet ot
                    ON ot.outlet_id = o.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = o.outlet_id

                WHERE o.order_id IN (?, ?)

                  AND ot.company_id = ?

                  AND uo.user_id = ?

                ORDER BY o.order_id

                FOR UPDATE
                `,
                [
                    firstOrderId,
                    secondOrderId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        // ----------------------------------------------------
        // Both orders must exist
        // ----------------------------------------------------

        if (orders.length !== 2) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message:
                    'Source or target order not found'
            });

        }


        const sourceOrder =
            orders.find(
                row =>
                    Number(row.order_id) ===
                    sourceOrderId
            );

        const targetOrder =
            orders.find(
                row =>
                    Number(row.order_id) ===
                    targetOrderId
            );


        if (!sourceOrder || !targetOrder) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message:
                    'Source or target order not found'
            });

        }


        // ----------------------------------------------------
        // Same outlet
        // ----------------------------------------------------

        if (
            Number(sourceOrder.outlet_id) !==
            Number(targetOrder.outlet_id)
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Orders must belong to the same outlet'
            });

        }


        // ----------------------------------------------------
        // Same physical table
        // ----------------------------------------------------

        if (
            Number(sourceOrder.table_id) !==
            Number(targetOrder.table_id)
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Orders must belong to the same table'
            });

        }


        // ----------------------------------------------------
        // Status validation
        // ----------------------------------------------------

        const blockedStatuses = [
            'BILLED',
            'PAID',
            'CANCELLED',
            'VOID',
            'MERGED'
        ];


        if (
            blockedStatuses.includes(
                sourceOrder.order_status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot merge source order with status ${sourceOrder.order_status}`
            });

        }


        if (
            blockedStatuses.includes(
                targetOrder.order_status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot merge into target order with status ${targetOrder.order_status}`
            });

        }


        // ----------------------------------------------------
        // Source cannot already be merged
        // ----------------------------------------------------

        if (sourceOrder.merged_into_order_id) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Source order is already merged'
            });

        }


        // ----------------------------------------------------
        // Get source order items
        //
        // Lock all source items.
        // ----------------------------------------------------

        const [sourceItems] =
            await connection.query(
                `
                SELECT
                    order_item_id,
                    order_id,
                    line_no

                FROM order_item

                WHERE order_id = ?

                ORDER BY line_no

                FOR UPDATE
                `,
                [sourceOrderId]
            );


        // ----------------------------------------------------
        // Get current target maximum line number
        // ----------------------------------------------------

        const [targetLineRows] =
            await connection.query(
                `
                SELECT
                    COALESCE(
                        MAX(line_no),
                        0
                    ) AS max_line_no

                FROM order_item

                WHERE order_id = ?

                FOR UPDATE
                `,
                [targetOrderId]
            );


        let nextLineNo =
            Number(
                targetLineRows[0].max_line_no || 0
            ) + 1;


        // ----------------------------------------------------
        // Temporarily move source line numbers to negative
        //
        // This prevents primary-key collisions.
        //
        // Example:
        //
        // (23,1)
        // (23,2)
        //
        // becomes:
        //
        // (23,-1)
        // (23,-2)
        // ----------------------------------------------------

        if (sourceItems.length > 0) {

            await connection.query(
                `
                UPDATE order_item

                SET
                    line_no = -line_no

                WHERE order_id = ?
                `,
                [sourceOrderId]
            );

        }


        // ----------------------------------------------------
        // Move each source item to target
        //
        // order_item_id remains unchanged.
        // ----------------------------------------------------

        for (const item of sourceItems) {

            const newLineNo =
                nextLineNo++;

            await connection.query(
                `
                UPDATE order_item

                SET
                    order_id = ?,
                    line_no = ?

                WHERE order_item_id = ?

                  AND order_id = ?
                `,
                [
                    targetOrderId,
                    newLineNo,
                    item.order_item_id,
                    sourceOrderId
                ]
            );

        }


        // ----------------------------------------------------
        // Move KOT headers to target
        //
        // kot_item.order_item_id remains unchanged.
        // ----------------------------------------------------

        await connection.query(
            `
            UPDATE kot

            SET
                order_id = ?,
                updated_at = NOW()

            WHERE order_id = ?
            `,
            [
                targetOrderId,
                sourceOrderId
            ]
        );


        // ----------------------------------------------------
        // Mark source order as MERGED
        // ----------------------------------------------------

        await connection.query(
            `
            UPDATE orders

            SET
                order_status = 'MERGED',

                merged_into_order_id = ?,

                updated_by = ?,

                updated_at = NOW()

            WHERE order_id = ?
            `,
            [
                targetOrderId,
                req.user.userId,
                sourceOrderId
            ]
        );


        // ----------------------------------------------------
        // Release source logical table
        // ----------------------------------------------------

        if (sourceOrder.logical_table_id) {

            await connection.query(
                `
                UPDATE logical_table

                SET
                    status = 'AVAILABLE',

                    updated_at = NOW()

                WHERE logical_table_id = ?
                `,
                [
                    sourceOrder.logical_table_id
                ]
            );

        }


        // ----------------------------------------------------
        // Keep target logical table occupied
        // ----------------------------------------------------

        if (targetOrder.logical_table_id) {

            await connection.query(
                `
                UPDATE logical_table

                SET
                    status = 'OCCUPIED',

                    updated_at = NOW()

                WHERE logical_table_id = ?
                `,
                [
                    targetOrder.logical_table_id
                ]
            );

        }


        // ----------------------------------------------------
        // Physical table remains occupied
        // ----------------------------------------------------

        await connection.query(
            `
            UPDATE restaurant_table

            SET
                status = 'OCCUPIED'

            WHERE table_id = ?

              AND outlet_id = ?
            `,
            [
                targetOrder.table_id,
                targetOrder.outlet_id
            ]
        );


        // ----------------------------------------------------
        // Recalculate target order
        // ----------------------------------------------------

        await recalculateOrder(
            connection,
            targetOrderId,
            req.user.userId
        );


        // ----------------------------------------------------
        // Commit transaction
        // ----------------------------------------------------

        await connection.commit();


        // ----------------------------------------------------
        // Return updated target order
        // ----------------------------------------------------

        return exports.getOrder(
            {
                ...req,

                params: {
                    orderId: targetOrderId
                }
            },
            res
        );


    } catch (error) {

        await connection.rollback();

        console.error(
            'Merge orders error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to merge orders'
        });

    } finally {

        connection.release();

    }
};

/*
 * ============================================================
 * POST /api/orders/:orderId/transfer-table
 *
 * Transfer one logical order from one physical table
 * to another physical table.
 *
 * Example:
 * T01A on Table 1
 *        ↓
 * T05 on Table 5
 * ============================================================
 */

exports.transferOrderTable = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const orderId = Number(req.params.orderId);
        const newTableId = Number(req.body.newTableId);

        if (!orderId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }

        if (!newTableId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid newTableId'
            });
        }

        await connection.beginTransaction();

        // --------------------------------------------------
        // 1. Lock order and verify user access
        // --------------------------------------------------

        const [orders] = await connection.query(
            `
            SELECT
                o.*,
                rt.table_code AS old_table_code,
                rt.table_name AS old_table_name
            FROM orders o

            LEFT JOIN restaurant_table rt
                ON rt.table_id = o.table_id

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

        // --------------------------------------------------
        // 2. Validate order status
        // --------------------------------------------------

        if (
            [
                'PAID',
                'CANCELLED',
                'VOID'
            ].includes(order.order_status)
        ) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot transfer ${order.order_status} order`
            });
        }

        // --------------------------------------------------
        // 3. Same table?
        // --------------------------------------------------

        if (Number(order.table_id) === newTableId) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'Order is already on this table'
            });
        }

        // --------------------------------------------------
        // 4. Lock destination table
        // --------------------------------------------------

        const [tables] = await connection.query(
            `
            SELECT
                table_id,
                table_code,
                table_name,
                status
            FROM restaurant_table

            WHERE table_id = ?
              AND outlet_id = ?
              AND is_active = TRUE

            FOR UPDATE
            `,
            [
                newTableId,
                order.outlet_id
            ]
        );

        if (tables.length === 0) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Destination table not found'
            });
        }

        const destinationTable = tables[0];

        if (
            ![
                'AVAILABLE',
                'OCCUPIED'
            ].includes(destinationTable.status)
        ) {
            await connection.rollback();

            return res.status(409).json({
                success: false,
                message:
                    `Destination table is currently ${destinationTable.status}`
            });
        }

        // --------------------------------------------------
        // 5. Get/create logical table on destination
        // --------------------------------------------------
        //
        // This reuses the same logic already used by
        // createOrder().
        //

        const logicalTables = await getOrCreateLogicalTable(
            connection,
            newTableId,
            destinationTable.table_code
        );

        // --------------------------------------------------
        // 6. Update order
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE orders

            SET
                table_id = ?,
                logical_table_id = ?,
                updated_by = ?,
                updated_at = NOW()

            WHERE order_id = ?
            `,
            [
                newTableId,
                logicalTables.logicalTableId,
                req.user.userId,
                orderId
            ]
        );

        // --------------------------------------------------
        // 7. Release old logical table
        // --------------------------------------------------

        if (order.logical_table_id) {

            await connection.query(
                `
                UPDATE logical_table

                SET
                    status = 'AVAILABLE',
                    updated_at = NOW()

                WHERE logical_table_id = ?
                `,
                [
                    order.logical_table_id
                ]
            );
        }

        // --------------------------------------------------
        // 8. Determine whether old physical table is free
        // --------------------------------------------------

        const [oldActiveOrders] =
            await connection.query(
                `
                SELECT COUNT(*) AS cnt

                FROM orders

                WHERE outlet_id = ?
                  AND table_id = ?
                  AND order_id <> ?

                  AND order_status NOT IN
                  (
                      'PAID',
                      'CANCELLED',
                      'VOID',
                      'MERGED'
                  )
                `,
                [
                    order.outlet_id,
                    order.table_id,
                    orderId
                ]
            );

        const oldActiveCount =
            Number(oldActiveOrders[0].cnt || 0);

        if (oldActiveCount === 0 && order.table_id) {

            await connection.query(
                `
                UPDATE restaurant_table

                SET
                    status = 'AVAILABLE'

                WHERE table_id = ?
                  AND outlet_id = ?
                `,
                [
                    order.table_id,
                    order.outlet_id
                ]
            );

        } else if (order.table_id) {

            await connection.query(
                `
                UPDATE restaurant_table

                SET
                    status = 'OCCUPIED'

                WHERE table_id = ?
                  AND outlet_id = ?
                `,
                [
                    order.table_id,
                    order.outlet_id
                ]
            );
        }

        // --------------------------------------------------
        // 9. Destination table becomes occupied
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE restaurant_table

            SET
                status = 'OCCUPIED'

            WHERE table_id = ?
              AND outlet_id = ?
            `,
            [
                newTableId,
                order.outlet_id
            ]
        );

        // --------------------------------------------------
        // 10. Commit
        // --------------------------------------------------

        await connection.commit();

        // --------------------------------------------------
        // 11. Return updated order
        // --------------------------------------------------

        return exports.getOrder(
            {
                ...req,
                params: {
                    orderId
                }
            },
            res
        );

    } catch (error) {

        await connection.rollback();

        console.error(
            'Transfer table error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to transfer order'
        });

    } finally {
        connection.release();
    }
};

async function recalculateOrder(
    connection,
    orderId,
    userId
) {
    // --------------------------------------------------
    // 1. Get order
    // --------------------------------------------------

    const [orders] = await connection.query(
        `
        SELECT *
        FROM orders
        WHERE order_id = ?
        FOR UPDATE
        `,
        [orderId]
    );

    if (orders.length === 0) {
        throw new Error('Order not found');
    }

    const order = orders[0];


    // --------------------------------------------------
    // 2. Get order items
    // --------------------------------------------------

    const [items] = await connection.query(
        `
        SELECT
            oi.*,

            mi.tax_group_id AS item_tax_group_id,

            mv.tax_group_id AS variant_tax_group_id

        FROM order_item oi

        INNER JOIN menu_item mi
            ON mi.menu_item_id = oi.menu_item_id

        LEFT JOIN menu_item_variant mv
            ON mv.variant_id = oi.variant_id

        WHERE oi.order_id = ?

        ORDER BY oi.line_no
        `,
        [orderId]
    );


    // --------------------------------------------------
    // 3. Remove previous order tax records
    // --------------------------------------------------

    await connection.query(
        `
        DELETE FROM order_tax
        WHERE order_id = ?
        `,
        [orderId]
    );


    // --------------------------------------------------
    // 4. Remove previous item tax amounts
    //
    // We will recalculate them from scratch.
    // --------------------------------------------------

    await connection.query(
        `
        UPDATE order_item

        SET
            tax_amount = 0,
            net_amount = taxable_amount

        WHERE order_id = ?
        `,
        [orderId]
    );


    let subtotal = 0;
    let itemDiscount = 0;


    /*
     * Tax buckets.
     *
     * Example:
     *
     * {
     *   1: {
     *       taxableAmount: 1000
     *   },
     *
     *   2: {
     *       taxableAmount: 500
     *   }
     * }
     */

    const taxBuckets = {};


    // --------------------------------------------------
    // 5. Process each order item
    // --------------------------------------------------

    for (const item of items) {

        const qty =
            Number(item.qty || 0);

        const rate =
            Number(item.rate || 0);


        // ----------------------------------------------
        // Item base amount
        // ----------------------------------------------

        const baseAmount =
            rate * qty;


        // ----------------------------------------------
        // Modifier amount
        //
        // order_item_modifier.amount is the amount
        // for one parent item quantity.
        // ----------------------------------------------

        const [modifiers] =
            await connection.query(
                `
                SELECT
                    oim.*,

                    mo.tax_group_id AS modifier_tax_group_id

                FROM order_item_modifier oim

                INNER JOIN modifier_option mo
                    ON mo.modifier_option_id =
                       oim.modifier_option_id

                WHERE oim.order_item_id = ?
                `,
                [item.order_item_id]
            );


        let modifierAmount = 0;


        /*
         * Keep track of modifier taxable amounts
         * separately because a modifier may have
         * a different tax group.
         */

        const modifierTaxBuckets = {};


        for (const modifier of modifiers) {

            const modifierQty =
                Number(modifier.qty || 0);

            const modifierRate =
                Number(modifier.rate || 0);


            const amount =
                modifierRate *
                modifierQty;


            modifierAmount +=
                amount * qty;


            // ------------------------------------------
            // Modifier tax group
            // ------------------------------------------

            const modifierTaxGroupId =
                modifier.modifier_tax_group_id ||
                item.variant_tax_group_id ||
                item.item_tax_group_id;


            if (modifierTaxGroupId) {

                if (!modifierTaxBuckets[
                    modifierTaxGroupId
                ]) {

                    modifierTaxBuckets[
                        modifierTaxGroupId
                    ] = 0;
                }


                modifierTaxBuckets[
                    modifierTaxGroupId
                ] += amount * qty;
            }
        }


        // ----------------------------------------------
        // Item gross
        // ----------------------------------------------

        const grossAmount =
            baseAmount +
            modifierAmount;


        // ----------------------------------------------
        // Item discount
        // ----------------------------------------------

        const discountAmount =
            Number(item.discount_amount || 0);


        const taxableAmount =
            Math.max(
                grossAmount - discountAmount,
                0
            );


        subtotal +=
            grossAmount;

        itemDiscount +=
            discountAmount;


        // ----------------------------------------------
        // Determine item tax group
        //
        // Priority:
        //
        // Variant
        // Menu item
        // No tax
        // ----------------------------------------------

        const itemTaxGroupId =
            item.variant_tax_group_id ||
            item.item_tax_group_id;


        /*
         * Amount after discount which belongs
         * to the item itself.
         *
         * If modifiers use a different tax group,
         * their taxable amount will be handled
         * separately below.
         */

        const modifierTotal =
            Object.values(
                modifierTaxBuckets
            ).reduce(
                (sum, amount) =>
                    sum + amount,
                0
            );


        const itemOnlyTaxable =
            Math.max(
                taxableAmount -
                modifierTotal,
                0
            );


        // ----------------------------------------------
        // Add item amount to tax bucket
        // ----------------------------------------------

        if (itemTaxGroupId &&
            itemOnlyTaxable > 0) {

            if (!taxBuckets[itemTaxGroupId]) {

                taxBuckets[itemTaxGroupId] = {
                    taxableAmount: 0
                };
            }


            taxBuckets[itemTaxGroupId]
                .taxableAmount +=
                itemOnlyTaxable;
        }


        // ----------------------------------------------
        // Add modifier amounts to tax buckets
        // ----------------------------------------------

        for (
            const [
                taxGroupId,
                amount
            ]
            of Object.entries(
                modifierTaxBuckets
            )
        ) {

            if (!taxBuckets[taxGroupId]) {

                taxBuckets[taxGroupId] = {
                    taxableAmount: 0
                };
            }


            taxBuckets[taxGroupId]
                .taxableAmount += amount;
        }


        // ----------------------------------------------
        // Update item taxable amount
        // ----------------------------------------------

        await connection.query(
            `
            UPDATE order_item

            SET
                gross_amount = ?,
                taxable_amount = ?,
                tax_amount = 0,
                net_amount = ?

            WHERE order_item_id = ?
            `,
            [
                grossAmount,
                taxableAmount,
                taxableAmount,
                item.order_item_id
            ]
        );
    }


    // --------------------------------------------------
    // 6. Get bill-level discount
    // --------------------------------------------------

    const [discountRows] =
        await connection.query(
            `
            SELECT
                COALESCE(
                    SUM(discount_amount),
                    0
                ) AS bill_discount

            FROM order_discount

            WHERE order_id = ?
            `,
            [orderId]
        );


    const billDiscount =
        Number(
            discountRows[0].bill_discount || 0
        );


    // --------------------------------------------------
    // 7. Total taxable amount BEFORE bill discount
    // --------------------------------------------------

    const taxableBeforeBillDiscount =
        Math.max(
            subtotal -
            itemDiscount,
            0
        );


    /*
     * Bill discount must be distributed across
     * tax groups proportionately.
     */

    const billDiscountAmount =
        Math.min(
            billDiscount,
            taxableBeforeBillDiscount
        );


    const taxBaseAfterBillDiscount =
        Math.max(
            taxableBeforeBillDiscount -
            billDiscountAmount,
            0
        );


    // --------------------------------------------------
    // 8. Apply bill discount proportionately
    // --------------------------------------------------

    let totalTaxableFromBuckets = 0;

    for (const bucket
        of Object.values(taxBuckets)) {

        totalTaxableFromBuckets +=
            bucket.taxableAmount;
    }


    if (totalTaxableFromBuckets > 0 &&
        billDiscountAmount > 0) {

        for (const bucket
            of Object.values(taxBuckets)) {

            const proportion =
                bucket.taxableAmount /
                totalTaxableFromBuckets;

            const allocatedDiscount =
                billDiscountAmount *
                proportion;

            bucket.taxableAmount =
                Math.max(
                    bucket.taxableAmount -
                    allocatedDiscount,
                    0
                );
        }
    }


    // --------------------------------------------------
    // 9. Calculate tax
    // --------------------------------------------------

    let totalTax = 0;


    /*
     * Keep item tax allocation.
     *
     * First calculate tax at tax-group level.
     */

    const taxGroupTotals = {};


    for (const [
        taxGroupId,
        bucket
    ] of Object.entries(taxBuckets)) {

        const [rates] =
            await connection.query(
                `
                SELECT
                    tax_rate_id,
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


        taxGroupTotals[taxGroupId] = {
            taxableAmount:
                bucket.taxableAmount,

            taxAmount: 0
        };


        for (const taxRate of rates) {

            const rate =
                Number(taxRate.rate || 0);

            const taxable =
                Number(
                    bucket.taxableAmount
                );


            let taxAmount;


            if (taxRate.is_inclusive) {

                /*
                 * Inclusive tax:
                 *
                 * tax = gross × rate / (100 + rate)
                 */

                taxAmount =
                    taxable *
                    rate /
                    (100 + rate);

            } else {

                /*
                 * Exclusive tax.
                 */

                taxAmount =
                    taxable *
                    rate /
                    100;
            }


            taxAmount =
                Number(
                    taxAmount.toFixed(2)
                );


            taxGroupTotals[taxGroupId]
                .taxAmount +=
                taxAmount;


            totalTax +=
                taxAmount;


            // ------------------------------------------
            // Save tax snapshot
            // ------------------------------------------

            await connection.query(
                `
                INSERT INTO order_tax
                (
                    order_id,
                    tax_rate_id,
                    tax_name,
                    tax_type,
                    rate,
                    taxable_amount,
                    tax_amount
                )

                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?
                )
                `,
                [
                    orderId,

                    taxRate.tax_rate_id,

                    taxRate.tax_name,

                    taxRate.tax_type,

                    taxRate.rate,

                    taxable,

                    taxAmount
                ]
            );
        }
    }


// --------------------------------------------------
// 10. Update item tax amounts accurately
// --------------------------------------------------

for (const item of items) {

    const qty =
        Number(item.qty || 0);

    const itemTaxGroupId =
        item.variant_tax_group_id ||
        item.item_tax_group_id;


    // ----------------------------------------------
    // Get modifiers
    // ----------------------------------------------

    const [modifiers] =
        await connection.query(
            `
            SELECT
                oim.qty,
                oim.rate,
                oim.amount,

                mo.tax_group_id
                    AS modifier_tax_group_id

            FROM order_item_modifier oim

            INNER JOIN modifier_option mo
                ON mo.modifier_option_id =
                   oim.modifier_option_id

            WHERE oim.order_item_id = ?
            `,
            [item.order_item_id]
        );


    // ----------------------------------------------
    // Taxable amounts by tax group
    // ----------------------------------------------

    const itemTaxGroups = {};


    const itemGross =
        Number(item.rate || 0) *
        qty;


    const itemDiscountAmount =
        Number(
            item.discount_amount || 0
        );


    /*
     * We initially allocate item discount
     * against the complete item line.
     */

    let modifierGross = 0;


    for (const modifier of modifiers) {

        const modifierAmount =
            Number(modifier.amount || 0) *
            qty;


        modifierGross +=
            modifierAmount;


        const taxGroupId =
            modifier.modifier_tax_group_id ||
            itemTaxGroupId;


        if (!taxGroupId) {
            continue;
        }


        if (!itemTaxGroups[taxGroupId]) {

            itemTaxGroups[taxGroupId] = 0;
        }


        itemTaxGroups[taxGroupId] +=
            modifierAmount;
    }


    const itemOnlyGross =
        itemGross;


    if (itemTaxGroupId) {

        if (!itemTaxGroups[itemTaxGroupId]) {

            itemTaxGroups[itemTaxGroupId] = 0;
        }


        itemTaxGroups[itemTaxGroupId] +=
            itemOnlyGross;
    }


    const totalGross =
        itemGross +
        modifierGross;


    /*
     * Allocate item discount proportionately.
     */

    for (const taxGroupId
        of Object.keys(itemTaxGroups)) {

        const groupGross =
            itemTaxGroups[taxGroupId];


        const proportion =
            totalGross > 0
                ? groupGross / totalGross
                : 0;


        const allocatedDiscount =
            itemDiscountAmount *
            proportion;


        itemTaxGroups[taxGroupId] =
            Math.max(
                groupGross -
                allocatedDiscount,
                0
            );
    }


    // ----------------------------------------------
    // Calculate tax
    // ----------------------------------------------

    let itemTax = 0;


    for (const [
        taxGroupId,
        taxable
    ] of Object.entries(itemTaxGroups)) {

        const [rates] =
            await connection.query(
                `
                SELECT
                    rate,
                    is_inclusive

                FROM tax_rate

                WHERE tax_group_id = ?

                  AND is_active = TRUE
                `,
                [taxGroupId]
            );


        for (const taxRate of rates) {

            const rate =
                Number(taxRate.rate || 0);


            let taxAmount;


            if (taxRate.is_inclusive) {

                taxAmount =
                    taxable *
                    rate /
                    (100 + rate);

            } else {

                taxAmount =
                    taxable *
                    rate /
                    100;
            }


            itemTax +=
                taxAmount;
        }
    }


    /*
     * Round only after all tax components
     * have been calculated.
     */

    itemTax =
        Number(
            itemTax.toFixed(2)
        );


    const itemTaxable =
        Number(
            item.taxable_amount || 0
        );


    const itemNet =
        itemTaxable +
        itemTax;


    await connection.query(
        `
        UPDATE order_item

        SET
            tax_amount = ?,
            net_amount = ?

        WHERE order_item_id = ?
        `,
        [
            itemTax,
            itemNet,
            item.order_item_id
        ]
    );
}
    /*
     * To avoid incorrectly assigning a different
     * tax group's amount to an item, calculate
     * item tax using its effective tax group.
     *
     * This is done from the current taxable amount.
     */

    for (const item of items) {

        const itemTaxGroupId =
            item.variant_tax_group_id ||
            item.item_tax_group_id;


        if (!itemTaxGroupId) {

            continue;
        }


        const [rates] =
            await connection.query(
                `
                SELECT
                    rate,
                    is_inclusive

                FROM tax_rate

                WHERE tax_group_id = ?

                  AND is_active = TRUE
                `,
                [itemTaxGroupId]
            );


        const itemTaxable =
            Number(
                item.taxable_amount || 0
            );


        let itemTax = 0;


        for (const rateRow of rates) {

            const rate =
                Number(rateRow.rate || 0);


            if (rateRow.is_inclusive) {

                itemTax +=
                    itemTaxable *
                    rate /
                    (100 + rate);

            } else {

                itemTax +=
                    itemTaxable *
                    rate /
                    100;
            }
        }


        itemTax =
            Number(
                itemTax.toFixed(2)
            );


        const itemNet =
            itemTaxable +
            itemTax;


        await connection.query(
            `
            UPDATE order_item

            SET
                tax_amount = ?,
                net_amount = ?

            WHERE order_item_id = ?
            `,
            [
                itemTax,
                itemNet,
                item.order_item_id
            ]
        );
    }


    // --------------------------------------------------
    // 11. Rounding
    // --------------------------------------------------

    const unroundedTotal =
        taxBaseAfterBillDiscount +
        totalTax;


    const grandTotal =
        Math.round(
            unroundedTotal
        );


    const roundingAmount =
        Number(
            (
                grandTotal -
                unroundedTotal
            ).toFixed(2)
        );


    // --------------------------------------------------
    // 12. Existing payments
    // --------------------------------------------------

    const [payments] =
        await connection.query(
            `
            SELECT
                COALESCE(
                    SUM(amount),
                    0
                ) AS paid_amount

            FROM order_payment

            WHERE order_id = ?

              AND status = 'SUCCESS'
            `,
            [orderId]
        );


    const paidAmount =
        Number(
            payments[0].paid_amount || 0
        );


    const balanceAmount =
        Number(
            (
                grandTotal -
                paidAmount
            ).toFixed(2)
        );


    // --------------------------------------------------
    // 13. Update order
    // --------------------------------------------------

    await connection.query(
        `
        UPDATE orders

        SET
            subtotal = ?,

            item_discount = ?,

            bill_discount = ?,

            taxable_amount = ?,

            tax_amount = ?,

            rounding_amount = ?,

            grand_total = ?,

            paid_amount = ?,

            balance_amount = ?,

            updated_by = ?

        WHERE order_id = ?
        `,
        [
            subtotal,

            itemDiscount,

            billDiscountAmount,

            taxBaseAfterBillDiscount,

            totalTax,

            roundingAmount,

            grandTotal,

            paidAmount,

            balanceAmount,

            userId,

            orderId
        ]
    );
}
exports.recalculateOrder = recalculateOrder;

exports.applyOrderDiscount = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const orderId =
            Number(req.params.orderId);

        const {
            discountId = null,
            discountType,
            discountValue
        } = req.body;


        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }


        if (!['PERCENT', 'AMOUNT']
            .includes(discountType)) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid discountType'
            });
        }


        const value =
            Number(discountValue);


        if (!value || value < 0) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid discountValue'
            });
        }


        await connection.beginTransaction();


        // --------------------------------------
        // Get order
        // --------------------------------------

        const [orders] =
            await connection.query(
                `
                SELECT *
                FROM orders
                WHERE order_id = ?
                FOR UPDATE
                `,
                [orderId]
            );


        if (orders.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }


        const order =
            orders[0];


        // --------------------------------------
        // Calculate current subtotal
        // --------------------------------------

        const [items] =
            await connection.query(
                `
                SELECT
                    COALESCE(
                        SUM(gross_amount),
                        0
                    ) AS subtotal

                FROM order_item

                WHERE order_id = ?

                  AND status NOT IN
                  (
                    'CANCELLED',
                    'VOID'
                  )
                `,
                [orderId]
            );


        const subtotal =
            Number(items[0].subtotal || 0);


        // --------------------------------------
        // If discount master supplied
        // --------------------------------------

        let discountName =
            'Manual Discount';


        let maxDiscountAmount =
            null;

        let minBillAmount =
            null;

        let requiresApproval =
            false;


        if (discountId) {

            const [discounts] =
                await connection.query(
                    `
                    SELECT
                        discount_id,
                        discount_name,
                        discount_type,
                        discount_value,
                        max_discount_amount,
                        min_bill_amount,
                        requires_approval

                    FROM discount

                    WHERE discount_id = ?
                      AND outlet_id = ?
                      AND is_active = TRUE

                    LIMIT 1
                    `,
                    [
                        discountId,
                        order.outlet_id
                    ]
                );


            if (discounts.length === 0) {

                await connection.rollback();

                return res.status(404).json({
                    success: false,
                    message:
                        'Discount not found'
                });
            }


            const discount =
                discounts[0];


            discountName =
                discount.discount_name;

            maxDiscountAmount =
                discount.max_discount_amount;

            minBillAmount =
                discount.min_bill_amount;

            requiresApproval =
                discount.requires_approval;


            if (discount.discount_type !==
                discountType) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,
                    message:
                        'Discount type does not match'
                });
            }
        }


        // --------------------------------------
        // Minimum bill
        // --------------------------------------

        if (
            minBillAmount !== null &&
            subtotal < Number(minBillAmount)
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Minimum bill amount not reached'
            });
        }


        // --------------------------------------
        // Calculate discount
        // --------------------------------------

        let discountAmount;


        if (discountType === 'PERCENT') {

            discountAmount =
                subtotal *
                value /
                100;

        } else {

            discountAmount =
                value;
        }


        // --------------------------------------
        // Maximum discount
        // --------------------------------------

        if (
            maxDiscountAmount !== null &&
            discountAmount >
                Number(maxDiscountAmount)
        ) {

            discountAmount =
                Number(maxDiscountAmount);
        }


        // Cannot exceed subtotal

        discountAmount =
            Math.min(
                discountAmount,
                subtotal
            );


        // --------------------------------------
        // Remove previous bill discounts
        // --------------------------------------

        await connection.query(
            `
            DELETE FROM order_discount
            WHERE order_id = ?
            `,
            [orderId]
        );


        // --------------------------------------
        // Insert discount snapshot
        // --------------------------------------

        await connection.query(
            `
            INSERT INTO order_discount
            (
                order_id,
                discount_id,
                discount_name,
                discount_type,
                discount_value,
                discount_amount,
                approved_by
            )

            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?
            )
            `,
            [
                orderId,

                discountId,

                discountName,

                discountType,

                value,

                discountAmount,

                requiresApproval
                    ? null
                    : req.user.userId
            ]
        );


        // --------------------------------------
        // Recalculate
        // --------------------------------------

        /*
         * For the next iteration, we'll make
         * recalculateOrder() read the current
         * order_discount record.
         */

        await recalculateOrder(
            connection,
            orderId,
            req.user.userId
        );


        await connection.commit();


        return exports.getOrder(
            {
                ...req,
                params: {
                    orderId
                }
            },
            res
        );


    } catch (error) {

        await connection.rollback();

        console.error(
            'Apply discount error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to apply discount'
        });

    } finally {

        connection.release();
    }
};


/**
 * Internal helper to add an item to an order.
 *
 * IMPORTANT:
 * - Caller must already have an active transaction.
 * - Does NOT begin transaction.
 * - Does NOT commit transaction.
 * - Does NOT rollback transaction.
 * - Does NOT send HTTP response.
 */
async function addOrderItemInternal(
    connection,
    {
        orderId,
        menuItemId,
        variantId = null,
        qty,
        specialInstruction = null,
        modifiers = [],

        userId
    }
) {

    // -----------------------------------------
    // Validation
    // -----------------------------------------

    if (!orderId) {
        throw new Error('Invalid orderId');
    }

    if (!menuItemId) {
        throw new Error('menuItemId is required');
    }

    const quantity = Number(qty);

    if (!quantity || quantity <= 0) {
        throw new Error(
            'qty must be greater than zero'
        );
    }

    if (!Array.isArray(modifiers)) {
        throw new Error(
            'modifiers must be an array'
        );
    }


    // -----------------------------------------
    // Get and lock order
    // -----------------------------------------

    const [orders] =
        await connection.query(
            `
            SELECT
                o.*

            FROM orders o

            INNER JOIN outlet ot
                ON ot.outlet_id = o.outlet_id

            WHERE o.order_id = ?

            FOR UPDATE
            `,
            [orderId]
        );


    if (orders.length === 0) {
        throw new Error(
            'Order not found'
        );
    }


    const order = orders[0];


    // -----------------------------------------
    // Don't allow items on completed orders
    // -----------------------------------------

    const blockedStatuses = [
        'BILLED',
    'PAID',
    'CANCELLED',
    'VOID'
    ];


    if (
        blockedStatuses.includes(
            order.order_status
        )
    ) {
        throw new Error(
            `Cannot add items to ${order.order_status} order`
        );
    }


    // -----------------------------------------
    // Get menu item
    // -----------------------------------------

    const [menuItems] =
        await connection.query(
            `
            SELECT
                menu_item_id,
                outlet_id,
                menu_category_id,
                item_code,
                item_name,
                item_type,
                base_rate,
                tax_group_id,
                is_available,
                is_active

            FROM menu_item

            WHERE menu_item_id = ?
              AND outlet_id = ?
              AND is_active = TRUE

            FOR UPDATE
            `,
            [
                menuItemId,
                order.outlet_id
            ]
        );


    if (menuItems.length === 0) {
        throw new Error(
            'Menu item not found'
        );
    }


    const menuItem =
        menuItems[0];


    if (!menuItem.is_available) {
        throw new Error(
            `${menuItem.item_name} is currently unavailable`
        );
    }


    // -----------------------------------------
    // Determine rate / variant
    // -----------------------------------------

    let rate =
        Number(menuItem.base_rate);

    let variantName = null;


    if (variantId) {

        const [variants] =
            await connection.query(
                `
                SELECT
                    variant_id,
                    menu_item_id,
                    variant_name,
                    rate,
                    is_active

                FROM menu_item_variant

                WHERE variant_id = ?
                  AND menu_item_id = ?
                  AND is_active = TRUE

                FOR UPDATE
                `,
                [
                    variantId,
                    menuItemId
                ]
            );


        if (variants.length === 0) {
            throw new Error(
                'Invalid variant for selected menu item'
            );
        }


        rate =
            Number(variants[0].rate);

        variantName =
            variants[0].variant_name;
    }


    // -----------------------------------------
    // Validate modifiers
    // -----------------------------------------

    const modifierRows = [];


    for (const modifier of modifiers) {

        const modifierGroupId =
            Number(
                modifier.modifierGroupId
            );

        const modifierOptionId =
            Number(
                modifier.modifierOptionId
            );

        const modifierQty =
            Number(
                modifier.qty || 1
            );


        if (
            !modifierGroupId ||
            !modifierOptionId ||
            modifierQty <= 0
        ) {
            throw new Error(
                'Invalid modifier information'
            );
        }


        // -------------------------------------
        // Verify group belongs to menu item
        // -------------------------------------

        const [groups] =
            await connection.query(
                `
                SELECT
                    mg.modifier_group_id,
                    mg.group_name,
                    mg.outlet_id

                FROM menu_item_modifier mim

                INNER JOIN modifier_group mg
                    ON mg.modifier_group_id =
                       mim.modifier_group_id

                WHERE mim.menu_item_id = ?
                  AND mim.modifier_group_id = ?
                  AND mg.outlet_id = ?
                  AND mg.is_active = TRUE

                LIMIT 1
                `,
                [
                    menuItemId,
                    modifierGroupId,
                    order.outlet_id
                ]
            );


        if (groups.length === 0) {
            throw new Error(
                'Modifier group is not valid for this menu item'
            );
        }


        // -------------------------------------
        // Get option
        // -------------------------------------

        const [options] =
            await connection.query(
                `
                SELECT
                    mo.modifier_option_id,
                    mo.modifier_group_id,
                    mo.option_name,
                    mo.extra_rate,
                    mo.is_active

                FROM modifier_option mo

                WHERE mo.modifier_option_id = ?
                  AND mo.modifier_group_id = ?
                  AND mo.is_active = TRUE

                LIMIT 1
                `,
                [
                    modifierOptionId,
                    modifierGroupId
                ]
            );


        if (options.length === 0) {
            throw new Error(
                'Invalid modifier option'
            );
        }


        const option =
            options[0];


        const modifierRate =
            Number(
                option.extra_rate || 0
            );


        const modifierAmount =
            modifierRate * modifierQty;


        modifierRows.push({
            modifierGroupId,
            modifierOptionId,

            modifierName:
                option.option_name,

            qty:
                modifierQty,

            rate:
                modifierRate,

            amount:
                modifierAmount
        });
    }


    // -----------------------------------------
    // Calculate item amounts
    // -----------------------------------------

    const grossAmount =
        rate * quantity;


    const modifierTotal =
        modifierRows.reduce(
            (total, modifier) =>
                total + modifier.amount,
            0
        );


    // -----------------------------------------
    // Discount
    // -----------------------------------------

    const discountAmount = 0;


    // -----------------------------------------
    // Tax
    // -----------------------------------------

    const taxableAmount =
        grossAmount +
        (modifierTotal * quantity) -
        discountAmount;


    const taxAmount = 0;


    const netAmount =
        taxableAmount +
        taxAmount;


    // -----------------------------------------
    // Determine next line number
    // -----------------------------------------

    const [lastLine] =
        await connection.query(
            `
            SELECT
                MAX(line_no) AS last_line_no

            FROM order_item

            WHERE order_id = ?

            FOR UPDATE
            `,
            [orderId]
        );


    const lineNo =
        Number(
            lastLine[0].last_line_no || 0
        ) + 1;


    // -----------------------------------------
    // Determine kitchen station
    // -----------------------------------------

    const [stationRows] =
        await connection.query(
            `
            SELECT
                miks.kitchen_station_id

            FROM menu_item_kitchen_station miks

            INNER JOIN kitchen_station ks
                ON ks.kitchen_station_id =
                   miks.kitchen_station_id

            WHERE miks.menu_item_id = ?
              AND miks.is_default = 1
              AND miks.is_active = 1
              AND ks.outlet_id = ?
              AND ks.is_active = 1

            LIMIT 1
            `,
            [
                menuItemId,
                order.outlet_id
            ]
        );


    if (stationRows.length === 0) {
        throw new Error(
            `Kitchen station is not assigned for ${menuItem.item_name}`
        );
    }


    const kitchenStationId =
        stationRows[0].kitchen_station_id;


    // -----------------------------------------
    // Insert order item
    // -----------------------------------------

    const orderItemUuid =
        crypto.randomUUID();


    const [itemResult] =
        await connection.query(
            `
            INSERT INTO order_item
            (
                order_item_uuid,
                order_id,
                line_no,

                menu_item_id,
                variant_id,

                item_name,
                variant_name,

                qty,
                rate,

                gross_amount,
                discount_amount,
                taxable_amount,
                tax_amount,
                net_amount,

                kitchen_station_id,
                status,
                special_instruction
            )

            VALUES
            (
                ?,
                ?,
                ?,

                ?,
                ?,

                ?,
                ?,

                ?,
                ?,

                ?,
                ?,
                ?,
                ?,
                ?,

                ?,
                'OPEN',
                ?
            )
            `,
            [
                orderItemUuid,
                orderId,
                lineNo,

                menuItemId,
                variantId,

                menuItem.item_name,
                variantName,

                quantity,
                rate,

                grossAmount,
                discountAmount,
                taxableAmount,
                taxAmount,
                netAmount,

                kitchenStationId,
                specialInstruction
            ]
        );


    const orderItemId =
        itemResult.insertId;


    // -----------------------------------------
    // Insert modifiers
    // -----------------------------------------

    for (const modifier of modifierRows) {

        await connection.query(
            `
            INSERT INTO order_item_modifier
            (
                order_item_id,
                modifier_group_id,
                modifier_option_id,
                modifier_name,
                qty,
                rate,
                amount
            )

            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?
            )
            `,
            [
                orderItemId,

                modifier.modifierGroupId,
                modifier.modifierOptionId,
                modifier.modifierName,

                modifier.qty,
                modifier.rate,
                modifier.amount
            ]
        );
    }


    // -----------------------------------------
    // Recalculate order totals
    // -----------------------------------------

    await recalculateOrder(
        connection,
        orderId,
        userId
    );


    // -----------------------------------------
    // Return information
    // -----------------------------------------

    return {
        orderItemId,
        orderItemUuid,

        orderId,
        lineNo,

        menuItemId,
        variantId,

        itemName:
            menuItem.item_name,

        variantName,

        qty:
            quantity,

        rate,

        grossAmount,
        discountAmount,
        taxableAmount,
        taxAmount,
        netAmount,

        kitchenStationId,
        specialInstruction,

        modifiers:
            modifierRows
    };
}
exports.addOrderItemInternal = addOrderItemInternal;
exports.addOrderItem = async (req, res) => {

    const connection =
        await db.getConnection();

    try {

        const orderId =
            Number(req.params.orderId);


        const {
            menuItemId,
            variantId = null,
            qty,
            specialInstruction = null,
            modifiers = []
        } = req.body;


        // -----------------------------------------
        // Begin transaction
        // -----------------------------------------

        await connection.beginTransaction();


        // -----------------------------------------
        // Add item
        // -----------------------------------------

        await addOrderItemInternal(
            connection,
            {
                orderId,
                menuItemId,
                variantId,
                qty,
                specialInstruction,
                modifiers,

                userId:
                    req.user.userId
            }
        );


        // -----------------------------------------
        // Commit
        // -----------------------------------------

        await connection.commit();


        // -----------------------------------------
        // Return complete order
        // -----------------------------------------

        return exports.getOrder(
            {
                ...req,

                params: {
                    orderId
                }
            },
            res
        );


    } catch (error) {

        await connection.rollback();

        console.error(
            'Add order item error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                error.message ||
                'Unable to add order item'

        });

    } finally {

        connection.release();
    }
};

async function getOrCreateLogicalTable(
    connection,
    restaurantTableId,
    tableCode
) {

    // --------------------------------------------------
    // Find existing logical tables
    // --------------------------------------------------

    const [logicalTables] =
        await connection.query(
            `
            SELECT
                logical_table_id,
                logical_code,
                logical_name,
                status

            FROM logical_table

            WHERE restaurant_table_id = ?

              AND is_active = TRUE

            ORDER BY logical_table_id

            FOR UPDATE
            `,
            [restaurantTableId]
        );


    // --------------------------------------------------
    // Reuse an AVAILABLE logical table
    // --------------------------------------------------

    const available =
        logicalTables.find(
            row => row.status === 'AVAILABLE'
        );


    if (available) {

        await connection.query(
            `
            UPDATE logical_table

            SET
                status = 'OCCUPIED',
                updated_at = NOW()

            WHERE logical_table_id = ?
            `,
            [
                available.logical_table_id
            ]
        );


        return {
            logicalTableId:
                available.logical_table_id,

            logicalCode:
                available.logical_code
        };
    }


    // --------------------------------------------------
    // No available logical table
    // Create a new one
    // --------------------------------------------------

    const usedCodes =
        new Set(
            logicalTables.map(
                row => row.logical_code
            )
        );


    let suffix = 0;
    let logicalCode;


    while (true) {

        if (suffix === 0) {

            logicalCode =
                tableCode;

        } else {

            logicalCode =
                tableCode +
                String.fromCharCode(
                    64 + suffix
                );
        }


        if (!usedCodes.has(logicalCode)) {
            break;
        }


        suffix++;
    }


    const logicalTableUuid =
        crypto.randomUUID();


    const logicalName =
        logicalCode === tableCode
            ? tableCode
            : logicalCode;


    const [result] =
        await connection.query(
            `
            INSERT INTO logical_table
            (
                logical_table_uuid,
                restaurant_table_id,
                logical_code,
                logical_name,
                status,
                is_active
            )

            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                'OCCUPIED',
                1
            )
            `,
            [
                logicalTableUuid,
                restaurantTableId,
                logicalCode,
                logicalName
            ]
        );


    return {
        logicalTableId:
            result.insertId,

        logicalCode
    };
}


/**
 * Internal order creation helper
 *
 * IMPORTANT:
 * - Does NOT create a DB connection
 * - Does NOT begin transaction
 * - Does NOT commit transaction
 * - Does NOT rollback transaction
 * - Does NOT send HTTP response
 *
 * Caller must already have an active transaction.
 */
async function createOrderInternal(
    connection,
    {
        outletId,
        terminalId = null,
        orderType,
        tableId = null,
        customerId = null,
        reservationId = null,
        waiterId = null,
        captainId = null,
        guestCount = 1,
        parentOrderId = null,
        remarks = null,

        // New fields
        orderSource = 'POS',
        tableSessionId = null,
        customerSessionId = null,
        // User/company context
        userId,
        companyId
    }
) {

    // -----------------------------------------
    // Validation
    // -----------------------------------------

    if (!outletId) {
        throw new Error('outletId is required');
    }

    if (!orderType) {
        throw new Error('orderType is required');
    }

    const validOrderTypes = [
        'DINE_IN',
        'TAKEAWAY',
        'DELIVERY',
        'PICKUP',
        'QR_ORDER',
        'ONLINE'
    ];

    if (!validOrderTypes.includes(orderType)) {
        throw new Error('Invalid orderType');
    }


    // -----------------------------------------
    // Validate order source
    // -----------------------------------------

    const validOrderSources = [
        'POS',
        'QR',
        'ONLINE',
        'ROOM',
        'ROOM_QR'
    ];

    if (!validOrderSources.includes(orderSource)) {
        throw new Error('Invalid orderSource');
    }


    // -----------------------------------------
    // Verify outlet access
    // -----------------------------------------

    const [access] =
        await connection.query(
            `
            SELECT 1
            FROM user_outlet uo

            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id

            WHERE uo.user_id = ?
              AND uo.outlet_id = ?
              AND o.company_id = ?
              AND o.is_active = TRUE

            LIMIT 1
            `,
            [
                userId,
                outletId,
                companyId
            ]
        );


    if (access.length === 0) {
        throw new Error(
            'You are not authorized for this outlet'
        );
    }


    // -----------------------------------------
    // DINE_IN requires table
    // -----------------------------------------

    if (orderType === 'DINE_IN' && !tableId) {
        throw new Error(
            'tableId is required for DINE_IN order'
        );
    }


    // -----------------------------------------
    // QR orders must have table session
    // -----------------------------------------

    if (
        orderSource === 'QR' &&
        !tableSessionId
    ) {
        throw new Error(
            'tableSessionId is required for QR order'
        );
    }


    let logicalTableId = null;
    let logicalCode = null;


    // -----------------------------------------
    // Lock physical table
    // -----------------------------------------

    if (tableId) {

        const [tables] =
            await connection.query(
                `
                SELECT
                    table_id,
                    table_code,
                    table_name,
                    status

                FROM restaurant_table

                WHERE table_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE

                FOR UPDATE
                `,
                [
                    tableId,
                    outletId
                ]
            );


        if (tables.length === 0) {
            throw new Error(
                'Restaurant table not found'
            );
        }


        const physicalTable =
            tables[0];


        // -----------------------------------------
        // Find existing logical tables
        // -----------------------------------------

        const [logicalTables] =
            await connection.query(
                `
                SELECT
                    logical_table_id,
                    logical_code,
                    logical_name,
                    status

                FROM logical_table

                WHERE restaurant_table_id = ?

                  AND is_active = TRUE

                ORDER BY logical_table_id

                FOR UPDATE
                `,
                [tableId]
            );


        // -----------------------------------------
        // Reuse AVAILABLE logical table
        // -----------------------------------------

        const availableLogical =
            logicalTables.find(
                row =>
                    row.status === 'AVAILABLE'
            );


        if (availableLogical) {

            logicalTableId =
                availableLogical.logical_table_id;

            logicalCode =
                availableLogical.logical_code;


            await connection.query(
                `
                UPDATE logical_table

                SET
                    status = 'OCCUPIED',
                    updated_at = NOW()

                WHERE logical_table_id = ?
                `,
                [logicalTableId]
            );

        } else {

            // -----------------------------------------
            // Create next logical table
            // -----------------------------------------

            const usedCodes =
                new Set(
                    logicalTables.map(
                        row => row.logical_code
                    )
                );


            let suffix = 0;


            while (true) {

                if (suffix === 0) {

                    logicalCode =
                        physicalTable.table_code;

                } else {

                    logicalCode =
                        physicalTable.table_code +
                        String.fromCharCode(
                            64 + suffix
                        );
                }


                if (!usedCodes.has(logicalCode)) {
                    break;
                }


                suffix++;
            }


            const logicalTableUuid =
                crypto.randomUUID();


            const [logicalResult] =
                await connection.query(
                    `
                    INSERT INTO logical_table
                    (
                        logical_table_uuid,
                        restaurant_table_id,
                        logical_code,
                        logical_name,
                        status,
                        is_active
                    )

                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        ?,
                        'OCCUPIED',
                        1
                    )
                    `,
                    [
                        logicalTableUuid,
                        tableId,
                        logicalCode,
                        logicalCode
                    ]
                );


            logicalTableId =
                logicalResult.insertId;
        }
    }


    // -----------------------------------------
    // Generate order number
    // -----------------------------------------

    const [lastOrder] =
        await connection.query(
            `
            SELECT order_no

            FROM orders

            WHERE outlet_id = ?

            ORDER BY order_id DESC

            LIMIT 1

            FOR UPDATE
            `,
            [outletId]
        );


    let nextOrderNo = 1;


    if (lastOrder.length > 0) {

        const lastNo =
            parseInt(
                lastOrder[0].order_no,
                10
            );


        if (!isNaN(lastNo)) {
            nextOrderNo = lastNo + 1;
        }
    }


    const orderNo =
        String(nextOrderNo);


    // -----------------------------------------
    // Generate UUID
    // -----------------------------------------

    const orderUuid =
        crypto.randomUUID();


    // -----------------------------------------
    // Insert order
    // -----------------------------------------

    const [result] =
        await connection.query(
            `
            INSERT INTO orders
            (
                order_uuid,
                outlet_id,
                terminal_id,
                order_no,
                order_date,
                order_time,

                order_type,
                order_source,
                order_status,

                table_id,
                logical_table_id,
                table_session_id,
                customer_session_id,
                customer_id,
                reservation_id,
                waiter_id,
                captain_id,
                guest_count,
                parent_order_id,
                remarks,

                subtotal,
                item_discount,
                bill_discount,
                taxable_amount,
                tax_amount,
                rounding_amount,
                grand_total,
                paid_amount,
                balance_amount,

                created_by
            )

            VALUES
            (
                ?,
                ?,
                ?,
                ?,

                CURDATE(),
                NOW(),

                ?,
                ?,
                'OPEN',

                ?,
                ?,
                ?,

                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,

                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,

                ?
            )
            `,
            [
                orderUuid,
                outletId,
                terminalId,
                orderNo,

                orderType,
                orderSource,

                tableId,
                logicalTableId,
                tableSessionId,
                customerSessionId,
                customerId,
                reservationId,
                waiterId,
                captainId,
                guestCount,
                parentOrderId,
                remarks,

                userId
            ]
        );


    const orderId =
        result.insertId;


    // -----------------------------------------
    // Mark physical table OCCUPIED
    // -----------------------------------------

    if (tableId) {

        await connection.query(
            `
            UPDATE restaurant_table

            SET status = 'OCCUPIED'

            WHERE table_id = ?
              AND outlet_id = ?
            `,
            [
                tableId,
                outletId
            ]
        );
    }


    // -----------------------------------------
    // Return created order
    // -----------------------------------------

    return {
        orderId,
        orderUuid,
        orderNo,

        outletId,
        terminalId,

        orderType,
        orderSource,
        orderStatus: 'OPEN',

        tableId,
        logicalTableId,
        logicalCode,
        tableSessionId,

        customerId,
        reservationId,

        waiterId,
        captainId,

        guestCount,
        parentOrderId,
        remarks,

        subtotal: 0,
        itemDiscount: 0,
        billDiscount: 0,
        taxableAmount: 0,
        taxAmount: 0,
        roundingAmount: 0,
        grandTotal: 0,
        paidAmount: 0,
        balanceAmount: 0
    };
}
exports.createOrderInternal = createOrderInternal;

exports.createOrder = async (req, res) => {

    const connection =
        await db.getConnection();

    try {

        const {
            outletId,
            terminalId = null,
            orderType,
            tableId = null,
            customerId = null,
            reservationId = null,
            waiterId = null,
            captainId = null,
            guestCount = 1,
            parentOrderId = null,
            remarks = null
        } = req.body;


        // -----------------------------------------
        // Begin transaction
        // -----------------------------------------

        await connection.beginTransaction();


        // -----------------------------------------
        // Create order
        // -----------------------------------------

        const order =
            await createOrderInternal(
                connection,
                {
                    outletId,
                    terminalId,
                    orderType,
                    tableId,
                    customerId,
                    reservationId,
                    waiterId,
                    captainId,
                    guestCount,
                    parentOrderId,
                    remarks,

                    // Normal POS endpoint
                    orderSource: 'POS',
                    tableSessionId: null,

                    userId:
                        req.user.userId,

                    companyId:
                        req.user.companyId
                }
            );


        // -----------------------------------------
        // Commit
        // -----------------------------------------

        await connection.commit();


        // -----------------------------------------
        // Response
        // -----------------------------------------

        return res.status(201).json({

            success: true,

            message:
                'Order created successfully',

            order

        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Create order error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                error.message ||
                'Unable to create order'

        });

    } finally {

        connection.release();
    }
};


/*
 * GET /api/orders/:orderId
 *
 * Returns complete order header,
 * items and modifiers.
 */
exports.getOrder = async (req, res) => {
const connection = await db.getConnection();
    try {

        const orderId =
            Number(req.params.orderId);


        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }


        // -----------------------------------------
        // Order header
        // -----------------------------------------

        const [orders] =
            await connection.query(
                `
                SELECT
                    o.*,

                    rt.table_code,
                    rt.table_name,

                    c.customer_name

                FROM orders o

                LEFT JOIN restaurant_table rt
                    ON rt.table_id = o.table_id

                LEFT JOIN customer c
                    ON c.customer_id = o.customer_id

                WHERE o.order_id = ?

                  AND EXISTS
                  (
                      SELECT 1

                      FROM outlet ot

                      INNER JOIN user_outlet uo
                          ON uo.outlet_id = ot.outlet_id

                      WHERE ot.outlet_id = o.outlet_id
                        AND ot.company_id = ?
                        AND uo.user_id = ?
                  )

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


        const order = orders[0];


        // -----------------------------------------
        // Order items
        // -----------------------------------------

        const [items] =
            await connection.query(
                `
                SELECT
                    oi.*,

                    mi.item_code

                FROM order_item oi

                INNER JOIN menu_item mi
                    ON mi.menu_item_id =
                       oi.menu_item_id

                WHERE oi.order_id = ?

                ORDER BY oi.line_no
                `,
                [orderId]
            );


        // -----------------------------------------
        // Modifiers
        // -----------------------------------------

        for (const item of items) {

            const [modifiers] =
                await connection.query(
                    `
                    SELECT
                        order_item_modifier_id,
                        modifier_group_id,
                        modifier_option_id,
                        modifier_name,
                        qty,
                        rate,
                        amount

                    FROM order_item_modifier

                    WHERE order_item_id = ?

                    ORDER BY
                        order_item_modifier_id
                    `,
                    [item.order_item_id]
                );

            item.modifiers = modifiers;
        }


        return res.json({
            success: true,

            order: {
                ...order,
                items
            }
        });


    } catch (error) {

        console.error(
            'Get order error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get order'
        });
    }
};

/*
 * PUT /api/orders/:orderId
 *
 * Update order header.
 *
 * Fields that can be updated:
 * orderType
 * tableId
 * customerId
 * waiterId
 * captainId
 * guestCount
 * remarks
 */

exports.updateOrder = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const orderId =
            Number(req.params.orderId);

        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderId'
            });
        }


        const {
            orderType,
            tableId = null,
            customerId = null,
            waiterId = null,
            captainId = null,
            guestCount = 1,
            remarks = null
        } = req.body;


        // --------------------------------------------------
        // Validate order type
        // --------------------------------------------------

        const validOrderTypes = [
            'DINE_IN',
            'TAKEAWAY',
            'DELIVERY',
            'PICKUP',
            'QR_ORDER',
            'ONLINE'
        ];


        if (
            orderType != null &&
            !validOrderTypes.includes(orderType)
        ) {

            return res.status(400).json({
                success: false,
                message: 'Invalid orderType'
            });
        }


        // --------------------------------------------------
        // Validate guest count
        // --------------------------------------------------

        const guests =
            Number(guestCount);

        if (!guests || guests < 1) {

            return res.status(400).json({
                success: false,
                message:
                    'guestCount must be greater than zero'
            });
        }


        await connection.beginTransaction();


        // --------------------------------------------------
        // Get and lock order
        // --------------------------------------------------

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


        // --------------------------------------------------
        // Don't modify completed orders
        // --------------------------------------------------

        const blockedStatuses = [
            'PAID',
            'CANCELLED',
            'VOID'
        ];


        if (
            blockedStatuses.includes(
                order.order_status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot update ${order.order_status} order`
            });
        }


        // --------------------------------------------------
        // Determine final values
        // --------------------------------------------------

        const newOrderType =
            orderType ?? order.order_type;

        const newTableId =
            ['DINE_IN', 'QR_ORDER'].includes(newOrderType)
        ? tableId
        : null;


        // --------------------------------------------------
        // DINE_IN requires table
        // --------------------------------------------------

        if (
            newOrderType === 'DINE_IN' &&
            !newTableId
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'tableId is required for DINE_IN order'
            });
        }


        // --------------------------------------------------
        // If table is changing
        // --------------------------------------------------

        if (
            newTableId &&
            newTableId !== order.table_id
        ) {

            // ----------------------------------------------
            // Lock new table
            // ----------------------------------------------

            const [tables] =
                await connection.query(
                    `
                    SELECT
                        table_id,
                        outlet_id,
                        status

                    FROM restaurant_table

                    WHERE table_id = ?

                      AND outlet_id = ?

                      AND is_active = TRUE

                    FOR UPDATE
                    `,
                    [
                        newTableId,
                        order.outlet_id
                    ]
                );


            if (tables.length === 0) {

                await connection.rollback();

                return res.status(404).json({
                    success: false,
                    message:
                        'Restaurant table not found'
                });
            }



const allowedTableStatuses = [
    'AVAILABLE',
    'OCCUPIED'
];

if (!allowedTableStatuses.includes(tables[0].status)) {

    await connection.rollback();

    return res.status(409).json({
        success: false,
        message:
            `Table is currently ${tables[0].status}`
    });
}

         
        }


        // --------------------------------------------------
        // Update order header
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE orders

            SET
                order_type = ?,
                table_id = ?,
                customer_id = ?,
                waiter_id = ?,
                captain_id = ?,
                guest_count = ?,
                remarks = ?,
                updated_by = ?,
                updated_at = NOW()

            WHERE order_id = ?
            `,
            [
                newOrderType,
                newTableId,
                customerId,
                waiterId,
                captainId,
                guests,
                remarks,
                req.user.userId,
                orderId
            ]
        );


        // --------------------------------------------------
        // Update table status
        // --------------------------------------------------

        if (
            order.table_id &&
            order.table_id !== newTableId
        ) {

            await connection.query(
                `
                UPDATE restaurant_table

                SET status = 'AVAILABLE'

                WHERE table_id = ?

                  AND outlet_id = ?
                `,
                [
                    order.table_id,
                    order.outlet_id
                ]
            );
        }


        if (newTableId) {

            await connection.query(
                `
                UPDATE restaurant_table

                SET status = 'OCCUPIED'

                WHERE table_id = ?

                  AND outlet_id = ?
                `,
                [
                    newTableId,
                    order.outlet_id
                ]
            );
        }


        await connection.commit();


        // --------------------------------------------------
        // Return complete updated order
        // --------------------------------------------------

        return exports.getOrder(
            {
                ...req,

                params: {
                    orderId
                }
            },
            res
        );


    } catch (error) {

        await connection.rollback();

        console.error(
            'Update order error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to update order'
        });

    } finally {

        connection.release();
    }
};



// ============================================================
// Get all active orders for a physical table
// ============================================================

exports.getTableOrders = async (req, res) => {
const connection = await db.getConnection();
    try {

        const tableId =
            Number(req.params.tableId);


        if (!tableId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid tableId'
            });
        }


        // ----------------------------------------------------
        // Verify table access
        // ----------------------------------------------------

        const [tables] =
            await connection.query(
                `
                SELECT
                    rt.table_id,
                    rt.outlet_id,
                    rt.table_code,
                    rt.table_name,
                    rt.capacity,
                    rt.status

                FROM restaurant_table rt

                INNER JOIN outlet ot
                    ON ot.outlet_id = rt.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = rt.outlet_id

                WHERE rt.table_id = ?

                  AND ot.company_id = ?

                  AND uo.user_id = ?

                  AND rt.is_active = TRUE

                LIMIT 1
                `,
                [
                    tableId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (tables.length === 0) {

            return res.status(404).json({
                success: false,
                message: 'Restaurant table not found'
            });
        }


        const table =
            tables[0];


        // ----------------------------------------------------
        // Get active orders for physical table
        // ----------------------------------------------------

        const [orders] =
    await connection.query(
        `
        SELECT

            o.order_id,
            o.order_uuid,
            o.order_no,

            o.outlet_id,
            o.terminal_id,

            o.order_date,
            o.order_time,

            o.order_type,
            o.order_status,

            o.table_id,
            o.logical_table_id,

            lt.logical_code,
            lt.logical_name,

            o.customer_id,

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
            o.balance_amount

        FROM orders o

        INNER JOIN logical_table lt
            ON lt.logical_table_id =
               o.logical_table_id

        WHERE o.table_id = ?

          AND o.outlet_id = ?

          AND o.order_status IN
          (
            'OPEN',
            'CONFIRMED',
            'PREPARING',
            'READY',
            'SERVED',
            'BILLED'
          )

        ORDER BY
            o.order_id
        `,
        [
            tableId,
            table.outlet_id
        ]
    );
console.log('TABLE ORDERS DEBUG');
console.log('tableId:', tableId);
console.log('table:', table);
console.log('orders:', orders);

        return res.json({

            success: true,

            table: {
                tableId: table.table_id,
                tableCode: table.table_code,
                tableName: table.table_name,
                capacity: table.capacity,
                status: table.status
            },

            orders

        });


    } catch (error) {

        console.error(
            'Get table orders error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get table orders'
        });
    }
};

/*
 * GET /api/orders/table/:tableId
 *
 * Returns the currently active order
 * for a restaurant table.
 */

exports.getTableOrder = async (req, res) => {
const connection = await db.getConnection();
    try {

        const tableId =
            Number(req.params.tableId);

        const outletId =
            Number(req.query.outletId);


        if (!tableId || !outletId) {

            return res.status(400).json({
                success: false,
                message:
                    'tableId and outletId are required'
            });
        }


        const [orders] =
            await connection.query(
                `
                SELECT
                    o.order_id,
                    o.order_uuid,
                    o.order_no,
                    o.order_date,
                    o.order_time,
                    o.order_type,
                    o.order_status,
                    o.table_id,
                    o.customer_id,
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
                    o.balance_amount

                FROM orders o

                INNER JOIN outlet ot
                    ON ot.outlet_id = o.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = o.outlet_id

                WHERE o.outlet_id = ?
                  AND o.table_id = ?

                  AND o.order_status IN
                  (
                    'OPEN',
                    'CONFIRMED',
                    'PREPARING',
                    'READY',
                    'SERVED',
                    'BILLED'
                  )

                  AND ot.company_id = ?
                  AND uo.user_id = ?

                ORDER BY o.order_id DESC

                LIMIT 1
                `,
                [
                    outletId,
                    tableId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (orders.length === 0) {

            return res.json({
                success: true,
                order: null
            });
        }


        return res.json({
            success: true,
            order: orders[0]
        });


    } catch (error) {

        console.error(
            'Get table order error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get table order'
        });
    }
};