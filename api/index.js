const path = require('path');
require('dotenv').config({
    path: path.join(__dirname, '.env')
});

//require('dotenv').config();
const express = require('express');

const {authRoutes, outletRoutes, menuRoutes,orderRoutes, kotRoutes, taxRoutes, billRoutes,customerOrderRoutes, hotelRoutes, appMenuRoutes, inventoryRoutes, purchaseRoutes, stockRoutes,supplierPaymentRoutes,supplierLedgerRoutes,stockAdjustmentRoutes, recipeRoutes,inventoryConsumptionRoutes,exciseRoutes} = require('./router');
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
app.use('/excise', exciseRoutes);
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

app.get('/order/:table_uuid', (req, res) => {
    const tableUuid = String(req.params.table_uuid || '').trim();

    if (!tableUuid) {
        return res.status(400).send('Invalid table QR');
    }

    res.send(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >
    <title>Restaurant Digital Ordering</title>
</head>

<body style="
    font-family: Arial, sans-serif;
    text-align: center;
    padding: 50px 20px;
">

    <h1>Restaurant Digital Ordering</h1>

    <p>
        Please open the Customer App to continue.
    </p>

    <p>
        <a
            href="restappcustomer://table/${encodeURIComponent(tableUuid)}"
            style="
                display:inline-block;
                padding:14px 24px;
                background:#1976d2;
                color:white;
                text-decoration:none;
                border-radius:8px;
                font-weight:bold;
            "
        >
            OPEN CUSTOMER APP
        </a>
    </p>

    <p>
        <a href="https://www.jaihindplaster.com/download/app-release.apk">
            Download Customer App
        </a>
    </p>

</body>
</html>
    `);
});


app.get('/.well-known/assetlinks.json', (req, res) => {
    res.type('application/json');

    res.send([
        {
            relation: [
                'delegate_permission/common.handle_all_urls'
            ],
            target: {
                namespace: 'android_app',
                package_name: 'com.qsoft.restapp_customer',
                sha256_cert_fingerprints: [
                    'C6:93:97:95:77:AF:5E:1B:D1:72:50:DA:4F:F9:AB:44:2C:74:34:A2:CD:6B:5F:0F:9E:69:13:12:25:07:BE:8B'
                ]
            }
        }
    ]);
});

app.get("/test", (req, res) => {
    res.send("Test route is working!");
});
//app.use('/order-items', orderItemsRoutes);

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});