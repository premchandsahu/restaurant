import 'package:flutter/material.dart';

import '../../models/inventory/inventory_stock_balance.dart';
import '../../services/inventory/inventory_stock_balance_service.dart';

class InventoryStockBalanceScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryStockBalanceScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryStockBalanceScreen> createState() =>
      _InventoryStockBalanceScreenState();
}

class _InventoryStockBalanceScreenState
    extends State<InventoryStockBalanceScreen> {
  late final InventoryStockBalanceService _service;

  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toDateController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();

  List<InventoryStockBalance> _balances = [];

  List<InventoryStockBalance> _filteredBalances = [];

  bool _loading = false;

  bool _showNegativeOnly = false;

  @override
  void initState() {
    super.initState();

    _service = InventoryStockBalanceService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    final today = DateTime.now();

    final firstDayOfMonth = DateTime(today.year, today.month, 1);

    _fromDateController.text = _formatDate(firstDayOfMonth);

    _toDateController.text = _formatDate(today);

    _searchController.addListener(_applyFilters);

    _loadStockBalance();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadStockBalance() async {
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
      final result = await _service.getStockBalances(
        outletId: widget.outletId,
        fromDate: _fromDateController.text,
        toDate: _toDateController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _balances = result;
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _balances = [];
        _filteredBalances = [];
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    var rows = List<InventoryStockBalance>.from(_balances);

    if (query.isNotEmpty) {
      rows = rows.where((item) {
        return item.materialCode.toLowerCase().contains(query) ||
            item.materialName.toLowerCase().contains(query);
      }).toList();
    }

    if (_showNegativeOnly) {
      rows = rows.where((item) => item.negativeStock).toList();
    }

    if (mounted) {
      setState(() {
        _filteredBalances = rows;
      });
    }
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  int get _negativeCount {
    return _balances.where((item) => item.negativeStock).length;
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
      appBar: AppBar(title: const Text('Stock Balance')),
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

                _buildSummary(isDesktop),

                const SizedBox(height: 16),

                _buildSearchSection(isDesktop),

                const SizedBox(height: 16),

                _buildStockList(isDesktop),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // DATE FILTERS
  // ============================================================

  Widget _buildFilters(bool isDesktop) {
    final fromDate = SizedBox(
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

    final toDate = SizedBox(
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

    final loadButton = SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _loadStockBalance,
        icon: const Icon(Icons.refresh),
        label: const Text('LOAD'),
      ),
    );

    if (isDesktop) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: fromDate),
              const SizedBox(width: 12),
              Expanded(child: toDate),
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
            fromDate,

            const SizedBox(height: 12),

            toDate,

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

  Widget _buildSummary(bool isDesktop) {
    final cards = [
      _summaryCard(
        title: 'Materials',
        value: _balances.length.toString(),
        icon: Icons.inventory_2,
      ),
      _summaryCard(
        title: 'Negative Stock',
        value: _negativeCount.toString(),
        icon: Icons.warning_amber,
        warning: _negativeCount > 0,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
        ],
      );
    }

    return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    bool warning = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30, color: warning ? Colors.red : null),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: warning ? Colors.red : null,
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
  // SEARCH
  // ============================================================

  Widget _buildSearchSection(bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search material code or name',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Negative Only'),
              selected: _showNegativeOnly,
              onSelected: (selected) {
                setState(() {
                  _showNegativeOnly = selected;
                });

                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STOCK LIST
  // ============================================================

  Widget _buildStockList(bool isDesktop) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_filteredBalances.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  _balances.isEmpty
                      ? 'No stock balance data found'
                      : 'No materials match the filter',
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
        children: _filteredBalances
            .map((item) => _buildMobileCard(item))
            .toList(),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Material')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Opening')),
            DataColumn(label: Text('Purchase')),
            DataColumn(label: Text('Adj. In')),
            DataColumn(label: Text('Adj. Out')),
            DataColumn(label: Text('Consumption')),
            DataColumn(label: Text('Wastage')),
            DataColumn(label: Text('Damage')),
            DataColumn(label: Text('Closing')),
          ],
          rows: _filteredBalances.map((item) {
            return DataRow(
              color: item.negativeStock
                  ? WidgetStatePropertyAll(Colors.red.withOpacity(0.08))
                  : null,
              cells: [
                DataCell(Text(item.materialCode)),
                DataCell(SizedBox(width: 220, child: Text(item.materialName))),
                DataCell(Text(item.unitCode)),
                DataCell(_qtyText(item.openingQty, item)),
                DataCell(_qtyText(item.purchaseQty, item)),
                DataCell(_qtyText(item.adjustmentInQty, item)),
                DataCell(_qtyText(item.adjustmentOutQty, item)),
                DataCell(_qtyText(item.consumptionQty, item)),
                DataCell(
                  _qtyText(item.recipeWastageQty + item.wastageQty, item),
                ),
                DataCell(_qtyText(item.damageQty, item)),
                DataCell(_closingQtyText(item)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP QUANTITY DISPLAY
  // ============================================================

  Widget _qtyText(double quantity, InventoryStockBalance item) {
    return Text(quantity.toStringAsFixed(_displayDecimals(item)));
  }

  Widget _closingQtyText(InventoryStockBalance item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.closingQty.toStringAsFixed(_displayDecimals(item)),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: item.negativeStock ? Colors.red : null,
          ),
        ),
        if (item.negativeStock)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.warning_amber, size: 16, color: Colors.red),
          ),
      ],
    );
  }

  int _displayDecimals(InventoryStockBalance item) {
    final decimalString = item.unitCode.toUpperCase();

    if (decimalString == 'PCS' || decimalString == 'BOTTLE') {
      return 0;
    }

    return 3;
  }

  // ============================================================
  // MOBILE CARD
  // ============================================================

  Widget _buildMobileCard(InventoryStockBalance item) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.materialName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.materialCode}  •  ${item.unitCode}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (item.negativeStock)
                  const Icon(Icons.warning_amber, color: Colors.red),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(child: _mobileValue('Opening', item.openingQty, item)),
                Expanded(
                  child: _mobileValue('Purchase', item.purchaseQty, item),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _mobileValue('Adj. In', item.adjustmentInQty, item),
                ),
                Expanded(
                  child: _mobileValue('Adj. Out', item.adjustmentOutQty, item),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _mobileValue('Consumption', item.consumptionQty, item),
                ),
                Expanded(
                  child: _mobileValue(
                    'Wastage',
                    item.recipeWastageQty + item.wastageQty,
                    item,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _mobileValue('Damage', item.damageQty, item)),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: item.negativeStock
                          ? Colors.red.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.08),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Closing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.closingQty.toStringAsFixed(
                            _displayDecimals(item),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: item.negativeStock ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileValue(
    String label,
    double quantity,
    InventoryStockBalance item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(
            quantity.toStringAsFixed(_displayDecimals(item)),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
