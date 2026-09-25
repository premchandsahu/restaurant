import 'package:flutter/material.dart';

import '../../models/inventory/inventory_supplier.dart';
import '../../models/inventory/inventory_supplier_ledger.dart';
import '../../services/inventory/inventory_supplier_ledger_service.dart';
import '../../services/inventory/inventory_supplier_payment_service.dart';
import 'package:restapp/screens/inventory/inventory_supplier_payment_list_screen.dart';
import 'package:restapp/screens/inventory/inventory_supplier_ledger_screen.dart';

class InventorySupplierLedgerScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventorySupplierLedgerScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventorySupplierLedgerScreen> createState() =>
      _InventorySupplierLedgerScreenState();
}

class _InventorySupplierLedgerScreenState
    extends State<InventorySupplierLedgerScreen> {
  late final InventorySupplierLedgerService _ledgerService;
  late final InventorySupplierPaymentService _paymentService;

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  List<InventorySupplier> _suppliers = [];

  InventorySupplier? _selectedSupplier;

  InventorySupplierLedger? _ledger;

  bool _loading = true;
  bool _loadingLedger = false;

  @override
  void initState() {
    super.initState();

    _ledgerService = InventorySupplierLedgerService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    /*
      Reuse the existing supplier-loading method from the
      supplier payment service.

      No changes are required to the payment service.
    */
    _paymentService = InventorySupplierPaymentService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    final today = DateTime.now();

    final firstDay = DateTime(today.year, today.month, 1);

    _fromDateController.text = _formatDate(firstDay);
    _toDateController.text = _formatDate(today);

    _loadSuppliers();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();

    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      setState(() {
        _loading = true;
      });

      _suppliers = await _paymentService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Unable to load suppliers: $e');
    }
  }

  Future<void> _selectSupplier() async {
    final controller = TextEditingController();

    try {
      final supplier = await showDialog<InventorySupplier>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final search = controller.text.trim().toLowerCase();

              final filtered = _suppliers.where((supplier) {
                if (search.isEmpty) {
                  return true;
                }

                return supplier.supplierCode.toLowerCase().contains(search) ||
                    supplier.supplierName.toLowerCase().contains(search);
              }).toList();

              return AlertDialog(
                title: const Text('Select Supplier'),
                content: SizedBox(
                  width: 500,
                  height: 500,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search supplier...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No supplier found'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final supplier = filtered[index];

                                  return ListTile(
                                    title: Text(supplier.supplierName),
                                    subtitle: Text(supplier.supplierCode),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop(supplier);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (supplier == null) {
        return;
      }

      setState(() {
        _selectedSupplier = supplier;
        _ledger = null;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _selectDate({required TextEditingController controller}) async {
    DateTime initialDate = DateTime.now();

    final existingDate = _parseDate(controller.text.trim());

    if (existingDate != null) {
      initialDate = existingDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      controller.text = _formatDate(picked);
    });
  }

  Future<void> _loadLedger() async {
    if (_selectedSupplier == null) {
      _showMessage('Please select a supplier.');
      return;
    }

    final fromDate = _toApiDate(_fromDateController.text.trim());

    final toDate = _toApiDate(_toDateController.text.trim());

    if (fromDate.isEmpty || toDate.isEmpty) {
      _showMessage('Please enter valid dates.');
      return;
    }

    if (fromDate.compareTo(toDate) > 0) {
      _showMessage('From date cannot be greater than To date.');
      return;
    }

    try {
      setState(() {
        _loadingLedger = true;
      });

      final ledger = await _ledgerService.getSupplierLedger(
        supplierId: _selectedSupplier!.supplierId,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (!mounted) return;

      setState(() {
        _ledger = ledger;
        _loadingLedger = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingLedger = false;
      });

      _showMessage('Unable to load supplier ledger: $e');
    }
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: _buildSupplierField()),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: _buildDateField('From Date', _fromDateController),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: _buildDateField('To Date', _toDateController),
                  ),

                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: _loadingLedger ? null : _loadLedger,
                    icon: const Icon(Icons.search),
                    label: const Text('LOAD'),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildSupplierField(),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildDateField('From Date', _fromDateController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField('To Date', _toDateController),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _loadingLedger ? null : _loadLedger,
                    icon: const Icon(Icons.search),
                    label: const Text('LOAD'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSupplierField() {
    return InkWell(
      onTap: _selectSupplier,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Supplier',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),
        child: _selectedSupplier == null
            ? const Text(
                'Select supplier',
                style: TextStyle(color: Colors.grey),
              )
            : Text(
                '${_selectedSupplier!.supplierCode} - '
                '${_selectedSupplier!.supplierName}',
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () {
        _selectDate(controller: controller);
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
    );
  }

  Widget _buildSummary(InventorySupplierLedger ledger) {
    final summary = ledger.summary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ledger.supplier.supplierName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              '${ledger.supplier.supplierCode}  •  '
              '${ledger.period.fromDate} to '
              '${ledger.period.toDate}',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 900
                    ? 5
                    : constraints.maxWidth >= 600
                    ? 3
                    : 2;

                final width =
                    (constraints.maxWidth - ((count - 1) * 12)) / count;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryBox(
                      'Opening Balance',
                      summary.openingBalance,
                      width,
                    ),
                    _summaryBox('Purchases', summary.totalPurchases, width),
                    _summaryBox('Payments', summary.totalPayments, width),
                    _summaryBox(
                      'Closing Balance',
                      summary.closingBalance,
                      width,
                    ),
                    _summaryBox('Payable', summary.payableBalance, width),
                    if (summary.advanceBalance > 0)
                      _summaryBox('Advance', summary.advanceBalance, width),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(String label, double value, double width) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactions(InventorySupplierLedger ledger) {
    final transactions = ledger.transactions;

    if (transactions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No transactions found for the selected period.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            if (!wide) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  return _buildMobileTransaction(transactions[index]);
                },
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Description')),
                  DataColumn(numeric: true, label: Text('Debit')),
                  DataColumn(numeric: true, label: Text('Credit')),
                  DataColumn(numeric: true, label: Text('Balance')),
                ],
                rows: transactions.map((transaction) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_displayDate(transaction.transactionDate))),
                      DataCell(Text(transaction.transactionType)),
                      DataCell(
                        Text(
                          transaction.referenceNo?.isNotEmpty == true
                              ? transaction.referenceNo!
                              : '-',
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            transaction.description?.isNotEmpty == true
                                ? transaction.description!
                                : '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction.debit > 0
                              ? '₹${transaction.debit.toStringAsFixed(2)}'
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction.credit > 0
                              ? '₹${transaction.credit.toStringAsFixed(2)}'
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          '₹${transaction.runningBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileTransaction(
    InventorySupplierLedgerTransaction transaction,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      title: Row(
        children: [
          Expanded(
            child: Text(
              transaction.transactionType,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '₹${transaction.runningBalance.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_displayDate(transaction.transactionDate)),
            if (transaction.referenceNo?.isNotEmpty == true)
              Text('Ref: ${transaction.referenceNo}'),
            if (transaction.description?.isNotEmpty == true)
              Text(transaction.description!),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Debit: ₹${transaction.debit.toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                Text('Credit: ₹${transaction.credit.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerContent() {
    if (_selectedSupplier == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Select a supplier and load the ledger.')),
        ),
      );
    }

    if (_loadingLedger) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_ledger == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Click LOAD to display the supplier ledger.'),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummary(_ledger!),

        const SizedBox(height: 12),

        _buildTransactions(_ledger!),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$day-$month-$year';
  }

  static String _toApiDate(String value) {
    final date = _parseDate(value);

    if (date == null) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$year-$month-$day';
  }

  static DateTime? _parseDate(String value) {
    final parts = value.split('-');

    if (parts.length != 3) {
      return null;
    }

    try {
      final day = int.parse(parts[0]);

      final month = int.parse(parts[1]);

      final year = int.parse(parts[2]);

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static String _displayDate(String value) {
    if (value.length < 10) {
      return value;
    }

    final date = value.substring(0, 10);

    final parts = date.split('-');

    if (parts.length != 3) {
      return value;
    }

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Supplier Ledger')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Ledger')),
      body: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildFilters(),

              const SizedBox(height: 12),

              _buildLedgerContent(),
            ],
          ),
        ),
      ),
    );
  }
}
