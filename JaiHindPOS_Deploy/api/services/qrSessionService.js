/**
 * Close the active QR/table session when all orders
 * belonging to that session have reached a terminal state.
 *
 * Terminal order states:
 * PAID, CANCELLED, VOID, MERGED
 *
 * Returns:
 *   true  -> session was closed
 *   false -> session is still active / already closed / not found
 */
async function closeTableSessionIfSettled(
    connection,
    tableSessionId
) {
    if (!tableSessionId) {
        return false;
    }

    // --------------------------------------------------
    // 1. Lock the table session
    // --------------------------------------------------
    const [sessions] = await connection.query(
        `
        SELECT
            session_id,
            table_id,
            status
        FROM table_order_session
        WHERE session_id = ?
        FOR UPDATE
        `,
        [tableSessionId]
    );

    if (
        sessions.length === 0 ||
        sessions[0].status !== 'ACTIVE'
    ) {
        return false;
    }

    // --------------------------------------------------
    // 2. Check whether any unsettled order remains
    // --------------------------------------------------
    const [openOrders] = await connection.query(
        `
        SELECT
            order_id
        FROM orders
        WHERE table_session_id = ?
          AND order_status NOT IN
              ('PAID', 'CANCELLED', 'VOID', 'MERGED')
        LIMIT 1
        `,
        [tableSessionId]
    );

    // Another customer/order is still active.
    if (openOrders.length > 0) {
        return false;
    }

    // --------------------------------------------------
    // 3. Close table QR session
    // --------------------------------------------------
    await connection.query(
        `
        UPDATE table_order_session
        SET
            status = 'CLOSED',
            closed_at = NOW()
        WHERE session_id = ?
          AND status = 'ACTIVE'
        `,
        [tableSessionId]
    );

    // --------------------------------------------------
    // 4. Close all customer sessions belonging
    //    to this table session
    // --------------------------------------------------
    await connection.query(
        `
        UPDATE customer_order_session
        SET
            status = 'CLOSED',
            closed_at = NOW()
        WHERE table_session_id = ?
          AND status = 'ACTIVE'
        `,
        [tableSessionId]
    );

    return true;
}

module.exports = {
    closeTableSessionIfSettled
};