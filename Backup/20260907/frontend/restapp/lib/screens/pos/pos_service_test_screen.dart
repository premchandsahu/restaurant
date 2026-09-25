import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/bill_payment_screen.dart';
import 'package:restapp/screens/pos/kitchen_display_screen.dart';

import '../../services/pos/pos_order_service.dart';

class PosServiceTestScreen extends StatefulWidget {
  const PosServiceTestScreen({super.key});

  @override
  State<PosServiceTestScreen> createState() => _PosServiceTestScreenState();
}

class _PosServiceTestScreenState extends State<PosServiceTestScreen> {
  final TextEditingController orderIdController = TextEditingController();

  String result = '';

  bool loading = false;

  // --------------------------------------------------
  // CHANGE THESE VALUES
  // --------------------------------------------------

  final String baseUrl = 'http://localhost:5000';

  final String token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEsInVzZXJVdWlkIjoiYTk2NDMyZTgtYTFiNi0xMWYxLWI2NDYtMDAzNTBjOWVmNGVhIiwiY29tcGFueUlkIjoxLCJyb2xlSWQiOjEsInJvbGVDb2RlIjoiT1dORVIiLCJpYXQiOjE3ODg0MTQ2MTksImV4cCI6MTc4ODQ1NzgxOX0.y-ZqJroi56QahZJLpzh9PWVBptawQFOFszsEOi_MW-4';

  late final PosOrderService service;

  @override
  void initState() {
    super.initState();

    service = PosOrderService(baseUrl: baseUrl, token: token);
  }

  Future<void> testUpdateKOT() async {
    final kots = await service.getStationKOTs(2);

    for (final kot in kots) {
      debugPrint(
        '${kot.kotNo} - '
        '${kot.stationName} - '
        '${kot.status}',
      );
    }
  }

  // --------------------------------------------------
  // Test 1
  // --------------------------------------------------

  Future<void> testCreateOrder() async {
    setState(() {
      loading = true;
      result = 'Creating order...';
    });

    try {
      final order = await service.createOrder(
        outletId: 1,
        orderType: 'DINE_IN',
        tableId: 1,
        guestCount: 2,
      );

      orderIdController.text = order.orderId.toString();

      setState(() {
        result =
            '''
TEST 1 SUCCESS

Order ID: ${order.orderId}
Order No: ${order.orderNo}
Order Type: ${order.orderType}
Order Status: ${order.orderStatus}
Table ID: ${order.tableId}
Grand Total: ${order.grandTotal}
''';
      });
    } catch (e) {
      setState(() {
        result = 'TEST 1 FAILED\n\n$e';
      });
    }

    setState(() {
      loading = false;
    });
  }

  // --------------------------------------------------
  // Test 2
  // --------------------------------------------------

  Future<void> testGetOrder() async {
    final orderId = int.tryParse(orderIdController.text.trim());

    if (orderId == null) {
      setState(() {
        result = 'Please enter a valid Order ID';
      });

      return;
    }

    setState(() {
      loading = true;
      result = 'Getting order...';
    });

    try {
      final order = await service.getOrder(orderId);

      setState(() {
        result =
            '''
TEST 2 SUCCESS

Order ID: ${order.orderId}
Order No: ${order.orderNo}
Status: ${order.orderStatus}

Items: ${order.items.length}

Subtotal: ${order.subtotal}
Tax: ${order.taxAmount}
Grand Total: ${order.grandTotal}
Paid: ${order.paidAmount}
Balance: ${order.balanceAmount}
''';
      });
    } catch (e) {
      setState(() {
        result = 'TEST 2 FAILED\n\n$e';
      });
    }

    setState(() {
      loading = false;
    });
  }

  // --------------------------------------------------
  // Test 3
  // --------------------------------------------------

  Future<void> testAddItem() async {
    final orderId = int.tryParse(orderIdController.text.trim());

    if (orderId == null) {
      setState(() {
        result = 'Please enter a valid Order ID';
      });

      return;
    }

    setState(() {
      loading = true;
      result = 'Adding item...';
    });

    try {
      final order = await service.addItem(
        orderId: orderId,

        menuItemId: 1,

        variantId: 2,

        qty: 2,
      );

      setState(() {
        result =
            '''
TEST 3 SUCCESS

Order ID: ${order.orderId}
Order No: ${order.orderNo}

Items: ${order.items.length}

Subtotal: ${order.subtotal}
Tax: ${order.taxAmount}
Grand Total: ${order.grandTotal}
Balance: ${order.balanceAmount}
''';
      });
    } catch (e) {
      setState(() {
        result = 'TEST 3 FAILED\n\n$e';
      });
    }

    setState(() {
      loading = false;
    });
  }

  void callKDS() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillPaymentScreen(
          billId: 3,
          grandTotal: 5000,
          paidAmount: 1000,
          billNo: "3",
          tableName: "T02",
          logicalCode: "T02B",
          baseUrl: baseUrl,
          token: token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS Service Tests')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            TextField(
              controller: orderIdController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Order ID',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,

              children: [
                ElevatedButton(
                  onPressed: loading ? null : callKDS,

                  child: const Text('Test 1 - Update KOT'),
                ),

                ElevatedButton(
                  onPressed: loading ? null : testGetOrder,

                  child: const Text('Test 2 - Get Order'),
                ),

                ElevatedButton(
                  onPressed: loading ? null : testAddItem,

                  child: const Text('Test 3 - Add Item'),
                ),
              ],
            ),

            const SizedBox(height: 30),

            if (loading) const CircularProgressIndicator(),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  result,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    orderIdController.dispose();

    super.dispose();
  }
}
