const db = require('../database');
const crypto = require('crypto');

const orderController = require('./orderController');




exports.getPendingBills = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const outletId = Number(req.query.outletId);

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        // -----------------------------------------
        // Verify outlet access
        // -----------------------------------------

        const [access] = await connection.query(
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
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );

        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }

        // -----------------------------------------
        // Pending bills
        // -----------------------------------------

        const [bills] = await connection.query(
            `
            SELECT
                b.bill_id,
                b.bill_uuid,
                b.outlet_id,
                b.terminal_id,
                b.order_id,
                b.bill_no,
                b.bill_date,
                b.bill_time,
                b.bill_type,
                b.bill_status,
                b.grand_total,
                b.paid_amount,
                b.balance_amount,

                o.order_no,
                o.order_type,
                o.table_id,
                o.logical_table_id,

                rt.table_code,
                rt.table_name,

                lt.logical_code,
                lt.logical_name,

                c.customer_name

            FROM bill b

            INNER JOIN orders o
                ON o.order_id = b.order_id

            LEFT JOIN restaurant_table rt
                ON rt.table_id = o.table_id

            LEFT JOIN logical_table lt
                ON lt.logical_table_id = o.logical_table_id

            LEFT JOIN customer c
                ON c.customer_id = o.customer_id

            WHERE b.outlet_id = ?

              AND b.bill_status IN (
                  'FINAL',
                  'PARTIALLY_PAID'
              )

              AND b.balance_amount > 0

            ORDER BY
                b.bill_date,
                b.bill_time,
                b.bill_id
            `,
            [outletId]
        );

        return res.json({
            success: true,
            bills
        });

    } catch (error) {

        console.error(
            'Get pending bills error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get pending bills'
        });

    } finally {
        connection.release();
    }
};

