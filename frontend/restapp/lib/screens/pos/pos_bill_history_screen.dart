import 'package:flutter/material.dart';

import '../../models/pos/bill_history.dart';
import '../../services/pos/bill_history_service.dart';
import '../../services/api_client.dart';
import 'pos_bill_screen.dart';
import '../../models/pos/restaurant_table.dart';
import '../../models/pos/pos_layout.dart';

class PosBillHistoryScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const PosBillHistoryScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<PosBillHistoryScreen> createState() => _PosBillHistoryScreenState();
}

class _PosBillHistoryScreenState extends State<PosBillHistoryScreen> {
  late final BillHistoryService _billHistoryService;
  List<RestaurantTable> _tables = [];

  int? _selectedTableId;
  final TextEditingController _billNoController = TextEditingController();

  final TextEditingController _orderNoController = TextEditingController();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  String _billStatus = 'ALL';
  String _paymentStatus = 'ALL';

  List<BillHistory> _bills = [];

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _billHistoryService = BillHistoryService(apiClient: widget.apiClient);
    _loadTables();
    _loadBills();
  }

  Future<void> _loadTables() async {
    try {
      final response = await widget.apiClient.get(
        '/outlets/${widget.outletId}/pos-layout',
      );

      final result = PosLayout.fromJson(response);

      if (!mounted) return;

      setState(() {
        _tables = result.tables;
      });
    } catch (e) {
      debugPrint('Unable to load tables: $e');
    }
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _orderNoController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildSummary() {
    double total = 0;
    double paid = 0;
    double pending = 0;

    for (final bill in _bills) {
      total += bill.grandTotal;
      paid += bill.paidAmount;
      pending += bill.balanceAmount;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 30,
          runSpacing: 8,
          children: [
            _buildSummaryItem('Bills', _bills.length.toString()),
            _buildSummaryItem('Total', '₹${total.toStringAsFixed(2)}'),
            _buildSummaryItem('Paid', '₹${paid.toStringAsFixed(2)}'),
            _buildSummaryItem('Pending', '₹${pending.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() {
        _fromDate = selected;

        if (_fromDate.isAfter(_toDate)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() {
        _toDate = selected;

        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      });
    }
  }

  Future<void> _loadBills() async {
    if (_fromDate.isAfter(_toDate)) {
      setState(() {
        _errorMessage = 'From Date cannot be after To Date.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final bills = await _billHistoryService.getBillHistory(
        outletId: widget.outletId,
        fromDate: _formatDate(_fromDate),
        toDate: _formatDate(_toDate),
        billNo: _billNoController.text,
        orderNo: _orderNoController.text,
        tableId: _selectedTableId,
        billStatus: _billStatus,
        paymentStatus: _paymentStatus,
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
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openBill(BillHistory bill) async {
    if (bill.billId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosBillScreen(
          billId: bill.billId,
          baseUrl: widget.apiClient.baseUrl,
          token: widget.apiClient.token ?? "",
        ),
      ),
    );

    // Reload because payment may have been made
    // from the bill screen.
    await _loadBills();
  }

  String _displayDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    if (value.length >= 10) {
      return value.substring(0, 10);
    }

    return value;
  }

  Widget _buildFilters(bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isDesktop ? 150 : 140,
              child: InkWell(
                onTap: _selectFromDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDate(_fromDate)),
                ),
              ),
            ),

            SizedBox(
              width: isDesktop ? 150 : 140,
              child: InkWell(
                onTap: _selectToDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'To Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDate(_toDate)),
                ),
              ),
            ),

            SizedBox(
              width: isDesktop ? 150 : 140,
              child: TextField(
                controller: _billNoController,
                decoration: const InputDecoration(
                  labelText: 'Bill No',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            SizedBox(
              width: isDesktop ? 150 : 140,
              child: TextField(
                controller: _orderNoController,
                decoration: const InputDecoration(
                  labelText: 'Order No',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: isDesktop ? 160 : 140,
              child: DropdownButtonFormField<int?>(
                value: _selectedTableId,
                decoration: const InputDecoration(
                  labelText: 'Table',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Tables'),
                  ),
                  ..._tables.map(
                    (table) => DropdownMenuItem<int?>(
                      value: table.tableId,
                      child: Text(
                        table.tableCode.isNotEmpty
                            ? table.tableCode
                            : table.tableName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTableId = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: isDesktop ? 150 : 140,
              child: DropdownButtonFormField<String>(
                value: _billStatus,
                decoration: const InputDecoration(
                  labelText: 'Bill Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'FINAL', child: Text('Final')),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _billStatus = value;
                  });
                },
              ),
            ),

            SizedBox(
              width: isDesktop ? 150 : 140,
              child: DropdownButtonFormField<String>(
                value: _paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Payment',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _paymentStatus = value;
                  });
                },
              ),
            ),

            ElevatedButton.icon(
              onPressed: _loading ? null : _loadBills,
              icon: const Icon(Icons.search),
              label: const Text('SEARCH'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(BillHistory bill) {
    final paid = bill.isPaid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: InkWell(
        onTap: () => _openBill(bill),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bill ${bill.billNo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Text(
                    paid ? 'PAID' : 'PENDING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: paid ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text('Date: ${_displayDate(bill.billDate)}'),

              if (bill.orderNo != null) Text('Order: ${bill.orderNo}'),

              Text('Table: ${bill.displayTable}'),

              if (bill.customerName != null && bill.customerName!.isNotEmpty)
                Text('Customer: ${bill.customerName}'),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Grand Total: '
                      '₹${bill.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (!paid)
                    Text(
                      'Balance: '
                      '₹${bill.balanceAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Bill No')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Order No')),
          DataColumn(label: Text('Table')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Balance')),
        ],
        rows: _bills.map((bill) {
          return DataRow(
            onSelectChanged: (_) => _openBill(bill),
            cells: [
              DataCell(Text(bill.billNo)),
              DataCell(Text(_displayDate(bill.billDate))),
              DataCell(Text(bill.orderNo ?? '-')),
              DataCell(Text(bill.displayTable)),
              DataCell(Text(bill.customerName ?? '-')),
              DataCell(Text(bill.isPaid ? 'PAID' : 'PENDING')),
              DataCell(Text('₹${bill.grandTotal.toStringAsFixed(2)}')),
              DataCell(Text('₹${bill.paidAmount.toStringAsFixed(2)}')),
              DataCell(Text('₹${bill.balanceAmount.toStringAsFixed(2)}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResults(bool isDesktop) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_bills.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('No bills found for the selected filters.'),
        ),
      );
    }

    if (isDesktop) {
      return _buildDesktopTable();
    }

    return ListView.builder(
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        return _buildBillCard(_bills[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: _buildFilters(isDesktop),
          ),

          if (!_loading && _errorMessage == null && _bills.isNotEmpty)
            _buildSummary(),

          Expanded(child: _buildResults(isDesktop)),
        ],
      ),
    );
  }
}
