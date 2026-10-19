
const authRoutes = require('./authRouter');
const outletRoutes=require('./outletRouter')
const menuRoutes = require('./menuRouter')
const orderRoutes = require('./orderRouter')
const kotRoutes = require('./kotRouter')
const taxRoutes = require('./taxRouter')
const billRoutes = require('./billRouter')
const customerOrderRoutes = require('./customerOrderRouter')
const hotelRoutes = require('./hotelRouter');
const appMenuRoutes = require('./appMenuRouter');
const inventoryRoutes = require('./inventoryRouter');
const purchaseRoutes = require('./purchaseRouter');
const stockRoutes = require('./stockRouter');
const supplierPaymentRoutes = require('./supplierPaymentRouter');
const supplierLedgerRoutes = require('./supplierLedgerRouter');
const stockAdjustmentRoutes = require('./stockAdjustmentRouter');
const recipeRoutes = require('./recipeRouter');
const inventoryConsumptionRoutes =
    require('./inventoryConsumptionRouter');
const exciseRoutes = require('./exciseRouter')


module.exports = {
    authRoutes,
    outletRoutes,
    menuRoutes,
    orderRoutes,
    kotRoutes,
    taxRoutes,
    billRoutes,
    customerOrderRoutes,
    hotelRoutes,
    appMenuRoutes,
    inventoryRoutes,
    purchaseRoutes,
    stockRoutes,
    supplierPaymentRoutes,
    supplierLedgerRoutes,
    stockAdjustmentRoutes,
    recipeRoutes,
    inventoryConsumptionRoutes,
    exciseRoutes
}