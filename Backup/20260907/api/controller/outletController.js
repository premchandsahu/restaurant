const conn = require('../database');

exports.getOutlets = async (req, res) => {
    console.log(req.user.companyId)
 const db=await conn.getConnection();
    try {

        /*
         * req.user.companyId comes from JWT.
         *
         * This prevents a user from requesting
         * outlets belonging to another company.
         */
        const [outlets] = await db.query(
            `
            SELECT
                outlet_id,
                outlet_uuid,
                outlet_code,
                outlet_name,
                gstin,
                phone,
                email,
                address1,
                address2,
                city,
                state,
                pincode,
                invoice_prefix,
                kot_prefix
            FROM outlet
            WHERE company_id = ?
              AND is_active = TRUE
            ORDER BY outlet_name
            `,
            [req.user.companyId]
        );

        return res.status(200).json({
            success: true,
            outlets: outlets
        });

    } catch (error) {

        console.error('Get outlets error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to get outlets'
        });
    }
};


exports.getPosLayout = async (req, res) => {
 const db=await conn.getConnection();
    try {

        const outletId = Number(req.params.outletId);

        if (!outletId || outletId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid outlet ID'
            });
        }

        /*
         * IMPORTANT:
         *
         * Check that the logged-in user is actually
         * assigned to this outlet.
         */
        const [userOutlets] = await db.query(
            `
            SELECT
                uo.outlet_id
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

        if (userOutlets.length === 0) {

            return res.status(403).json({
                success: false,
                message: 'You are not authorized for this outlet'
            });
        }


        // ----------------------------------------------------
        // OUTLET
        // ----------------------------------------------------

        const [outlets] = await db.query(
            `
            SELECT
                outlet_id,
                outlet_uuid,
                outlet_code,
                outlet_name,
                gstin,
                phone,
                email,
                address1,
                address2,
                city,
                state,
                pincode,
                invoice_prefix,
                kot_prefix
            FROM outlet
            WHERE outlet_id = ?
              AND is_active = TRUE
            LIMIT 1
            `,
            [outletId]
        );


        if (outlets.length === 0) {

            return res.status(404).json({
                success: false,
                message: 'Outlet not found'
            });
        }


        // ----------------------------------------------------
        // FLOORS
        // ----------------------------------------------------

        const [floors] = await db.query(
            `
            SELECT
                floor_id,
                floor_name,
                display_order
            FROM floor
            WHERE outlet_id = ?
              AND is_active = TRUE
            ORDER BY
                display_order,
                floor_name
            `,
            [outletId]
        );


        // ----------------------------------------------------
        // DINING AREAS
        // ----------------------------------------------------

        const [diningAreas] = await db.query(
            `
            SELECT
                dining_area_id,
                area_name,
                display_order
            FROM dining_area
            WHERE outlet_id = ?
              AND is_active = TRUE
            ORDER BY
                display_order,
                area_name
            `,
            [outletId]
        );


       // ----------------------------------------------------
// TABLES
// ----------------------------------------------------

const [tables] = await db.query(
    `
    SELECT
        rt.table_id,
        rt.table_uuid,
        rt.table_code,
        rt.table_name,
        rt.capacity,
        rt.floor_id,
        rt.dining_area_id,
        rt.shape,
        rt.pos_x,
        rt.pos_y,
        rt.width,
        rt.height,
        rt.status,

        /* ---------------------------------------------
         * ACTIVE ORDER SUMMARY
         * --------------------------------------------- */

        COUNT(DISTINCT CASE
            WHEN o.order_id IS NOT NULL
            THEN o.order_id
        END) AS active_order_count,

        COALESCE(
            SUM(
                CASE
                    WHEN o.order_id IS NOT NULL
                    THEN o.guest_count
                    ELSE 0
                END
            ),
            0
        ) AS active_guest_count,

        COALESCE(
            SUM(
                CASE
                    WHEN o.order_id IS NOT NULL
                    THEN o.grand_total
                    ELSE 0
                END
            ),
            0
        ) AS active_order_amount

    FROM restaurant_table rt

    LEFT JOIN orders o
        ON o.table_id = rt.table_id
       AND o.outlet_id = rt.outlet_id

       /* ---------------------------------------------
        * Orders which are still active on the table
        * --------------------------------------------- */
       AND o.order_status NOT IN (
            'PAID',
            'CANCELLED',
            'VOID',
            'MERGED'
       )

    WHERE rt.outlet_id = ?
      AND rt.is_active = TRUE

    GROUP BY
        rt.table_id,
        rt.table_uuid,
        rt.table_code,
        rt.table_name,
        rt.capacity,
        rt.floor_id,
        rt.dining_area_id,
        rt.shape,
        rt.pos_x,
        rt.pos_y,
        rt.width,
        rt.height,
        rt.status

    ORDER BY
        rt.table_code
    `,
    [outletId]
);

        return res.status(200).json({

            success: true,

            outlet: outlets[0],

            floors: floors,

            diningAreas: diningAreas,

            tables: tables
        });


    } catch (error) {

        console.error('Get POS layout error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to load POS layout'
        });
    }
};