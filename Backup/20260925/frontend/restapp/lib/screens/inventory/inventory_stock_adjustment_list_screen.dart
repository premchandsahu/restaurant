import 'package:flutter/material.dart';

import '../../models/inventory/inventory_stock_adjustment.dart';
import '../../services/inventory/inventory_stock_adjustment_service.dart';
import 'inventory_stock_adjustment_screen.dart';

class InventoryStockAdjustmentListScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryStockAdjustmentListScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryStockAdjustmentListScreen> createState() =>
      _InventoryStockAdjustmentListScreenState();
}

class _InventoryStockAdjustmentListScreenState
    extends State<InventoryStockAdjustmentListScreen> {
  late final InventoryStockAdjustmentService _service;

  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toDateController = TextEditingController();

  List<InventoryStockAdjustment> _adjustments = [];

  String _selectedType = 'ALL';

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _service = InventoryStockAdjustmentService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    final today = DateTime.now();

    final firstDayOfMonth = DateTime(today.year, today.month, 1);

    _fromDateController.text = _formatDate(firstDayOfMonth);

    _toDateController.text = _formatDate(today);

    _loadAdjustments();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  // ============================================================
  // NEW ADJUSTMENT
  // ============================================================

  Future<void> _openNewAdjustment() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryStockAdjustmentScreen(
          outletId: widget.outletId,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadAdjustments();
    }
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('-');

    if (parts.length != 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  Future<void> _pickDate({required TextEditingController controller}) async {
    final existingDate = _parseDate(controller.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: existingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadAdjustments() async {
    if (_fromDateController.text.isEmpty || _toDateController.text.isEmpty) {
      return;
    }

    final fromDate = _parseDate(_fromDateController.text);

    final toDate = _parseDate(_toDateController.text);

    if (fromDate == null || toDate == null) {
      _showMessage('Please enter valid dates');
      return;
    }

    if (fromDate.isAfter(toDate)) {
      _showMessage('From Date cannot be greater than To Date');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result = await _service.getStockAdjustments(
        outletId: widget.outletId,
        fromDate: _fromDateController.text,
        toDate: _toDateController.text,
        adjustmentType: _selectedType == 'ALL' ? null : _selectedType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _adjustments = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // DETAIL
  // ============================================================

  Future<void> _showDetail(InventoryStockAdjustment adjustment) async {
    try {
      final detail = await _service.getStockAdjustment(
        outletId: widget.outletId,
        adjustmentId: adjustment.stockAdjustmentId,
      );

      if (!mounted) {
        return;
      }

      await showDialog(
        context: context,
        builder: (_) {
          return _buildDetailDialog(detail);
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // DETAIL DIALOG
  // ============================================================

  Widget _buildDetailDialog(InventoryStockAdjustment adjustment) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(adjustment.adjustmentNo)),
          Text(
            adjustment.adjustmentType,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 850,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Date: ${adjustment.adjustmentDate}')),
                  Expanded(child: Text('Reason: ${adjustment.reason ?? '-'}')),
                ],
              ),

              const SizedBox(height: 16),

              const Divider(),

              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Material')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Balance')),
                  ],
                  rows: adjustment.items
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.materialCode)),
                            DataCell(Text(item.materialName)),
                            DataCell(Text(item.qty.toStringAsFixed(3))),
                            DataCell(Text(item.unitCode)),
                            DataCell(Text(item.rate.toStringAsFixed(2))),
                            DataCell(Text(item.amount.toStringAsFixed(2))),
                            DataCell(Text(item.balanceQty.toStringAsFixed(3))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${_detailTotal(adjustment).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  double _detailTotal(InventoryStockAdjustment adjustment) {
    if (adjustment.items.isEmpty) {
      return adjustment.totalAmount;
    }

    return adjustment.items.fold(0, (sum, item) => sum + item.amount);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustments'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openNewAdjustment,
              icon: const Icon(Icons.add),
              label: const Text('NEW ADJUSTMENT'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 20 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilters(isDesktop),

                const SizedBox(height: 16),

                _buildSummary(),

                const SizedBox(height: 16),

                _buildList(isDesktop),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(bool isDesktop) {
    final dateFrom = SizedBox(
      width: isDesktop ? 180 : double.infinity,
      child: TextField(
        controller: _fromDateController,
        readOnly: true,
        onTap: () {
          _pickDate(controller: _fromDateController);
        },
        decoration: const InputDecoration(
          labelText: 'From Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month),
        ),
      ),
    );

    final dateTo = SizedBox(
      width: isDesktop ? 180 : double.infinity,
      child: TextField(
        controller: _toDateController,
        readOnly: true,
        onTap: () {
          _pickDate(controller: _toDateController);
        },
        decoration: const InputDecoration(
          labelText: 'To Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month),
        ),
      ),
    );

    final type = SizedBox(
      width: isDesktop ? 180 : double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedType,
        decoration: const InputDecoration(
          labelText: 'Adjustment Type',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'ALL', child: Text('All')),
          DropdownMenuItem(value: 'OPENING', child: Text('Opening')),
          DropdownMenuItem(value: 'INCREASE', child: Text('Increase')),
          DropdownMenuItem(value: 'DECREASE', child: Text('Decrease')),
          DropdownMenuItem(value: 'WASTAGE', child: Text('Wastage')),
          DropdownMenuItem(value: 'DAMAGE', child: Text('Damage')),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            _selectedType = value;
          });
        },
      ),
    );

    final loadButton = SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _loadAdjustments,
        icon: const Icon(Icons.search),
        label: const Text('LOAD'),
      ),
    );

    if (isDesktop) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: dateFrom),
              const SizedBox(width: 12),
              Expanded(child: dateTo),
              const SizedBox(width: 12),
              Expanded(child: type),
              const SizedBox(width: 12),
              loadButton,
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            dateFrom,
            const SizedBox(height: 12),
            dateTo,
            const SizedBox(height: 12),
            type,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: loadButton),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final count = _adjustments.length;

    final totalAmount = _adjustments.fold<double>(
      0,
      (sum, adjustment) => sum + adjustment.totalAmount,
    );

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Adjustments',
            count.toString(),
            Icons.inventory_2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Total Amount',
            totalAmount.toStringAsFixed(2),
            Icons.currency_rupee,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildList(bool isDesktop) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_adjustments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No stock adjustments found',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isDesktop) {
      return Column(
        children: _adjustments
            .map((adjustment) => _buildMobileCard(adjustment))
            .toList(),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Adjustment No')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Action')),
          ],
          rows: _adjustments
              .map(
                (adjustment) => DataRow(
                  cells: [
                    DataCell(Text(adjustment.adjustmentNo)),
                    DataCell(Text(adjustment.adjustmentDate)),
                    DataCell(_typeChip(adjustment.adjustmentType)),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          adjustment.reason ?? '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(adjustment.itemCount.toString())),
                    DataCell(Text(adjustment.totalAmount.toStringAsFixed(2))),
                    DataCell(
                      IconButton(
                        tooltip: 'View',
                        onPressed: () {
                          _showDetail(adjustment);
                        },
                        icon: const Icon(Icons.visibility),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE CARD
  // ============================================================

  Widget _buildMobileCard(InventoryStockAdjustment adjustment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    adjustment.adjustmentNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _typeChip(adjustment.adjustmentType),
              ],
            ),

            const SizedBox(height: 8),

            Text('Date: ${adjustment.adjustmentDate}'),

            const SizedBox(height: 4),

            Text('Reason: ${adjustment.reason ?? '-'}'),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: Text('Items: ${adjustment.itemCount}')),
                Text(
                  adjustment.totalAmount.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showDetail(adjustment);
                },
                icon: const Icon(Icons.visibility),
                label: const Text('VIEW'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TYPE CHIP
  // ============================================================

  Widget _typeChip(String type) {
    Color background;
    IconData icon;

    switch (type.toUpperCase()) {
      case 'OPENING':
        background = Colors.blue;
        icon = Icons.flag;
        break;

      case 'INCREASE':
        background = Colors.green;
        icon = Icons.arrow_upward;
        break;

      case 'DECREASE':
        background = Colors.orange;
        icon = Icons.arrow_downward;
        break;

      case 'WASTAGE':
        background = Colors.red;
        icon = Icons.delete_outline;
        break;

      case 'DAMAGE':
        background = Colors.grey;
        icon = Icons.broken_image;
        break;

      default:
        background = Colors.grey;
        icon = Icons.inventory;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            type,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