// ============================================================
// ADD PAYMENT TO BILL
// ============================================================
exports.addPayment = async (req, res) => {
  const connection = await db.getConnection();

  try {
    const billId = Number(req.params.billId);
    const {
      paymentMode,
      amount,
      referenceNo,
      remarks,
    } = req.body;

    if (!billId) {
      return res.status(400).json({
        success: false,
        message: 'Invalid bill ID',
      });
    }

    const paymentAmount = Number(amount);

    if (!paymentAmount || paymentAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Payment amount must be greater than zero',
      });
    }

    const allowedModes = [
      'CASH',
      'CARD',
      'UPI',
      'BANK',
      'WALLET',
      'CREDIT',
      'OTHER',
    ];

    if (!allowedModes.includes(paymentMode)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid payment mode',
      });
    }

    await connection.beginTransaction();

    // --------------------------------------------------------
    // Lock bill and verify company / outlet access
    // --------------------------------------------------------
    const [billRows] = await connection.query(
      `
      SELECT
          b.*
      FROM bill b
      INNER JOIN outlet o
          ON o.outlet_id = b.outlet_id
      INNER JOIN user_outlet uo
          ON uo.outlet_id = b.outlet_id
         AND uo.user_id = ?
      WHERE b.bill_id = ?
        AND o.company_id = ?
      FOR UPDATE
      `,
      [
        req.user.userId,
        billId,
        req.user.companyId,
      ]
    );

    if (!billRows.length) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: 'Bill not found or access denied',
      });
    }

    const bill = billRows[0];

    // --------------------------------------------------------
    // Check bill status
    // --------------------------------------------------------
    if (
      bill.bill_status === 'CANCELLED' ||
      bill.bill_status === 'VOID' ||
      bill.bill_status === 'REFUNDED'
    ) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: `Payment not allowed for bill status ${bill.bill_status}`,
      });
    }

    if (bill.bill_status === 'PAID') {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: 'Bill is already fully paid',
      });
    }

    // --------------------------------------------------------
    // Calculate already received successful payments
    // --------------------------------------------------------
    const [paymentRows] = await connection.query(
      `
      SELECT
          COALESCE(SUM(amount), 0) AS paid_amount
      FROM bill_payment
      WHERE bill_id = ?
        AND status = 'SUCCESS'
      `,
      [billId]
    );

    const alreadyPaid = Number(paymentRows[0].paid_amount || 0);

    const grandTotal = Number(bill.grand_total || 0);

    const balance = grandTotal - alreadyPaid;

    // --------------------------------------------------------
    // Prevent overpayment
    // --------------------------------------------------------
    const epsilon = 0.01;

    if (paymentAmount > balance + epsilon) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: 'Payment amount exceeds outstanding balance',
        grandTotal,
        paidAmount: alreadyPaid,
        balanceAmount: balance,
      });
    }

    // --------------------------------------------------------
    // Insert payment
    // --------------------------------------------------------
    const paymentUuid = crypto.randomUUID();

    await connection.query(
      `
      INSERT INTO bill_payment
      (
          payment_uuid,
          bill_id,
          outlet_id,
          terminal_id,
          payment_date,
          payment_mode,
          amount,
          reference_no,
          received_by,
          remarks,
          status
      )
      VALUES (?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, 'SUCCESS')
      `,
      [
        paymentUuid,
        billId,
        bill.outlet_id,
        bill.terminal_id,
        paymentMode,
        paymentAmount,
        referenceNo || null,
        req.user.userId,
        remarks || null,
      ]
    );

    // --------------------------------------------------------
    // Calculate new payment totals
    // --------------------------------------------------------
    const newPaidAmount = alreadyPaid + paymentAmount;

    const newBalance = Math.max(
      grandTotal - newPaidAmount,
      0
    );

    const newBillStatus =
      newBalance <= epsilon
        ? 'PAID'
        : 'PARTIALLY_PAID';

    // --------------------------------------------------------
    // Update bill
    // --------------------------------------------------------
    await connection.query(
      `
      UPDATE bill
      SET
          paid_amount = ?,
          balance_amount = ?,
          bill_status = ?
      WHERE bill_id = ?
      `,
      [
        newPaidAmount,
        newBalance,
        newBillStatus,
        billId,
      ]
    );

    // --------------------------------------------------------
    // FULL PAYMENT
    // --------------------------------------------------------
    if (newBillStatus === 'PAID') {

      // ----------------------------------------------
      // Mark order as PAID
      // ----------------------------------------------
      if (bill.order_id) {
        await connection.query(
          `
          UPDATE orders
          SET
              order_status = 'PAID'
          WHERE order_id = ?
            AND order_status NOT IN ('CANCELLED', 'VOID')
          `,
          [bill.order_id]
        );

        // --------------------------------------------
        // Release logical table
        // --------------------------------------------
        const [orderRows] = await connection.query(
          `
          SELECT
              table_id,
              logical_table_id
          FROM orders
          WHERE order_id = ?
          FOR UPDATE
          `,
          [bill.order_id]
        );

        if (orderRows.length) {
          const order = orderRows[0];

          if (order.logical_table_id) {
            await connection.query(
              `
              UPDATE logical_table
              SET
                  status = 'AVAILABLE'
              WHERE logical_table_id = ?
              `,
              [order.logical_table_id]
            );
          }

          // ------------------------------------------
          // Check whether physical table still has
          // another active order.
          //
          // This is important because T01 and T01A
          // can exist simultaneously.
          // ------------------------------------------
          if (order.table_id) {

            const [activeOrders] = await connection.query(
              `
              SELECT order_id
              FROM orders
              WHERE table_id = ?
                AND order_status NOT IN
                    ('PAID', 'CANCELLED', 'VOID','MERGED')
              LIMIT 1
              `,
              [order.table_id]
            );

            if (activeOrders.length === 0) {

              await connection.query(
                `
                UPDATE restaurant_table
                SET
                    status = 'AVAILABLE'
                WHERE table_id = ?
                `,
                [order.table_id]
              );

            } else {

              await connection.query(
                `
                UPDATE restaurant_table
                SET
                    status = 'OCCUPIED'
                WHERE table_id = ?
                `,
                [order.table_id]
              );
            }
          }
        }
      }
    }

    await connection.commit();

    // --------------------------------------------------------
    // Return complete bill
    // --------------------------------------------------------
    // --------------------------------------------------------
// Get updated bill
// --------------------------------------------------------
const [updatedBillRows] = await connection.query(
  `
  SELECT *
  FROM bill
  WHERE bill_id = ?
  `,
  [billId]
);

if (!updatedBillRows.length) {
  throw new Error('Bill not found after payment');
}

const updatedBill = updatedBillRows[0];

const [items] = await connection.query(
  `
  SELECT *
  FROM bill_item
  WHERE bill_id = ?
  ORDER BY bill_item_id
  `,
  [billId]
);

const [taxes] = await connection.query(
  `
  SELECT *
  FROM bill_tax
  WHERE bill_id = ?
  ORDER BY bill_tax_id
  `,
  [billId]
);

