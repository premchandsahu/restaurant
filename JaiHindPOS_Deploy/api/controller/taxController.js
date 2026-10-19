const conn =  require('../database');


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