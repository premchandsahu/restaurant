const bcrypt = require('bcrypt');
const crypto = require('crypto');

const db = require('./database');

async function createCaptainUser() {
    const connection = await db.getConnection();

    try {
        // --------------------------------------------------
        // Change these values as required
        // --------------------------------------------------
        const companyId = 1;
        const outletId = 1;

        const username = 'captain01';
        const password = 'Captain@123';
        const displayName = 'Captain 01';
        const mobile = null;
        const email = null;
        const employeeCode = 'CAP001';

        // --------------------------------------------------
        // Get CAPTAIN role
        // --------------------------------------------------
        const [roles] = await connection.query(
            `
            SELECT role_id
            FROM role
            WHERE role_code = 'CAPTAIN'
              AND is_active = TRUE
            LIMIT 1
            `
        );

        if (roles.length === 0) {
            throw new Error(
                'CAPTAIN role does not exist'
            );
        }

        const roleId = roles[0].role_id;

        // --------------------------------------------------
        // Check whether username already exists
        // --------------------------------------------------
        const [existingUsers] = await connection.query(
            `
            SELECT user_id
            FROM app_user
            WHERE company_id = ?
              AND username = ?
            LIMIT 1
            `,
            [companyId, username]
        );

        if (existingUsers.length > 0) {
            throw new Error(
                `Username '${username}' already exists`
            );
        }

        // --------------------------------------------------
        // Generate password hash
        // --------------------------------------------------
        const passwordHash = await bcrypt.hash(
            password,
            10
        );

        // --------------------------------------------------
        // Generate UUID
        // --------------------------------------------------
        const userUuid = crypto.randomUUID();

        // --------------------------------------------------
        // Create user
        // --------------------------------------------------
        const [userResult] = await connection.query(
            `
            INSERT INTO app_user
            (
                user_uuid,
                company_id,
                role_id,
                username,
                password_hash,
                display_name,
                mobile,
                email,
                employee_code,
                is_active
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE)
            `,
            [
                userUuid,
                companyId,
                roleId,
                username,
                passwordHash,
                displayName,
                mobile,
                email,
                employeeCode
            ]
        );

        const userId = userResult.insertId;

        // --------------------------------------------------
        // Assign outlet
        // --------------------------------------------------
        await connection.query(
            `
            INSERT INTO user_outlet
            (
                user_id,
                outlet_id,
                is_default
            )
            VALUES (?, ?, TRUE)
            `,
            [userId, outletId]
        );

        console.log('');
        console.log('Captain user created successfully');
        console.log('----------------------------------');
        console.log('User ID      :', userId);
        console.log('Username     :', username);
        console.log('Password     :', password);
        console.log('Role         : CAPTAIN');
        console.log('Company ID   :', companyId);
        console.log('Outlet ID    :', outletId);
        console.log('');

    } catch (error) {
        console.error(
            'Unable to create Captain user:',
            error.message
        );
    } finally {
        connection.release();
    }
}

createCaptainUser();