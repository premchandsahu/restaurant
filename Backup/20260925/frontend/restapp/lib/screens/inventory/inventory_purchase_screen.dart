import 'package:flutter/material.dart';
import 'package:restapp/models/pos/pos_tax.dart';

import '../../models/inventory/inventory_purchase.dart';
import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_supplier.dart';
import '../../services/inventory/inventory_purchase_service.dart';

class InventoryPurchaseScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;
  final int? purchaseId;

  const InventoryPurchaseScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
    this.purchaseId,
  });

  @override
  State<InventoryPurchaseScreen> createState() =>
      _InventoryPurchaseScreenState();
}

class _InventoryPurchaseScreenState extends State<InventoryPurchaseScreen> {
  late final InventoryPurchaseService _service;

  final _formKey = GlobalKey<FormState>();

  final _purchaseNoController = TextEditingController();
  final _supplierInvoiceController = TextEditingController();
  final _remarksController = TextEditingController();

  List<InventorySupplier> _suppliers = [];
  List<InventoryRawMaterial> _rawMaterials = [];
  List<InventoryUnit> _units = [];
  List<PosTaxGroup> _taxGroups = [];
  InventorySupplier? _selectedSupplier;

  String _purchaseDate = _today();

  final List<_PurchaseItemDraft> _rows = [];

  bool _loading = true;
  bool _saving = false;
  bool _posting = false;

  InventoryPurchase? _purchase;

  bool get _isEdit => widget.purchaseId != null;

  bool get _isDraft {
    return _purchase == null || _purchase!.status.toUpperCase() == 'DRAFT';
  }

  @override
  void initState() {
    super.initState();

    _service = InventoryPurchaseService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _load();
  }

  @override
  void dispose() {
    _purchaseNoController.dispose();
    _supplierInvoiceController.dispose();
    _remarksController.dispose();

    for (final row in _rows) {
      row.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
      });

      final results = await Future.wait([
        _service.getSuppliers(),
        _service.getRawMaterials(outletId: widget.outletId),
        _service.getUnits(),
        _service.getTaxGroups(),
      ]);

      _suppliers = results[0] as List<InventorySupplier>;
      _rawMaterials = results[1] as List<InventoryRawMaterial>;
      _units = results[2] as List<InventoryUnit>;
      _taxGroups = results[3] as List<PosTaxGroup>;

