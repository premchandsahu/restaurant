const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Change this path if your existing DB connection has another location/name.
const conn = require('../database');

exports.login = async (req, res) => {
    const db = await conn.getConnection();

    try {

        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Username and password are required'
            });
        }

        /*
         * app_user is the actual user table in our schema.
         *
         * role gives us role_code / role_name.
         * company identifies the company.
         */
        const [users] = await db.query(
            `
            SELECT
                u.user_id,
                u.user_uuid,
                u.company_id,
                u.role_id,
                u.username,
                u.password_hash,
                u.display_name,
                u.mobile,
                u.email,
                r.role_code,
                r.role_name
            FROM app_user u
            INNER JOIN role r
                ON r.role_id = u.role_id
            WHERE u.username = ?
              AND u.is_active = TRUE
              AND r.is_active = TRUE
            LIMIT 1
            `,
            [username]
        );

        if (users.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Invalid username or password'
            });
        }

        const user = users[0];

        // Compare entered password with password_hash
        const passwordValid = await bcrypt.compare(
            password,
            user.password_hash
        );

        if (!passwordValid) {
            return res.status(401).json({
                success: false,
                message: 'Invalid username or password'
            });
        }

        /*
         * H5.5
         * Get permissions assigned to the user's role.
         */
        const [permissionRows] = await db.query(
            `
            SELECT
                p.permission_id,
                p.permission_code,
                p.permission_name,
                p.module_name
            FROM role_permission rp
            INNER JOIN permission p
                ON p.permission_id = rp.permission_id
            WHERE rp.role_id = ?
            ORDER BY
                p.module_name,
                p.permission_code
            `,
            [user.role_id]
        );

        const permissions = permissionRows.map(
            permission => permission.permission_code
        );

        /*
         * Get outlets assigned to this user.
         *
         * user_outlet is the mapping table in our schema.
         */
        const [outlets] = await db.query(
            `
            SELECT
                o.outlet_id,
                o.outlet_uuid,
                o.outlet_code,
                o.outlet_name,
                o.gstin,
                o.phone,
                o.email,
                o.address1,
                o.address2,
                o.city,
                o.state,
                o.pincode,
                uo.is_default
            FROM user_outlet uo
            INNER JOIN outlet o
                ON o.outlet_id = uo.outlet_id
            WHERE uo.user_id = ?
              AND o.is_active = TRUE
            ORDER BY
                uo.is_default DESC,
                o.outlet_name
            `,
            [user.user_id]
        );

        /*
         * Create JWT.
         *
         * Keep permissions OUT of JWT.
         */
        const token = jwt.sign(
            {
                userId: user.user_id,
                userUuid: user.user_uuid,
                companyId: user.company_id,
                roleId: user.role_id,
                roleCode: user.role_code
            },
            process.env.JWT_SECRET,
            {
                expiresIn: '12h'
            }
        );

        /*
         * Update last login.
         */
        await db.query(
            `
            UPDATE app_user
            SET last_login_at = NOW()
            WHERE user_id = ?
            `,
            [user.user_id]
        );

        return res.status(200).json({
            success: true,
            token: token,

            user: {
                userId: user.user_id,
                userUuid: user.user_uuid,
                username: user.username,
                displayName: user.display_name,
                companyId: user.company_id,
                roleId: user.role_id,
                roleCode: user.role_code,
                roleName: user.role_name
            },

            permissions: permissions,

            outlets: outlets
        });

    } catch (error) {

        console.error('Login error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to login'
        });

    } finally {

        db.release();

    }
};