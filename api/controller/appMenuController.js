const conn = require('../database');

exports.getMyMenus = async (req, res) => {

    let db;

    try {

        if (!req.user || !req.user.roleId) {
            return res.status(401).json({
                success: false,
                message: 'User role information not available'
            });
        }

        db = await conn.getConnection();

        /*
         * Get all menus assigned to the logged-in user's role.
         *
         * A menu is returned only when:
         *
         * 1. It is assigned to the role through role_app_menu
         *
         * AND
         *
         * 2. It has no required permission
         *    OR
         *    the role has the required permission.
         *
         * Group menus have required_permission = NULL.
         */

        const [rows] = await db.query(
            `
            SELECT
                m.menu_id,
                m.parent_menu_id,
                m.menu_code,
                m.menu_name,
                m.module_name,
                m.icon_name,
                m.route_name,
                m.required_permission,
                m.display_order,
                m.is_group

            FROM role_app_menu ram

            INNER JOIN app_menu m
                ON m.menu_id = ram.menu_id

            LEFT JOIN permission required_p
                ON required_p.permission_code =
                   m.required_permission

            LEFT JOIN role_permission rp
                ON rp.role_id = ram.role_id
               AND rp.permission_id = required_p.permission_id

            WHERE ram.role_id = ?
              AND m.is_active = 1

              AND (
                    m.required_permission IS NULL
                    OR rp.permission_id IS NOT NULL
                  )

            ORDER BY
                m.display_order,
                m.menu_id
            `,
            [req.user.roleId]
        );

        /*
         * Convert MySQL rows into application menu objects.
         */
        const menus = rows.map(row => ({
            menuId: row.menu_id,
            parentMenuId: row.parent_menu_id,
            menuCode: row.menu_code,
            menuName: row.menu_name,
            moduleName: row.module_name,
            iconName: row.icon_name,
            routeName: row.route_name,
            requiredPermission: row.required_permission,
            displayOrder: row.display_order,
            isGroup: Boolean(row.is_group),
            children: []
        }));

        /*
         * Build hierarchy.
         */

    
        const menuMap = new Map();

        for (const menu of menus) {
            menuMap.set(menu.menuId, menu);
        }
        //console.log(menuMap);

        const rootMenus = [];

        for (const menu of menus) {

            if (menu.parentMenuId === null) {

                rootMenus.push(menu);

            } else {

                const parent = menuMap.get(menu.parentMenuId);

                if (parent) {
                    parent.children.push(menu);
                }
            }
        }

        return res.status(200).json({
            success: true,
            menus: rootMenus
        });

    } catch (error) {

        console.error('Get application menus error:', error);

        return res.status(500).json({
            success: false,
            message: 'Unable to load application menus'
        });

    } finally {

        if (db) {
            db.release();
        }
    }
};