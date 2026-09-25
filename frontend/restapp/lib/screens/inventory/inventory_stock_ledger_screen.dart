import 'package:flutter/material.dart';

import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_stock_ledger.dart';
import '../../services/inventory/inventory_raw_material_service.dart';
import '../../services/inventory/inventory_stock_ledger_service.dart';

class InventoryStockLedgerScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryStockLedgerScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryStockLedgerScreen> createState() =>
      _InventoryStockLedgerScreenState();
}

class _InventoryStockLedgerScreenState
    extends State<InventoryStockLedgerScreen> {
  late final InventoryStockLedgerService _ledgerService;
  late final InventoryRawMaterialService _rawMaterialService;

  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toDateController = TextEditingController();

  final TextEditingController _materialSearchController =
      TextEditingController();

  List<InventoryRawMaterial> _rawMaterials = [];

  InventoryRawMaterial? _selectedMaterial;

  InventoryStockLedger? _ledger;

  bool _loadingMaterials = false;
  bool _loadingLedger = false;

  @override
  void initState() {
    super.initState();

    _ledgerService = InventoryStockLedgerService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _rawMaterialService = InventoryRawMaterialService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    final today = DateTime.now();

    final firstDayOfMonth = DateTime(today.year, today.month, 1);

    _fromDateController.text = _formatDate(firstDayOfMonth);

    _toDateController.text = _formatDate(today);

    _loadRawMaterials();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _materialSearchController.dispose();
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
  // LOAD RAW MATERIALS
  // ============================================================

  Future<void> _loadRawMaterials() async {
    setState(() {
      _loadingMaterials = true;
    });

    try {
      final materials = await _rawMaterialService.getRawMaterials(
        outletId: widget.outletId,
      );

      if (!mounted) {
        return;
      }

      materials.sort(
        (a, b) => a.materialName.toLowerCase().compareTo(
          b.materialName.toLowerCase(),
        ),
      );

      setState(() {
        _rawMaterials = materials;
        _loadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMaterials = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // SELECT MATERIAL
  // ============================================================

  Future<void> _selectMaterial() async {
    if (_rawMaterials.isEmpty) {
      _showMessage(
        _loadingMaterials
            ? 'Loading raw materials...'
            : 'No raw materials found',
      );
      return;
    }

    final searchController = TextEditingController();

    List<InventoryRawMaterial> filtered = List.from(_rawMaterials);

    final selected = await showDialog<InventoryRawMaterial>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Raw Material'),
              content: SizedBox(
                width: 600,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search material code or name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final query = value.trim().toLowerCase();

                        setDialogState(() {
                          if (query.isEmpty) {
                            filtered = List.from(_rawMaterials);
                          } else {
                            filtered = _rawMaterials
                                .where(
                                  (item) =>
                                      item.materialCode.toLowerCase().contains(
                                        query,
                                      ) ||
                                      item.materialName.toLowerCase().contains(
                                        query,
                                      ),
                                )
                                .toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No materials found'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];

                                return ListTile(
                                  title: Text(item.materialName),
                                  subtitle: Text(
                                    '${item.materialCode} • ${item.unitCode}',
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogContext, item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('CANCEL'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();

    if (selected != null && mounted) {
      setState(() {
        _selectedMaterial = selected;
        _ledger = null;
        _materialSearchController.text =
            '${selected.materialCode} - ${selected.materialName}';
      });
    }
  }

  // ============================================================
  // LOAD LEDGER
  // ============================================================

  Future<void> _loadLedger() async {
    final material = _selectedMaterial;

    if (material == null) {
      _showMessage('Please select a raw material');
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
      _loadingLedger = true;
    });

    try {
      final result = await _ledgerService.getStockLedger(
        outletId: widget.outletId,
        rawMaterialId: material.rawMaterialId,
        fromDate: _fromDateController.text,
        toDate: _toDateController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _ledger = result;
        _loadingLedger = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ledger = null;
        _loadingLedger = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // SOURCE COLOR
  // ============================================================

  Color _sourceColor(String sourceType) {
    switch (sourceType.toUpperCase()) {
      case 'PURCHASE':
        return Colors.green;

      case 'OPENING':
        return Colors.blue;

      case 'ADJUSTMENT_IN':
        return Colors.teal;

      case 'ADJUSTMENT_OUT':
        return Colors.orange;

      case 'WASTAGE':
      case 'RECIPE_WASTAGE':
        return Colors.red;

      case 'DAMAGE':
        return Colors.deepOrange;

      case 'SALE_CONSUMPTION':
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // SOURCE ICON
  // ============================================================

  IconData _sourceIcon(String sourceType) {
    switch (sourceType.toUpperCase()) {
      case 'PURCHASE':
        return Icons.shopping_cart;

      case 'OPENING':
        return Icons.flag;

      case 'ADJUSTMENT_IN':
        return Icons.add_circle_outline;

      case 'ADJUSTMENT_OUT':
        return Icons.remove_circle_outline;

      case 'WASTAGE':
      case 'RECIPE_WASTAGE':
        return Icons.delete_outline;

      case 'DAMAGE':
        return Icons.broken_image_outlined;

      case 'SALE_CONSUMPTION':
        return Icons.restaurant;

      default:
        return Icons.inventory_2_outlined;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Ledger')),
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

                if (_loadingLedger)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_ledger != null)
                  _buildLedger(isDesktop)
                else
                  _buildEmptyState(),
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
    final materialField = GestureDetector(
      onTap: _selectMaterial,
      child: AbsorbPointer(
        child: TextField(
          controller: _materialSearchController,
          decoration: InputDecoration(
            labelText: 'Raw Material',
            hintText: 'Select material',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.inventory_2),
            suffixIcon: _loadingMaterials
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
        ),
      ),
    );

    final fromDate = SizedBox(
      width: isDesktop ? 170 : double.infinity,
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
      width: isDesktop ? 170 : double.infinity,
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
        onPressed: _loadingLedger ? null : _loadLedger,
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
              Expanded(child: materialField),
              const SizedBox(width: 12),
              fromDate,
              const SizedBox(width: 12),
              toDate,
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
            materialField,

            const SizedBox(height: 12),

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
  // LEDGER
  // ============================================================

  Widget _buildLedger(bool isDesktop) {
    final ledger = _ledger!;

    return Column(
      children: [
        _buildMaterialHeader(ledger),

        const SizedBox(height: 16),

        _buildSummary(ledger, isDesktop),

        const SizedBox(height: 16),

        _buildTransactions(ledger, isDesktop),
      ],
    );
  }

  // ============================================================
  // MATERIAL HEADER
  // ============================================================

  Widget _buildMaterialHeader(InventoryStockLedger ledger) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.inventory_2, size: 36),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.rawMaterial.materialName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ledger.rawMaterial.materialCode} • ${ledger.rawMaterial.unitCode}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            if (ledger.summary.negativeStock)
              const Tooltip(
                message: 'Negative closing stock',
                child: Icon(Icons.warning_amber, color: Colors.red, size: 30),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(InventoryStockLedger ledger, bool isDesktop) {
    final summary = ledger.summary;

    final cards = [
      _summaryCard(
        'Opening',
        _formatQty(summary.openingQty, ledger),
        Icons.flag,
      ),
      _summaryCard(
        'Period In',
        _formatQty(summary.periodInQty, ledger),
        Icons.arrow_upward,
      ),
      _summaryCard(
        'Period Out',
        _formatQty(summary.periodOutQty, ledger),
        Icons.arrow_downward,
      ),
      _summaryCard(
        'Closing',
        _formatQty(summary.closingQty, ledger),
        Icons.inventory_2,
        warning: summary.negativeStock,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon, {
    bool warning = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: warning ? Colors.red : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
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
  // TRANSACTIONS
  // ============================================================

  Widget _buildTransactions(InventoryStockLedger ledger, bool isDesktop) {
    if (ledger.transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No transactions found for the selected period',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    if (!isDesktop) {
      return Column(
        children: ledger.transactions
            .map((transaction) => _buildMobileTransaction(transaction, ledger))
            .toList(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('In')),
                  DataColumn(label: Text('Out')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Remarks')),
                ],
                rows: ledger.transactions.map((transaction) {
                  return DataRow(
                    cells: [
                      DataCell(Text(transaction.date)),

                      DataCell(_sourceChip(transaction.sourceType)),

                      DataCell(Text(transaction.referenceNo ?? '-')),

                      DataCell(
                        SizedBox(
                          width: 230,
                          child: Text(
                            transaction.description ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          _formatTransactionQty(transaction.quantityIn, ledger),
                        ),
                      ),

                      DataCell(
                        Text(
                          _formatTransactionQty(
                            transaction.quantityOut,
                            ledger,
                          ),
                        ),
                      ),

                      DataCell(Text(transaction.rate.toStringAsFixed(2))),

                      DataCell(
                        Text(
                          _formatTransactionQty(transaction.balanceQty, ledger),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            transaction.remarks ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE TRANSACTION
  // ============================================================

  Widget _buildMobileTransaction(
    InventoryStockLedgerTransaction transaction,
    InventoryStockLedger ledger,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  transaction.date,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _sourceChip(transaction.sourceType),
                const Spacer(),
                Text(
                  _formatTransactionQty(transaction.balanceQty, ledger),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (transaction.referenceNo != null)
              Text('Reference: ${transaction.referenceNo}'),

            if (transaction.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(transaction.description!),
              ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _mobileTransactionValue(
                    'In',
                    _formatTransactionQty(transaction.quantityIn, ledger),
                  ),
                ),
                Expanded(
                  child: _mobileTransactionValue(
                    'Out',
                    _formatTransactionQty(transaction.quantityOut, ledger),
                  ),
                ),
                Expanded(
                  child: _mobileTransactionValue(
                    'Rate',
                    transaction.rate.toStringAsFixed(2),
                  ),
                ),
              ],
            ),

            if (transaction.remarks?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Remarks: ${transaction.remarks}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileTransactionValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ============================================================
  // SOURCE CHIP
  // ============================================================

  Widget _sourceChip(String sourceType) {
    final color = _sourceColor(sourceType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_sourceIcon(sourceType), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            sourceType,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 50),
              const SizedBox(height: 12),
              Text(
                'Select a raw material and date range',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _formatQty(double quantity, InventoryStockLedger ledger) {
    return quantity.toStringAsFixed(ledger.rawMaterial.decimalPlaces);
  }

  String _formatTransactionQty(double quantity, InventoryStockLedger ledger) {
    return quantity.toStringAsFixed(ledger.rawMaterial.decimalPlaces);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
