import 'dart:async';
import 'package:flutter/material.dart';
//import 'package:restapp/screens/pos/customer_menu_screen.dart';
import 'package:restapp_customer/models/customer/customer_order_status.dart';
import 'package:restapp_customer/services/customer/customer_order_service.dart';
import 'customer_menu_screen.dart';
import 'customer_bill_screen.dart';
//import '../../models/pos/customer_order_status.dart';
//import '../../services/pos/customer_order_service.dart';
//import 'pos_bill_screen.dart';

class CustomerOrderStatusScreen extends StatefulWidget {
  final String customerSessionToken;
  final String baseUrl;

  const CustomerOrderStatusScreen({
    super.key,
    required this.customerSessionToken,
    required this.baseUrl,
  });

  @override
  State<CustomerOrderStatusScreen> createState() =>
      _CustomerOrderStatusScreenState();
}

class _CustomerOrderStatusScreenState extends State<CustomerOrderStatusScreen>
    with WidgetsBindingObserver {
  late final CustomerOrderService _service;
  Timer? _statusTimer;
  bool _statusRequestInProgress = false;
  CustomerOrderStatus? _data;
  final Map<int, Map<String, dynamic>> _customerBills = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = CustomerOrderService(baseUrl: widget.baseUrl, token: '');

    _loadOrders();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _autoRefresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoRefresh() async {
    if (!mounted) return;

    // Prevent another request while one is already running.
    if (_statusRequestInProgress) return;

    // Don't refresh while the initial/manual refresh is running.
    if (_loading || _refreshing) return;

    _statusRequestInProgress = true;

    try {
      final result = await _service.getCustomerOrderStatus(
        customerSessionToken: widget.customerSessionToken,
      );

      if (!mounted) return;

      setState(() {
        _data = result;
      });

      await _checkCustomerBills(result);
    } catch (e) {
      // Don't show a SnackBar every 5 seconds if
      // the network temporarily goes down.
      debugPrint('Automatic order status refresh failed: $e');
    } finally {
      _statusRequestInProgress = false;
    }
  }

  Future<void> _checkCustomerBills(CustomerOrderStatus result) async {
    for (final order in result.orders) {
      if (!order.billRequested) {
        continue;
      }

      // Already obtained the bill for this order.
      if (_customerBills.containsKey(order.orderId)) {
        continue;
      }

      try {
        final billData = await _service.getCustomerBill(
          customerSessionToken: widget.customerSessionToken,
          orderId: order.orderId,
        );

        if (!mounted) return;

        setState(() {
          _customerBills[order.orderId] = billData;
        });
      } catch (e) {
        // Bill may not have been created yet.
        // The next polling cycle will try again.
        debugPrint(
          'Customer bill not ready for order '
          '${order.orderId}: $e',
        );
      }
    }
  }

  // ----------------------------------------------------------
  // Load order status
  // ----------------------------------------------------------

  Future<void> _loadOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await _service.getCustomerOrderStatus(
        customerSessionToken: widget.customerSessionToken,
      );

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
        _refreshing = false;
      });

      await _checkCustomerBills(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString();
      });
    }
  }

  // ----------------------------------------------------------
  // Refresh
  // ----------------------------------------------------------

  Future<void> _refresh() async {
    await _loadOrders(refresh: true);
  }

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_data == null) {
      return const Center(child: Text('No order information available'));
    }

    return RefreshIndicator(onRefresh: _refresh, child: _buildOrderContent());
  }

  // ----------------------------------------------------------
  // Error
  // ----------------------------------------------------------

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load your order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFoodButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerMenuScreen(
                customerSessionToken: widget.customerSessionToken,
                baseUrl: widget.baseUrl,
              ),
            ),
          );
        },
        icon: const Icon(Icons.restaurant_menu),
        label: const Text(
          'ORDER FOOD',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Main content
  // ----------------------------------------------------------

  Widget _buildOrderContent() {
    final data = _data!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        _buildCustomerHeader(data),

        const SizedBox(height: 12),

        if (data.orders.isEmpty) ...[
          _buildOrderFoodButton(),

          const SizedBox(height: 16),

          _buildNoOrders(),
        ] else
          ...data.orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOrderCard(order),
            ),
          ),
      ],
    );
  } // ----------------------------------------------------------
  // Customer / table header
  // ----------------------------------------------------------

  Widget _buildCustomerHeader(CustomerOrderStatus data) {
    final customer = data.customerSession.customerName ?? 'Customer';

    final tableId = data.table.tableId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                customer.isNotEmpty ? customer[0].toUpperCase() : 'C',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $customer',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Table ${tableId ?? ''}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // No orders
  // ----------------------------------------------------------

  Widget _buildNoOrders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Start your order by selecting items from the menu.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your orders will appear here.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestBill(CustomerOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request Bill'),
          content: Text(
            'Request the bill for Order '
            '#${order.orderNo ?? order.orderId}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('REQUEST'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _refreshing = true;
    });

    try {
      await _service.requestBill(
        customerSessionToken: widget.customerSessionToken,
        orderId: order.orderId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill requested successfully')),
      );

      await _loadOrders(refresh: true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _refreshing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildRequestBillButton(CustomerOrder order) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _requestBill(order),
          icon: const Icon(Icons.receipt_long),
          label: const Text('REQUEST BILL'),
        ),
      ),
    );
  }
  // ----------------------------------------------------------
  // Order card
  // ----------------------------------------------------------

  Widget _buildOrderCard(CustomerOrder order) {
    final status = (order.orderStatus ?? 'OPEN').toUpperCase();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.orderNo ?? order.orderId}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),

            if (order.logicalCode != null) ...[
              const SizedBox(height: 5),
              Text(
                order.logicalCode!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],

            const Divider(height: 24),

            if (order.items.isEmpty)
              const Text('No items')
            else
              ...order.items.map((item) => _buildItem(order, item)),

            const Divider(height: 24),

            _buildTotalRow('Subtotal', order.subtotal),

            if (order.itemDiscount > 0)
              _buildTotalRow('Item Discount', -order.itemDiscount),

            if (order.billDiscount > 0)
              _buildTotalRow('Bill Discount', -order.billDiscount),

            _buildTotalRow('Tax', order.taxAmount),

            if (order.roundingAmount != 0)
              _buildTotalRow('Rounding', order.roundingAmount),

            const Divider(),

            _buildTotalRow(
              'Grand Total',
              order.grandTotal,
              bold: true,
              fontSize: 18,
            ),

            if (order.paidAmount > 0) _buildTotalRow('Paid', order.paidAmount),

            if (order.balanceAmount > 0)
              _buildTotalRow('Balance', order.balanceAmount, bold: true),

            if (order.billRequested)
              _customerBills.containsKey(order.orderId)
                  ? _buildBillReady(order)
                  : _buildBillRequested()
            else if (order.balanceAmount > 0 &&
                order.orderStatus != 'CANCELLED' &&
                order.orderStatus != 'VOID') ...[
              _buildRequestBillButton(order),
              const SizedBox(height: 8),
              _buildAddMoreItemsButton(order),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreItemsButton(CustomerOrder order) {
    final status = (order.orderStatus ?? 'OPEN').toUpperCase();

    const blockedStatuses = ['BILLED', 'PAID', 'CANCELLED', 'VOID', 'MERGED'];

    if (blockedStatuses.contains(status)) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerMenuScreen(
                customerSessionToken: widget.customerSessionToken,
                baseUrl: widget.baseUrl,
                existingOrderId: order.orderId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('ADD MORE ITEMS'),
      ),
    );
  }
  // ----------------------------------------------------------
  // Order item
  // ----------------------------------------------------------

  Widget _buildItem(CustomerOrder order, CustomerOrderItem item) {
    final itemStatus = (item.status ?? 'OPEN').toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName ?? 'Item',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),

                if (item.variantName != null && item.variantName!.isNotEmpty)
                  Text(
                    item.variantName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                if (item.specialInstruction != null &&
                    item.specialInstruction!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Note: ${item.specialInstruction}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildItemStatusChip(itemStatus),

              if (itemStatus == 'OPEN')
                TextButton(
                  onPressed: () => _cancelItem(order: order, item: item),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelItem({
    required CustomerOrder order,
    required CustomerOrderItem item,
  }) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel ${item.itemName ?? 'this item'}?'),
              const SizedBox(height: 16),

              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('CANCEL ITEM'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();

    reasonController.dispose();

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _refreshing = true;
    });

    try {
      await _service.cancelOrderItem(
        customerSessionToken: widget.customerSessionToken,
        orderId: order.orderId,
        orderItemId: item.orderItemId,
        reason: reason.isEmpty ? 'Cancelled by customer' : reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item cancelled successfully')),
      );

      await _loadOrders(refresh: true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _refreshing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ----------------------------------------------------------
  // Order status chip
  // ----------------------------------------------------------

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _displayStatus(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Widget _buildItemStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _displayStatus(status),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: _statusColor(status),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Bill requested
  // ----------------------------------------------------------

  Widget _buildBillRequested() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Icon(Icons.receipt_long),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bill requested. Please wait for the staff.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillReady(CustomerOrder order) {
    final billData = _customerBills[order.orderId];

    if (billData == null) {
      return _buildBillRequested();
    }

    final rawBill = billData['bill'];

    if (rawBill is! Map) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        child: const Text('Bill information is not available.'),
      );
    }

    final bill = Map<String, dynamic>.from(rawBill);

    final billNo = bill['bill_no']?.toString() ?? '';

    final grandTotal =
        double.tryParse(bill['grand_total']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bill Ready',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (billNo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Bill No: $billNo'),
          ],

          const SizedBox(height: 4),

          Text(
            'Amount: ₹${grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerBillScreen(billData: billData),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('VIEW BILL'),
            ),
          ),
        ],
      ),
    );
  }
  // ----------------------------------------------------------
  // Total row
  // ----------------------------------------------------------

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool bold = false,
    double fontSize = 14,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Status helpers
  // ----------------------------------------------------------

  String _displayStatus(String status) {
    switch (status) {
      case 'SENT_TO_KITCHEN':
        return 'KITCHEN';

      case 'NEW':
        return 'ACCEPTED';

      case 'ACCEPTED':
        return 'ACCEPTED';

      case 'PREPARING':
        return 'PREPARING';

      case 'READY':
        return 'READY';

      case 'SERVED':
        return 'SERVED';

      case 'PREPARING':
        return 'PREPARING';

      case 'READY':
        return 'READY';

      case 'SERVED':
        return 'SERVED';

      case 'CANCELLED':
        return 'CANCELLED';

      case 'CONFIRMED':
        return 'CONFIRMED';

      case 'BILLED':
        return 'BILLED';

      case 'PAID':
        return 'PAID';

      case 'OPEN':
        return 'OPEN';

      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;

      case 'CONFIRMED':
        return Colors.blue;

      case 'SENT_TO_KITCHEN':
        return Colors.deepOrange;

      case 'PREPARING':
        return Colors.indigo;

      case 'READY':
        return Colors.green;

      case 'SERVED':
        return Colors.teal;

      case 'BILLED':
        return Colors.purple;

      case 'PAID':
        return Colors.green;

      case 'CANCELLED':
        return Colors.red;

      case 'VOID':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }
}
