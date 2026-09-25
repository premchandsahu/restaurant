const jwt = require('jsonwebtoken');

module.exports = function authenticate(req, res, next) {

    try {

        const authHeader = req.headers.authorization;

        if (!authHeader ||
            !authHeader.startsWith('Bearer ')) {

            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        const token = authHeader.substring(7);

        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET
        );

        /*
         * Make logged-in user available
         * to controllers.
         */
        req.user = decoded;

        next();

    } catch (error) {

        console.error('Authentication error:', error.message);

        return res.status(401).json({
            success: false,
            message: 'Invalid or expired token'
        });
    }
};