      if (_isEdit) {
        _purchase = await _service.getPurchase(
          outletId: widget.outletId,
          purchaseId: widget.purchaseId!,
        );

        _loadPurchaseIntoForm(_purchase!);
      } else {
        _addRow();
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Unable to load purchase: $e');
    }
  }

  void _loadPurchaseIntoForm(InventoryPurchase purchase) {
    _purchaseNoController.text = purchase.purchaseNo;

    _supplierInvoiceController.text = purchase.supplierInvoiceNo ?? '';

    _remarksController.text = purchase.remarks ?? '';

    _purchaseDate = purchase.purchaseDate.length >= 10
        ? purchase.purchaseDate.substring(0, 10)
        : _today();

    _selectedSupplier = _suppliers
        .where((supplier) => supplier.supplierId == purchase.supplierId)
        .firstOrNull;

    for (final row in _rows) {
      row.dispose();
    }

    _rows.clear();

    for (final item in purchase.items) {
      _rows.add(
        _PurchaseItemDraft(
          rawMaterial: _rawMaterials
              .where((rm) => rm.rawMaterialId == item.rawMaterialId)
              .firstOrNull,
          unit: _units.where((unit) => unit.unitId == item.unitId).firstOrNull,
          qty: item.qty,
          conversionFactor: item.conversionFactor,
          rate: item.rate,
          discountAmount: item.discountAmount,
          taxGroupId: item.taxGroupId,
          batchNo: item.batchNo,
          expiryDate: item.expiryDate,
        ),
      );
    }

    if (_rows.isEmpty) {
      _addRow();
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _PurchaseItemDraft(
          rawMaterial: null,
          unit: null,
          qty: 1,
          conversionFactor: 1,
          rate: 0,
          discountAmount: 0,
          taxGroupId: null,
          batchNo: null,
          expiryDate: null,
        ),
      );
    });
  }

  void _removeRow(int index) {
    final row = _rows.removeAt(index);
    row.dispose();

    if (_rows.isEmpty) {
      _addRow();
    } else {
      setState(() {});
    }
  }

  Future<InventorySupplier?> _selectSupplier() async {
    final controller = TextEditingController();

    try {
      return await showDialog<InventorySupplier>(
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
    } finally {
      controller.dispose();
    }
  }

  Future<InventoryRawMaterial?> _selectRawMaterial() async {
    final controller = TextEditingController();

    try {
      return await showDialog<InventoryRawMaterial>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final search = controller.text.trim().toLowerCase();

              final filtered = _rawMaterials.where((material) {
                if (search.isEmpty) return true;

                return material.materialCode.toLowerCase().contains(search) ||
                    material.materialName.toLowerCase().contains(search);
              }).toList();

              return AlertDialog(
                title: const Text('Select Raw Material'),
                content: SizedBox(
                  width: 550,
                  height: 500,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search raw material...',
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
                            ? const Center(child: Text('No raw material found'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final material = filtered[index];

                                  return ListTile(
                                    title: Text(material.materialName),
                                    subtitle: Text(
                                      '${material.materialCode} • '
                                      '${material.unitCode}',
                                    ),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop(material);
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
    } finally {
      controller.dispose();
    }
  }

  Future<void> _selectDate() async {
    final current = DateTime.tryParse(_purchaseDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _purchaseDate = _formatDate(picked);
    });
  }

  Future<void> _saveDraft() async {
    if (_saving || _posting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSupplier == null) {
      _showMessage('Select a supplier');
      return;
    }

    if (_rows.isEmpty) {
      _showMessage('Add at least one item');
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (final row in _rows) {
      if (row.rawMaterial == null) {
        _showMessage('Select raw material for every row');
        return;
      }

      if (row.unit == null) {
        _showMessage('Select purchase unit for every row');
        return;
      }

      final qty = double.tryParse(row.qty.text.trim());

      final conversion = double.tryParse(row.conversionFactor.text.trim()) ?? 1;

      final rate = double.tryParse(row.rate.text.trim()) ?? 0;

      final discount = double.tryParse(row.discount.text.trim()) ?? 0;

      if (qty == null || qty <= 0) {
        _showMessage('Quantity must be greater than zero');
        return;
      }

      if (conversion <= 0) {
        _showMessage('Conversion factor must be greater than zero');
        return;
      }

      if (rate < 0) {
        _showMessage('Invalid rate');
        return;
      }

      if (discount < 0) {
        _showMessage('Invalid discount');
        return;
      }

      items.add({
        'rawMaterialId': row.rawMaterial!.rawMaterialId,
        'qty': qty,
        'unitId': row.unit!.unitId,
        'conversionFactor': conversion,
        'rate': rate,
        'discountAmount': discount,
        'taxGroupId': row.taxGroupId,
        'batchNo': row.batchNo,
        'expiryDate': row.expiryDate,
      });
    }

    final payload = {
      'outletId': widget.outletId,
      'supplierId': _selectedSupplier!.supplierId,
      'purchaseNo': _purchaseNoController.text.trim(),
      'purchaseDate': _purchaseDate,
      'supplierInvoiceNo': _supplierInvoiceController.text.trim(),
      'remarks': _remarksController.text.trim(),
      'items': items,
    };

    setState(() {
      _saving = true;
    });

    try {
      late final InventoryPurchase result;

      if (_purchase == null) {
        result = await _service.createPurchase(payload: payload);
      } else {
        result = await _service.updatePurchase(
          purchaseId: _purchase!.purchaseId,
          payload: payload,
        );
      }

      if (!mounted) return;

      setState(() {
        _purchase = result;
        _purchaseNoController.text = result.purchaseNo;
        _saving = false;
      });

      _showMessage(
        result.purchaseId == widget.purchaseId
            ? 'Purchase draft updated'
            : 'Purchase draft saved',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Unable to save purchase: $e');
    }
  }

  Future<void> _postPurchase() async {
    if (_purchase == null) {
      _showMessage('Save the purchase draft first');
      return;
    }

    if (_purchase!.status.toUpperCase() != 'DRAFT') {
      _showMessage('Only DRAFT purchase can be posted');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Post Purchase'),
          content: const Text(
            'Posting this purchase will increase '
            'stock and create the purchase ledger '
            'transaction. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('POST'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _posting = true;
    });

    try {
      final result = await _service.postPurchase(
        purchaseId: _purchase!.purchaseId,
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _purchase = result;
        _posting = false;
      });

      _showMessage('Purchase posted successfully');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _posting = false;
      });

      _showMessage('Unable to post purchase: $e');
    }
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final children = [
              Expanded(
                child: TextFormField(
                  controller: _purchaseNoController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Purchase No',
                    border: OutlineInputBorder(),
                    helperText: 'Auto-generated',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _isDraft ? _selectDate : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Purchase Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                    child: Text(_purchaseDate),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _isDraft
                      ? () async {
                          final supplier = await _selectSupplier();

                          if (supplier == null) {
                            return;
                          }

                          setState(() {
                            _selectedSupplier = supplier;
                          });
                        }
                      : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    child: Text(
                      _selectedSupplier == null
                          ? 'Select supplier'
                          : '${_selectedSupplier!.supplierCode} - '
                                '${_selectedSupplier!.supplierName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 8),
                  children[2],
                  const SizedBox(height: 8),
                  children[4],
                ],
              );
            }

            return Row(children: children);
          },
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Purchase Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isDraft ? _addRow : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int index = 0; index < _rows.length; index++)
              _buildItemRow(index, _rows[index]),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, _PurchaseItemDraft row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1050;

            if (!wide) {
              return Column(
                children: [
                  _rawMaterialField(row),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _numberField(row.qty, 'Qty')),
                      const SizedBox(width: 8),
                      Expanded(child: _unitField(row)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(row.conversionFactor, 'Conversion'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(row.rate, 'Rate')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _numberField(row.discount, 'Discount')),
                      const SizedBox(width: 8),
                      Expanded(child: _taxGroupField(row)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(row.batchNoController, 'Batch No'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _textField(row.expiryController, 'Expiry Date'),
                      ),
                      IconButton(
                        onPressed: _isDraft ? () => _removeRow(index) : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 4, child: _rawMaterialField(row)),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _numberField(row.qty, 'Qty')),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _unitField(row)),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _numberField(row.conversionFactor, 'Conv'),
                ),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _numberField(row.rate, 'Rate')),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _numberField(row.discount, 'Discount'),
                ),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _taxGroupField(row)),
                IconButton(
                  onPressed: _isDraft ? () => _removeRow(index) : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rawMaterialField(_PurchaseItemDraft row) {
    return InkWell(
      onTap: _isDraft
          ? () async {
              final material = await _selectRawMaterial();

              if (material == null) return;

              setState(() {
                row.rawMaterial = material;

                row.unit ??= _units
                    .where((u) => u.unitId == material.unitId)
                    .firstOrNull;

                row.taxGroupId = material.taxGroupId;
              });
            }
          : null,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Raw Material',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(
          row.rawMaterial == null
              ? 'Select raw material'
              : '${row.rawMaterial!.materialCode} - '
                    '${row.rawMaterial!.materialName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _unitField(_PurchaseItemDraft row) {
    final selected = row.unit == null
        ? null
        : _units.where((unit) => unit.unitId == row.unit!.unitId).firstOrNull;

    return DropdownButtonFormField<InventoryUnit>(
      value: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unit',
        border: OutlineInputBorder(),
      ),
      items: _units.map((unit) {
        return DropdownMenuItem(value: unit, child: Text(unit.unitCode));
      }).toList(),
      onChanged: _isDraft
          ? (value) {
              setState(() {
                row.unit = value;
              });
            }
          : null,
    );
  }

  Widget _taxGroupField(_PurchaseItemDraft row) {
    final selectedTaxGroupId = row.taxGroupId ?? 0;

    return DropdownButtonFormField<int>(
      value: selectedTaxGroupId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tax Group',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(value: 0, child: Text('No GST')),
        ..._taxGroups.map(
          (taxGroup) => DropdownMenuItem<int>(
            value: taxGroup.taxGroupId,
            child: Text(
              '${taxGroup.taxGroupCode} - ${taxGroup.taxGroupName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _isDraft
          ? (value) {
              setState(() {
                row.taxGroupId = value == null || value == 0 ? null : value;
              });
            }
          : null,
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      enabled: _isDraft,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      enabled: _isDraft,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFooter() {
    final purchase = _purchase;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: _supplierInvoiceController,
              enabled: _isDraft,
              decoration: const InputDecoration(
                labelText: 'Supplier Invoice No',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              enabled: _isDraft,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (purchase != null)
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _amountText('Subtotal', purchase.subtotal),
                    _amountText('Discount', purchase.discountAmount),
                    _amountText('Tax', purchase.taxAmount),
                    const Divider(),
                    _amountText('Grand Total', purchase.grandTotal, bold: true),
                    _amountText('Paid', purchase.paidAmount),
                    _amountText('Balance', purchase.balanceAmount, bold: true),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDraft)
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveDraft,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('SAVE DRAFT'),
                  ),
                const SizedBox(width: 8),
                if (_purchase != null &&
                    _purchase!.status.toUpperCase() == 'DRAFT')
                  ElevatedButton.icon(
                    onPressed: _posting ? null : _postPurchase,
                    icon: _posting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: const Text('POST PURCHASE'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountText(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 120,
            child: Text(
              '₹${value.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _purchase == null
              ? 'Inventory • New Purchase'
              : 'Inventory • Purchase ${_purchase!.purchaseNo}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildItemsCard(),
              const SizedBox(height: 12),
              _buildFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _today() {
    return _formatDate(DateTime.now());
  }

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _PurchaseItemDraft {
  InventoryRawMaterial? rawMaterial;
  InventoryUnit? unit;

  final TextEditingController qty;
  final TextEditingController conversionFactor;
  final TextEditingController rate;
  final TextEditingController discount;

  final TextEditingController batchNoController;
  final TextEditingController expiryController;

  int? taxGroupId;

  _PurchaseItemDraft({
    required this.rawMaterial,
    required this.unit,
    required double qty,
    required double conversionFactor,
    required double rate,
    required double discountAmount,
    required this.taxGroupId,
    required String? batchNo,
    required String? expiryDate,
  }) : qty = TextEditingController(text: _number(qty)),
       conversionFactor = TextEditingController(
         text: _number(conversionFactor),
       ),
       rate = TextEditingController(text: _number(rate)),
       discount = TextEditingController(text: _number(discountAmount)),
       batchNoController = TextEditingController(text: batchNo ?? ''),
       expiryController = TextEditingController(text: expiryDate ?? '');

  void dispose() {
    qty.dispose();
    conversionFactor.dispose();
    rate.dispose();
    discount.dispose();
    batchNoController.dispose();
    expiryController.dispose();
  }

  String? get batchNo {
    final value = batchNoController.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get expiryDate {
    final value = expiryController.text.trim();
    return value.isEmpty ? null : value;
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toString()
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
