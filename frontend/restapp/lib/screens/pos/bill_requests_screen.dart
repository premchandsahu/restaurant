import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/pos/bill.dart';
import '../../services/pos/pos_order_service.dart';
import 'pos_bill_screen.dart';

class BillRequestsScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const BillRequestsScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<BillRequestsScreen> createState() => _BillRequestsScreenState();
}

class _BillRequestsScreenState extends State<BillRequestsScreen> {
  late final PosOrderService _orderService;

  Timer? _timer;

  List<Map<String, dynamic>> _requests = [];

  bool _loading = true;
  String? _errorMessage;

  int? _creatingBillOrderId;

  @override
  void initState() {
    super.initState();

    _orderService = PosOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadRequests();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadRequests());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final response = await _getBillRequests();

      if (!mounted) return;

      setState(() {
        _requests = response;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getBillRequests() async {
    final response = await _orderService.getBillRequests(
      outletId: widget.outletId,
    );

    return response;
  }

  Future<void> _createBill(Map<String, dynamic> request) async {
    if (_creatingBillOrderId != null) {
      return;
    }

    final orderId = NumberHelper.toInt(request['order_id']);

    if (orderId == null) {
      _showMessage('Invalid order ID');
      return;
    }

    setState(() {
      _creatingBillOrderId = orderId;
    });

    try {
      final Bill bill = await _orderService.createBill(orderId: orderId);

      if (!mounted) return;

      // Remove the request immediately from this screen.
      setState(() {
        _requests.removeWhere(
          (item) => NumberHelper.toInt(item['order_id']) == orderId,
        );

        _creatingBillOrderId = null;
      });

      // Open the generated bill.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PosBillScreen(
            billId: bill.billId,
            baseUrl: widget.baseUrl,
            token: widget.token,
          ),
        ),
      );

      // Refresh when returning.
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _creatingBillOrderId = null;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayText(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;

    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Unable to load bill requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRequests,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64),
            SizedBox(height: 12),
            Text(
              'No bill requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('Customer bill requests will appear here.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];

          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final orderId = NumberHelper.toInt(request['order_id']);

    final creating = _creatingBillOrderId == orderId;

    final tableCode = _displayText(request['table_code']);

    final logicalCode = _displayText(request['logical_code']);

    final customerName = _displayText(request['customer_name']);

    final customerPhone = _displayText(request['customer_phone']);

    final orderNo = _displayText(request['order_no']);

    final orderStatus = _displayText(request['order_status']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 28),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Bill Request',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Chip(label: Text(orderStatus)),
              ],
            ),

            const Divider(),

            _infoRow(
              'Table',
              logicalCode.isNotEmpty ? '$tableCode / $logicalCode' : tableCode,
            ),

            _infoRow('Order No', orderNo),

            _infoRow(
              'Customer',
              customerName.isNotEmpty ? customerName : 'Guest',
            ),

            if (customerPhone.isNotEmpty) _infoRow('Phone', customerPhone),

            _infoRow('Amount', '₹${_money(request['grand_total'])}'),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: creating ? null : () => _createBill(request),
                icon: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: Text(creating ? 'Creating Bill...' : 'CREATE BILL'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Small helper for nullable integer conversion.
// ------------------------------------------------------------

class NumberHelper {
  static int? toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }
}
