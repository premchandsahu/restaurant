
const authRoutes = require('./authRouter');
const outletRoutes=require('./outletRouter')
const menuRoutes = require('./menuRouter')
const orderRoutes = require('./orderRouter')
const kotRoutes = require('./kotRouter')
const taxRoutes = require('./taxRouter')
const billRoutes = require('./billRouter')
const customerOrderRoutes = require('./customerOrderRouter')

module.exports = {
    authRoutes,
    outletRoutes,
    menuRoutes,
    orderRoutes,
    kotRoutes,
    taxRoutes,
    billRoutes,
    customerOrderRoutes
    
}