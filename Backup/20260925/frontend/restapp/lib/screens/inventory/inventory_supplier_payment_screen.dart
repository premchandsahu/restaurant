import 'package:flutter/material.dart';

import '../../models/inventory/inventory_supplier.dart';
import '../../models/inventory/inventory_supplier_payment.dart';
import '../../services/inventory/inventory_supplier_payment_service.dart';

class InventorySupplierPaymentScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventorySupplierPaymentScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventorySupplierPaymentScreen> createState() =>
      _InventorySupplierPaymentScreenState();
}

class _InventorySupplierPaymentScreenState
    extends State<InventorySupplierPaymentScreen> {
  late final InventorySupplierPaymentService _service;

  final _formKey = GlobalKey<FormState>();

  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceNoController = TextEditingController();
  final _remarksController = TextEditingController();

  List<InventorySupplier> _suppliers = [];

  InventorySupplier? _selectedSupplier;

  String _paymentMode = 'CASH';

  bool _loading = true;
  bool _saving = false;

  static const List<String> _paymentModes = [
    'CASH',
    'CARD',
    'UPI',
    'BANK',
    'WALLET',
    'CREDIT',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();

    _service = InventorySupplierPaymentService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _dateController.text = _formatDate(DateTime.now());

    _load();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _referenceNoController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _load() async {
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
                if (search.isEmpty) return true;

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

      if (supplier == null) return;

      setState(() {
        _selectedSupplier = supplier;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();

    final existingDate = _parseDate(_dateController.text.trim());

    if (existingDate != null) {
      initialDate = existingDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSupplier == null) {
      _showMessage('Please select a supplier.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid payment amount.');
      return;
    }

    try {
      setState(() {
        _saving = true;
      });

      final payment = await _service.createSupplierPayment(
        supplierId: _selectedSupplier!.supplierId,
        payload: {
          'outletId': widget.outletId,
          'amount': amount,
          'paymentMode': _paymentMode,
          'paymentDate': _toApiDate(_dateController.text.trim()),
          'referenceNo': _referenceNoController.text.trim().isEmpty
              ? null
              : _referenceNoController.text.trim(),
          'remarks': _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),

          // Deliberately omitted from UI.
          // Backend supports supplier-level unallocated payments.
          'allocations': [],
        },
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Payment ${payment.paymentId} saved successfully.');

      Navigator.of(context).pop(payment);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Unable to save payment: $e');
    }
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
      return value;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Supplier Payment')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Payment')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSupplierSection(),

                  const SizedBox(height: 16),

                  _buildPaymentDetails(),

                  const SizedBox(height: 16),

                  _buildRemarksSection(),

                  const SizedBox(height: 24),

                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: _saving ? null : _selectSupplier,
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
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSupplier!.supplierName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSupplier!.supplierCode,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),

            if (_selectedSupplier != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Opening Balance: '
                  '₹${_selectedSupplier!.openingBalance.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: _buildDateField()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPaymentModeField()),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildDateField(),
                    const SizedBox(height: 16),
                    _buildPaymentModeField(),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: _buildAmountField()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildReferenceField()),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildAmountField(),
                    const SizedBox(height: 16),
                    _buildReferenceField(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: _saving ? null : _selectDate,
      decoration: const InputDecoration(
        labelText: 'Payment Date',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Payment date is required';
        }

        return null;
      },
    );
  }

  Widget _buildPaymentModeField() {
    return DropdownButtonFormField<String>(
      value: _paymentMode,
      decoration: const InputDecoration(
        labelText: 'Payment Mode',
        border: OutlineInputBorder(),
      ),
      items: _paymentModes.map((mode) {
        return DropdownMenuItem<String>(value: mode, child: Text(mode));
      }).toList(),
      onChanged: _saving
          ? null
          : (value) {
              if (value == null) return;

              setState(() {
                _paymentMode = value;
              });
            },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Payment mode is required';
        }

        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Amount',
        prefixText: '₹ ',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');

        if (amount == null || amount <= 0) {
          return 'Enter a valid amount';
        }

        return null;
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _referenceNoController,
      decoration: const InputDecoration(
        labelText: 'Reference No.',
        border: OutlineInputBorder(),
        hintText: 'Cheque / UTR / Transaction No.',
      ),
    );
  }

  Widget _buildRemarksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _remarksController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('CANCEL'),
        ),

        const SizedBox(width: 12),

        ElevatedButton.icon(
          onPressed: _saving ? null : _savePayment,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'SAVING...' : 'SAVE PAYMENT'),
        ),
      ],
    );
  }
}
