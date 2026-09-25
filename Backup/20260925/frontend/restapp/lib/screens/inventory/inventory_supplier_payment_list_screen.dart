import 'package:flutter/material.dart';

import '../../models/inventory/inventory_supplier.dart';
import '../../models/inventory/inventory_supplier_payment.dart';
import '../../services/inventory/inventory_supplier_payment_service.dart';
import 'inventory_supplier_payment_screen.dart';

class InventorySupplierPaymentListScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventorySupplierPaymentListScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventorySupplierPaymentListScreen> createState() =>
      _InventorySupplierPaymentListScreenState();
}

class _InventorySupplierPaymentListScreenState
    extends State<InventorySupplierPaymentListScreen> {
  late final InventorySupplierPaymentService _service;

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  List<InventorySupplier> _suppliers = [];
  List<InventorySupplierPayment> _payments = [];

  InventorySupplier? _selectedSupplier;

  bool _loading = true;
  bool _loadingPayments = false;

  @override
  void initState() {
    super.initState();

    _service = InventorySupplierPaymentService(
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

      _suppliers = await _service.getSuppliers();

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
        _payments = [];
      });

      await _loadPayments();
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

  Future<void> _loadPayments() async {
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
        _loadingPayments = true;
      });

      final payments = await _service.getSupplierPayments(
        supplierId: _selectedSupplier!.supplierId,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (!mounted) return;

      setState(() {
        _payments = payments;
        _loadingPayments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPayments = false;
      });

      _showMessage('Unable to load payments: $e');
    }
  }

  Future<void> _addPayment() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventorySupplierPaymentScreen(
          outletId: widget.outletId,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result is InventorySupplierPayment) {
      if (_selectedSupplier != null &&
          result.supplierId == _selectedSupplier!.supplierId) {
        await _loadPayments();
      }
    }
  }

  Future<void> _viewPayment(InventorySupplierPayment payment) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supplier Payment'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Payment ID', payment.paymentId.toString()),
                _detailRow('Date', _displayDate(payment.paymentDate)),
                _detailRow('Mode', payment.paymentMode),
                _detailRow('Amount', '₹${payment.amount.toStringAsFixed(2)}'),
                _detailRow(
                  'Reference No.',
                  payment.referenceNo?.isNotEmpty == true
                      ? payment.referenceNo!
                      : '-',
                ),
                _detailRow('Status', payment.status),
                _detailRow(
                  'Remarks',
                  payment.remarks?.isNotEmpty == true ? payment.remarks! : '-',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _voidPayment(InventorySupplierPayment payment) async {
    if (payment.status.toUpperCase() != 'SUCCESS') {
      _showMessage('Only SUCCESS payments can be voided.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Void Payment'),
          content: Text(
            'Void payment #${payment.paymentId} '
            'of ₹${payment.amount.toStringAsFixed(2)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('VOID PAYMENT'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final remarksController = TextEditingController();

    try {
      final remarks = await showDialog<String?>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Void Remarks'),
            content: TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(null);
                },
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(remarksController.text.trim());
                },
                child: const Text('CONFIRM VOID'),
              ),
            ],
          );
        },
      );

      if (remarks == null) {
        return;
      }

      setState(() {
        _loadingPayments = true;
      });

      await _service.voidSupplierPayment(
        supplierId: payment.supplierId,
        paymentId: payment.paymentId,
        remarks: remarks.isEmpty ? null : remarks,
      );

      if (!mounted) return;

      _showMessage('Payment voided successfully.');

      await _loadPayments();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPayments = false;
      });

      _showMessage('Unable to void payment: $e');
    } finally {
      remarksController.dispose();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 750;

                if (wide) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: _buildSupplierField()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField(
                          'From Date',
                          _fromDateController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField('To Date', _toDateController),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _loadingPayments ? null : _loadPayments,
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
                          child: _buildDateField(
                            'From Date',
                            _fromDateController,
                          ),
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
                        onPressed: _loadingPayments ? null : _loadPayments,
                        icon: const Icon(Icons.search),
                        label: const Text('LOAD'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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

  Widget _buildPaymentList() {
    if (_selectedSupplier == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Select a supplier to view payments.')),
        ),
      );
    }

    if (_loadingPayments) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_payments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No payments found for the selected period.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;

            if (!wide) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  return _buildMobilePayment(_payments[index]);
                },
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Payment ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Reference No.')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _payments.map((payment) {
                  return DataRow(
                    cells: [
                      DataCell(Text(payment.paymentId.toString())),
                      DataCell(Text(_displayDate(payment.paymentDate))),
                      DataCell(Text(payment.paymentMode)),
                      DataCell(
                        Text(
                          payment.referenceNo?.isNotEmpty == true
                              ? payment.referenceNo!
                              : '-',
                        ),
                      ),
                      DataCell(Text('₹${payment.amount.toStringAsFixed(2)}')),
                      DataCell(_statusChip(payment.status)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              onPressed: () => _viewPayment(payment),
                              icon: const Icon(Icons.visibility),
                            ),
                            IconButton(
                              tooltip: 'Void',
                              onPressed:
                                  payment.status.toUpperCase() == 'SUCCESS'
                                  ? () => _voidPayment(payment)
                                  : null,
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                          ],
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

  Widget _buildMobilePayment(InventorySupplierPayment payment) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Payment #${payment.paymentId}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _statusChip(payment.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_displayDate(payment.paymentDate)),
            Text(
              '${payment.paymentMode}  •  '
              '₹${payment.amount.toStringAsFixed(2)}',
            ),
            if (payment.referenceNo?.isNotEmpty == true)
              Text('Ref: ${payment.referenceNo}'),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'View',
            onPressed: () => _viewPayment(payment),
            icon: const Icon(Icons.visibility),
          ),
          IconButton(
            tooltip: 'Void',
            onPressed: payment.status.toUpperCase() == 'SUCCESS'
                ? () => _voidPayment(payment)
                : null,
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _addPayment,
          icon: const Icon(Icons.add),
          label: const Text('ADD PAYMENT'),
        ),
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
        appBar: AppBar(title: Text('Supplier Payments')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Payments')),
      body: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTopBar(),

              const SizedBox(height: 12),

              _buildFilters(),

              const SizedBox(height: 12),

              _buildPaymentList(),
            ],
          ),
        ),
      ),
    );
  }
}