const [discounts] = await connection.query(
  `
  SELECT *
  FROM bill_discount
  WHERE bill_id = ?
  ORDER BY bill_discount_id
  `,
  [billId]
);

const [payments] = await connection.query(
  `
  SELECT *
  FROM bill_payment
  WHERE bill_id = ?
  ORDER BY payment_id
  `,
  [billId]
);

const result = {
  ...updatedBill,
  items,
  taxes,
  discounts,
  payments,
};

    return res.status(201).json({
      success: true,
      message:
        newBillStatus === 'PAID'
          ? 'Payment received and bill paid successfully'
          : 'Payment received successfully',

      payment: {
        paymentUuid,
        paymentMode,
        amount: paymentAmount,
        referenceNo: referenceNo || null,
      },

      bill: result,
    });

  } catch (error) {

    await connection.rollback();

    console.error('ADD PAYMENT ERROR:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to process payment',
      error: error.message,
    });

  } finally {
    connection.release();
  }
};


// ============================================================
// Create Normal Bill
//
// POST /api/bills
//
// Body:
// {
//     "orderId": 123
// }
// ============================================================




exports.createBill = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const orderId =
            Number(req.body.orderId);


        // --------------------------------------------------
        // Validate input
        // --------------------------------------------------

        if (!orderId) {

            return res.status(400).json({
                success: false,
                message: 'orderId is required'
            });

        }


        await connection.beginTransaction();


        // ==================================================
        // 1. Get and lock order
        // ==================================================

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


        let order = orders[0];


        // ==================================================
        // 2. Validate order status
        // ==================================================

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
                    `Cannot create bill for ${order.order_status} order`
            });

        }


        // --------------------------------------------------
        // Prevent duplicate billing
        // --------------------------------------------------

        if (order.order_status === 'BILLED') {

            const [existingBills] =
                await connection.query(
                    `
                    SELECT
                        bill_id,
                        bill_uuid,
                        bill_no,
                        bill_status,
                        grand_total

                    FROM bill

                    WHERE order_id = ?

                      AND bill_status NOT IN
                      (
                          'CANCELLED',
                          'VOID'
                      )

                    ORDER BY bill_id DESC

                    LIMIT 1
                    `,
                    [orderId]
                );


            if (existingBills.length > 0) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message: 'Bill already exists for this order',
                    bill: existingBills[0]
                });

            }

        }


        // ==================================================
        // 3. Recalculate order
        //
        // Reuses existing tax/discount engine.
        // ==================================================

        await orderController.recalculateOrder(
            connection,
            orderId,
            req.user.userId
        );


        // ==================================================
        // 4. Re-read recalculated order
        // ==================================================

        const [updatedOrders] =
            await connection.query(
                `
                SELECT
                    o.*

                FROM orders o

                WHERE o.order_id = ?

                FOR UPDATE
                `,
                [orderId]
            );


        if (updatedOrders.length === 0) {

            throw new Error(
                'Order disappeared during bill creation'
            );

        }


        order = updatedOrders[0];


        // ==================================================
        // 5. Validate order has items
        // ==================================================

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

                  AND oi.status NOT IN
                  (
                      'CANCELLED',
                      'VOID'
                  )

                ORDER BY oi.line_no
                `,
                [orderId]
            );


        if (items.length === 0) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Cannot create bill without billable items'
            });

        }


        // ==================================================
        // 6. Generate bill number
        //
        // Bill number is generated inside transaction.
        // Outlet row is locked to avoid duplicate numbers.
        // ==================================================

        const [outlets] =
            await connection.query(
                `
                SELECT
                    outlet_id

                FROM outlet

                WHERE outlet_id = ?

                  AND company_id = ?

                FOR UPDATE
                `,
                [
                    order.outlet_id,
                    req.user.companyId
                ]
            );


        if (outlets.length === 0) {

            throw new Error(
                'Outlet not found or access denied'
            );

        }


        const [billNumbers] =
            await connection.query(
                `
                SELECT
                    MAX(
                        CAST(
                            bill_no AS UNSIGNED
                        )
                    ) AS last_bill_no

                FROM bill

                WHERE outlet_id = ?
                `,
                [order.outlet_id]
            );


        const lastBillNo =
            Number(
                billNumbers[0].last_bill_no || 0
            );


        const billNo =
            String(lastBillNo + 1);


        // ==================================================
        // 7. Create bill header
        // ==================================================

        const billUuid =
            crypto.randomUUID();


        const billType =
            'NORMAL';


        const billStatus =
            Number(order.balance_amount || 0) > 0
                ? 'FINAL'
                : 'PAID';


        const [billResult] =
            await connection.query(
                `
                INSERT INTO bill
                (
                    bill_uuid,
                    outlet_id,
                    terminal_id,
                    order_id,

                    bill_no,
                    bill_date,
                    bill_time,

                    bill_type,
                    bill_status,

                    subtotal,
                    item_discount,
                    bill_discount,
                    taxable_amount,
                    tax_amount,
                    rounding_amount,
                    grand_total,

                    paid_amount,
                    balance_amount,

                    remarks,

                    created_by,
                    updated_by
                )

                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,

                    ?,
                    CURDATE(),
                    CURTIME(),

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
                    ?
                )
                `,
                [

                    billUuid,

                    order.outlet_id,

                    order.terminal_id || null,

                    order.order_id,


                    billNo,

                    billType,

                    billStatus,


                    Number(order.subtotal || 0),

                    Number(order.item_discount || 0),

                    Number(order.bill_discount || 0),

                    Number(order.taxable_amount || 0),

                    Number(order.tax_amount || 0),

                    Number(order.rounding_amount || 0),

                    Number(order.grand_total || 0),


                    Number(order.paid_amount || 0),

                    Number(order.balance_amount || 0),


                    order.remarks || null,


                    req.user.userId,

                    req.user.userId
                ]
            );


        const billId =
            billResult.insertId;


        // ==================================================
        // 8. Copy order items to bill_item
        // ==================================================

        for (const item of items) {

            await connection.query(
                `
                INSERT INTO bill_item
                (
                    bill_id,
                    order_item_id,

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
                    net_amount
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
                    ?
                )
                `,
                [

                    billId,

                    item.order_item_id,


                    item.menu_item_id,

                    item.variant_id || null,


                    item.item_name,

                    item.variant_name || null,


                    Number(item.qty || 0),

                    Number(item.rate || 0),


                    Number(item.gross_amount || 0),

                    Number(item.discount_amount || 0),

                    Number(item.taxable_amount || 0),

                    Number(item.tax_amount || 0),

                    Number(item.net_amount || 0)
                ]
            );

        }


        // ==================================================
        // 9. Copy order taxes
        // ==================================================

        const [taxes] =
            await connection.query(
                `
                SELECT
                    *

                FROM order_tax

                WHERE order_id = ?

                ORDER BY order_tax_id
                `,
                [orderId]
            );


        for (const tax of taxes) {

            await connection.query(
                `
                INSERT INTO bill_tax
                (
                    bill_id,

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

                    billId,

                    tax.tax_rate_id || null,

                    tax.tax_name,

                    tax.tax_type,

                    Number(tax.rate || 0),


                    Number(
                        tax.taxable_amount || 0
                    ),

                    Number(
                        tax.tax_amount || 0
                    )
                ]
            );

        }


        // ==================================================
        // 10. Copy order discounts
        // ==================================================

        const [discounts] =
            await connection.query(
                `
                SELECT
                    *

                FROM order_discount

                WHERE order_id = ?

                ORDER BY order_discount_id
                `,
                [orderId]
            );


        for (const discount of discounts) {

            await connection.query(
                `
                INSERT INTO bill_discount
                (
                    bill_id,

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

                    billId,

                    discount.discount_id || null,

                    discount.discount_name ||
                        'Manual Discount',

                    discount.discount_type,

                    Number(
                        discount.discount_value || 0
                    ),

                    Number(
                        discount.discount_amount || 0
                    ),

                    discount.approved_by || null
                ]
            );

        }


        // ==================================================
        // 11. Mark order as BILLED
        // ==================================================

        await connection.query(
            `
            UPDATE orders

            SET
                order_status = 'BILLED',

                updated_by = ?

            WHERE order_id = ?
            `,
            [
                req.user.userId,
                orderId
            ]
        );


        // ==================================================
        // IMPORTANT:
        //
        // Do NOT mark restaurant_table AVAILABLE here.
        //
        // Payment/settlement will decide when the table
        // becomes available.
        // ==================================================


        // ==================================================
        // 12. Commit
        // ==================================================

        await connection.commit();


        // ==================================================
        // 13. Return complete bill
        // ==================================================

        return exports.getBill(
            {
                ...req,
                params: {
                    billId
                }
            },
            res
        );


    } catch (error) {

        await connection.rollback();

        console.error(
            'Create bill error:',
            error
        );


        return res.status(500).json({
            success: false,
            message:
                'Unable to create bill'
        });


    } finally {

        connection.release();

    }

};



// ============================================================
// Get Bill
//
// GET /api/bills/:billId
// ============================================================

exports.getBill = async (req, res) => {

    const connection =
        await db.getConnection();


    try {

        const billId =
            Number(req.params.billId);


        if (!billId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid billId'
            });

        }


        // ==================================================
        // Bill header
        // ==================================================

        const [bills] =
            await connection.query(
                `
                SELECT
                    b.*,

                    o.order_no,
                    o.order_type,
                    o.table_id,
                    o.logical_table_id,

                    rt.table_code,
                    rt.table_name

                FROM bill b

                INNER JOIN orders o
                    ON o.order_id =
                       b.order_id

                LEFT JOIN restaurant_table rt
                    ON rt.table_id =
                       o.table_id

                INNER JOIN outlet ot
                    ON ot.outlet_id =
                       b.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       b.outlet_id

                WHERE b.bill_id = ?

                  AND ot.company_id = ?

                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    billId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (bills.length === 0) {

            return res.status(404).json({
                success: false,
                message: 'Bill not found'
            });

        }


        const bill =
            bills[0];


        // ==================================================
        // Bill items
        // ==================================================

        const [items] =
            await connection.query(
                `
                SELECT
                    *

                FROM bill_item

                WHERE bill_id = ?

                ORDER BY bill_item_id
                `,
                [billId]
            );


        // ==================================================
        // Bill taxes
        // ==================================================

        const [taxes] =
            await connection.query(
                `
                SELECT
                    *

                FROM bill_tax

                WHERE bill_id = ?

                ORDER BY bill_tax_id
                `,
                [billId]
            );


        // ==================================================
        // Bill discounts
        // ==================================================

        const [discounts] =
            await connection.query(
                `
                SELECT
                    *

                FROM bill_discount

                WHERE bill_id = ?

                ORDER BY bill_discount_id
                `,
                [billId]
            );


        // ==================================================
        // Payments
        // ==================================================

        const [payments] =
            await connection.query(
                `
                SELECT
                    *

                FROM bill_payment

                WHERE bill_id = ?

                ORDER BY payment_id
                `,
                [billId]
            );


        // ==================================================
        // Response
        // ==================================================

        return res.json({

            success: true,

            bill: {

                ...bill,

                items,

                taxes,

                discounts,

                payments

            }

        });


    } catch (error) {

        console.error(
            'Get bill error:',
            error
        );


        return res.status(500).json({
            success: false,
            message:
                'Unable to get bill'
        });


    } finally {

        connection.release();

    }

};

