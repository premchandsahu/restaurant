require('dotenv').config();
const express = require('express');

const {authRoutes, outletRoutes, menuRoutes,orderRoutes, kotRoutes, taxRoutes, billRoutes,customerOrderRoutes, hotelRoutes, appMenuRoutes, inventoryRoutes, purchaseRoutes, stockRoutes,supplierPaymentRoutes,supplierLedgerRoutes,stockAdjustmentRoutes, recipeRoutes,inventoryConsumptionRoutes} = require('./router');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const port = process.env.PORT ||3000;



//const orderItemsRoutes = require('./routes/orderItems');
app.use(express.json());
app.use(cors());
app.use(bodyParser.json());


app.use('/auth', authRoutes);
app.use('/outlets', outletRoutes)
app.use('/menu',menuRoutes)
app.use('/orders',orderRoutes)
app.use('/kot',kotRoutes)
app.use('/tax',taxRoutes)
app.use('/bills',billRoutes)
app.use('/customer-order', customerOrderRoutes);
app.use('/hotel', hotelRoutes);
app.use('/app-menu',appMenuRoutes)
app.use('/inventory',inventoryRoutes)
app.use('/inventory/purchases',purchaseRoutes)
app.use('/inventory/stock',stockRoutes)
app.use('/inventory/suppliers', supplierPaymentRoutes);
app.use('/inventory/suppliers', supplierLedgerRoutes);
app.use('/inventory/stock-adjustments', stockAdjustmentRoutes);
app.use('/inventory',recipeRoutes)
app.use(
    '/inventory/consumption',
    inventoryConsumptionRoutes
);

app.get("/test", (req, res) => {
    res.send("Test route is working!");
});
//app.use('/order-items', orderItemsRoutes);

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});