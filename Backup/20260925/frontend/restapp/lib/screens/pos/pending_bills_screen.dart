import 'package:flutter/material.dart';

import '../../models/pos/pending_bill.dart';
import '../../services/pos/pos_order_service.dart';
import 'pos_bill_screen.dart';

class PendingBillsScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const PendingBillsScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<PendingBillsScreen> createState() => _PendingBillsScreenState();
}

class _PendingBillsScreenState extends State<PendingBillsScreen> {
  late final PosOrderService _orderService;

  List<PendingBill> _bills = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _orderService = PosOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bills = await _orderService.getPendingBills(
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _bills = bills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openBill(PendingBill bill) async {
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

    // Payment may have been completed.
    // Refresh the list.
    await _loadBills();
  }

  String _tableDisplay(PendingBill bill) {
    if (bill.logicalCode != null && bill.logicalCode!.isNotEmpty) {
      return bill.logicalCode!;
    }

    if (bill.tableCode != null && bill.tableCode!.isNotEmpty) {
      return bill.tableCode!;
    }

    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Bills'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadBills,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBills,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64),
            SizedBox(height: 12),
            Text(
              'No pending bills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return _buildDesktop();
        }

        return _buildMobile();
      },
    );
  }

  Widget _buildDesktop() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        return _buildBillCard(_bills[index]);
      },
    );
  }

  Widget _buildMobile() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        return _buildBillCard(_bills[index]);
      },
    );
  }

  Widget _buildBillCard(PendingBill bill) {
    final table = _tableDisplay(bill);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openBill(bill),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  table,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill ${bill.billNo ?? bill.billId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text('Order ${bill.orderNo ?? '-'}'),

                    if (bill.customerName != null) Text(bill.customerName!),

                    const SizedBox(height: 5),

                    Text(
                      bill.billStatus,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Balance', style: TextStyle(fontSize: 12)),

                  const SizedBox(height: 3),

                  Text(
                    '₹${bill.balanceAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