// ============================================================
// BILL HISTORY
//
// GET /api/bills/history
//
// Query parameters:
//
// outletId        required
// fromDate        required  YYYY-MM-DD
// toDate          required  YYYY-MM-DD
//
// billNo          optional
// orderNo         optional
// customerId      optional
// tableId         optional
// billStatus      optional
// paymentStatus   optional
//
// ============================================================

exports.getBillHistory = async (req, res) => {
    const connection = await db.getConnection();

    try {

        // --------------------------------------------------------
        // Read filters
        // --------------------------------------------------------

        const outletId = Number(req.query.outletId);

        const fromDate =
            req.query.fromDate
                ? String(req.query.fromDate)
                : null;

        const toDate =
            req.query.toDate
                ? String(req.query.toDate)
                : null;

        const billNo =
            req.query.billNo
                ? String(req.query.billNo).trim()
                : null;

        const orderNo =
            req.query.orderNo
                ? String(req.query.orderNo).trim()
                : null;

        const customerId =
            req.query.customerId
                ? Number(req.query.customerId)
                : null;

        const tableId =
            req.query.tableId
                ? Number(req.query.tableId)
                : null;

        const billStatus =
            req.query.billStatus
                ? String(req.query.billStatus).trim()
                : null;

        const paymentStatus =
            req.query.paymentStatus
                ? String(req.query.paymentStatus).trim()
                : null;


        // --------------------------------------------------------
        // Validate required filters
        // --------------------------------------------------------

        if (!outletId) {
            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        if (!fromDate || !toDate) {
            return res.status(400).json({
                success: false,
                message: 'fromDate and toDate are required'
            });
        }


        // --------------------------------------------------------
        // Validate dates
        // --------------------------------------------------------

        const fromDateObj = new Date(`${fromDate}T00:00:00`);
        const toDateObj = new Date(`${toDate}T00:00:00`);

        if (
            Number.isNaN(fromDateObj.getTime()) ||
            Number.isNaN(toDateObj.getTime())
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid date format. Use YYYY-MM-DD'
            });
        }

        if (fromDateObj > toDateObj) {
            return res.status(400).json({
                success: false,
                message: 'fromDate cannot be greater than toDate'
            });
        }


        // --------------------------------------------------------
        // Verify outlet access
        // --------------------------------------------------------

        const [access] = await connection.query(
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
                req.user.userId,
                outletId,
                req.user.companyId
            ]
        );


        if (access.length === 0) {
            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }


        // --------------------------------------------------------
        // Build query
        // --------------------------------------------------------

        let sql = `
            SELECT
                b.bill_id,
                b.bill_uuid,
                b.outlet_id,
                b.terminal_id,
                b.order_id,
                b.bill_no,
                b.bill_date,
                b.bill_time,
                b.bill_type,
                b.bill_status,

                b.subtotal,
                b.item_discount,
                b.bill_discount,
                b.taxable_amount,
                b.tax_amount,
                b.rounding_amount,
                b.grand_total,

                b.paid_amount,
                b.balance_amount,

                b.remarks,

                o.order_no,
                o.order_type,
                o.order_status,
                o.table_id,
                o.logical_table_id,

                rt.table_code,
                rt.table_name,

                lt.logical_code,
                lt.logical_name,

                c.customer_id,
                c.customer_name

            FROM bill b

            INNER JOIN orders o
                ON o.order_id = b.order_id

            LEFT JOIN restaurant_table rt
                ON rt.table_id = o.table_id

            LEFT JOIN logical_table lt
                ON lt.logical_table_id = o.logical_table_id

            LEFT JOIN customer c
                ON c.customer_id = o.customer_id

            WHERE b.outlet_id = ?

              AND b.bill_date BETWEEN ? AND ?
        `;

        const params = [
            outletId,
            fromDate,
            toDate
        ];


        // --------------------------------------------------------
        // Bill number filter
        // --------------------------------------------------------

        if (billNo) {
            sql += `
                AND b.bill_no LIKE ?
            `;

            params.push(`%${billNo}%`);
        }


        // --------------------------------------------------------
        // Order number filter
        // --------------------------------------------------------

        if (orderNo) {
            sql += `
                AND o.order_no LIKE ?
            `;

            params.push(`%${orderNo}%`);
        }


        // --------------------------------------------------------
        // Customer filter
        // --------------------------------------------------------

        if (customerId) {
            sql += `
                AND o.customer_id = ?
            `;

            params.push(customerId);
        }


        // --------------------------------------------------------
        // Table filter
        // --------------------------------------------------------

        if (tableId) {
            sql += `
                AND o.table_id = ?
            `;

            params.push(tableId);
        }


        // --------------------------------------------------------
        // Bill status filter
        // --------------------------------------------------------

        if (billStatus) {
            sql += `
                AND b.bill_status = ?
            `;

            params.push(billStatus);
        }


        // --------------------------------------------------------
        // Payment status filter
        //
        // PAID    = balance zero
        // PENDING = balance greater than zero
        // --------------------------------------------------------

        if (paymentStatus === 'PAID') {

            sql += `
                AND b.balance_amount <= 0.01
            `;

        } else if (paymentStatus === 'PENDING') {

            sql += `
                AND b.balance_amount > 0.01
            `;
        }


        // --------------------------------------------------------
        // Ordering
        // --------------------------------------------------------

        sql += `
            ORDER BY
                b.bill_date DESC,
                b.bill_time DESC,
                b.bill_id DESC
        `;


        const [bills] = await connection.query(
            sql,
            params
        );


        // --------------------------------------------------------
        // Response
        // --------------------------------------------------------

        return res.json({
            success: true,
            filters: {
                outletId,
                fromDate,
                toDate,
                billNo,
                orderNo,
                customerId,
                tableId,
                billStatus,
                paymentStatus
            },
            count: bills.length,
            bills
        });

    } catch (error) {

        console.error(
            'Get bill history error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Unable to get bill history'
        });

    } finally {

        connection.release();
    }
};