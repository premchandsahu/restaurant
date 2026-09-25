import 'package:flutter/material.dart';

import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_stock_adjustment.dart';
import '../../services/inventory/inventory_raw_material_service.dart';
import '../../services/inventory/inventory_stock_adjustment_service.dart';

class InventoryStockAdjustmentScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryStockAdjustmentScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryStockAdjustmentScreen> createState() =>
      _InventoryStockAdjustmentScreenState();
}

class _InventoryStockAdjustmentScreenState
    extends State<InventoryStockAdjustmentScreen> {
  late final InventoryStockAdjustmentService _adjustmentService;

  late final InventoryRawMaterialService _rawMaterialService;

  final TextEditingController _adjustmentNoController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _reasonController = TextEditingController();

  String _adjustmentType = 'INCREASE';

  List<InventoryRawMaterial> _rawMaterials = [];

  final List<_StockAdjustmentLine> _lines = [];

  bool _loadingMaterials = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _adjustmentService = InventoryStockAdjustmentService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _rawMaterialService = InventoryRawMaterialService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _dateController.text = _formatDate(DateTime.now());

    _loadRawMaterials();
  }

  @override
  void dispose() {
    _adjustmentNoController.dispose();
    _dateController.dispose();
    _reasonController.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // DATE
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

  Future<void> _pickDate() async {
    final existingDate = _parseDate(_dateController.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: existingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _dateController.text = _formatDate(picked);
    }
  }

  // ============================================================
  // RAW MATERIALS
  // ============================================================

  Future<void> _loadRawMaterials() async {
    setState(() {
      _loadingMaterials = true;
    });

    try {
      final result = await _rawMaterialService.getRawMaterials(
        outletId: widget.outletId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rawMaterials = result;
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
  // ADD MATERIAL
  // ============================================================

  Future<void> _addMaterial() async {
    if (_rawMaterials.isEmpty) {
      if (_loadingMaterials) {
        _showMessage('Loading raw materials...');
      } else {
        _showMessage('No raw materials found');
      }
      return;
    }

    final material = await _selectRawMaterial();

    if (material == null) {
      return;
    }

    final alreadyAdded = _lines.any(
      (line) => line.material.rawMaterialId == material.rawMaterialId,
    );

    if (alreadyAdded) {
      _showMessage('Material already added');
      return;
    }

    final line = _StockAdjustmentLine(material: material);

    setState(() {
      _lines.add(line);
    });
  }

  // ============================================================
  // MATERIAL SEARCH DIALOG
  // ============================================================

  Future<InventoryRawMaterial?> _selectRawMaterial() async {
    final searchController = TextEditingController();

    List<InventoryRawMaterial> filtered = List.from(_rawMaterials);

    final result = await showDialog<InventoryRawMaterial>(
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
                        hintText: 'Search code or material name',
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
                                    '${item.materialCode}  •  ${item.unitCode}',
                                  ),
                                  trailing: Text(
                                    item.purchaseRate.toStringAsFixed(2),
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

    return result;
  }

  // ============================================================
  // REMOVE LINE
  // ============================================================

  void _removeLine(int index) {
    final line = _lines[index];

    setState(() {
      _lines.removeAt(index);
    });

    line.dispose();
  }

  // ============================================================
  // TYPE
  // ============================================================

  bool get _isInwardType =>
      _adjustmentType == 'OPENING' || _adjustmentType == 'INCREASE';

  void _changeAdjustmentType(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _adjustmentType = value;
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    final adjustmentDate = _dateController.text.trim();

    final reason = _reasonController.text.trim();

    if (adjustmentDate.isEmpty) {
      _showMessage('Adjustment Date is required');
      return;
    }

    if (_lines.isEmpty) {
      _showMessage('Please add at least one material');
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];

      final qty = double.tryParse(line.qtyController.text.trim()) ?? 0;

      final rate = double.tryParse(line.rateController.text.trim()) ?? 0;

      if (qty <= 0) {
        _showMessage('Please enter valid quantity for row ${i + 1}');
        return;
      }

      if (_isInwardType && rate <= 0) {
        _showMessage('Rate is required for row ${i + 1}');
        return;
      }

      items.add({
        'rawMaterialId': line.material.rawMaterialId,
        'qty': qty,
        'unitId': line.material.unitId,

        // For INCREASE / OPENING the rate is
        // supplied by the user.
        //
        // For DECREASE / WASTAGE / DAMAGE,
        // sending 0 tells the backend to use
        // the current stock average rate.
        'rate': _isInwardType ? rate : 0,
      });
    }

    final payload = {
      'outletId': widget.outletId,
      'adjustmentDate': adjustmentDate,
      'adjustmentType': _adjustmentType,
      'reason': reason.isEmpty ? null : reason,
      'items': items,
    };

    setState(() {
      _saving = true;
    });

    try {
      final InventoryStockAdjustment result = await _adjustmentService
          .createStockAdjustment(payload: payload);

      if (!mounted) {
        return;
      }

      _showMessage(
        'Stock adjustment ${result.adjustmentNo} saved successfully',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildReasonChips() {
    final reasons = [
      'Physical Count',
      'Kitchen Wastage',
      'Damage',
      'Expired',
      'Opening Stock',
      'Other',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reasons.map((reason) {
        return ActionChip(
          label: Text(reason),
          onPressed: () {
            setState(() {
              _reasonController.text = reason;
            });
          },
        );
      }).toList(),
    );
  }
  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Adjustment')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 20 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDesktop),
                const SizedBox(height: 12),

                _buildAdjustmentBanner(),
                const SizedBox(height: 12),

                _buildReasonChips(),

                const SizedBox(height: 16),

                _buildItemsSection(isDesktop),

                const SizedBox(height: 16),

                _buildBottomSection(isDesktop),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdjustmentBanner() {
    Color color;
    IconData icon;
    String text;

    switch (_adjustmentType) {
      case 'OPENING':
        color = Colors.blue;
        icon = Icons.flag;
        text = 'Opening stock will be added.';
        break;

      case 'INCREASE':
        color = Colors.green;
        icon = Icons.arrow_upward;
        text = 'Stock quantity will increase.';
        break;

      case 'DECREASE':
        color = Colors.orange;
        icon = Icons.arrow_downward;
        text = 'Stock quantity will decrease.';
        break;

      case 'WASTAGE':
        color = Colors.red;
        icon = Icons.delete_outline;
        text = 'Kitchen wastage will reduce stock.';
        break;

      default:
        color = Colors.grey;
        icon = Icons.broken_image;
        text = 'Damaged stock will reduce inventory.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(bool isDesktop) {
    final adjustmentNo = SizedBox(
      width: isDesktop ? 220 : double.infinity,
      child: TextFormField(
        controller: _adjustmentNoController,
        readOnly: true,
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Adjustment No',
          border: OutlineInputBorder(),
          hintText: 'Auto Generated',
        ),
      ),
    );

    final date = SizedBox(
      width: isDesktop ? 180 : double.infinity,
      child: TextFormField(
        controller: _dateController,
        readOnly: true,
        onTap: _pickDate,
        decoration: const InputDecoration(
          labelText: 'Adjustment Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month),
        ),
      ),
    );

    final type = SizedBox(
      width: isDesktop ? 220 : double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue: _adjustmentType,
        decoration: const InputDecoration(
          labelText: 'Adjustment Type',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'OPENING', child: Text('Opening')),
          DropdownMenuItem(value: 'INCREASE', child: Text('Increase')),
          DropdownMenuItem(value: 'DECREASE', child: Text('Decrease')),
          DropdownMenuItem(value: 'WASTAGE', child: Text('Wastage')),
          DropdownMenuItem(value: 'DAMAGE', child: Text('Damage')),
        ],
        onChanged: _changeAdjustmentType,
      ),
    );

    if (isDesktop) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              adjustmentNo,
              const SizedBox(width: 12),
              date,
              const SizedBox(width: 12),
              type,
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
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
            adjustmentNo,
            const SizedBox(height: 12),
            date,
            const SizedBox(height: 12),
            type,
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ITEMS
  // ============================================================

  Widget _buildItemsSection(bool isDesktop) {
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
                    'Adjustment Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadingMaterials ? null : _addMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD MATERIAL'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'No materials added',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else if (isDesktop)
              _buildDesktopItems()
            else
              _buildMobileItems(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP ITEMS
  // ============================================================

  Widget _buildDesktopItems() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Material')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Rate')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Action')),
        ],
        rows: List.generate(_lines.length, (index) {
          final line = _lines[index];

          return DataRow(
            cells: [
              DataCell(Text(line.material.materialCode)),
              DataCell(
                SizedBox(width: 220, child: Text(line.material.materialName)),
              ),
              DataCell(
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: line.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),
              ),
              DataCell(Text(line.material.unitCode)),
              DataCell(
                SizedBox(
                  width: 110,
                  child: _isInwardType
                      ? TextFormField(
                          controller: line.rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                        )
                      : const Text('AUTO'),
                ),
              ),
              DataCell(Text(_lineAmount(line))),
              DataCell(
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () {
                    _removeLine(index);
                  },
                  icon: const Icon(Icons.delete),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ============================================================
  // MOBILE ITEMS
  // ============================================================

  Widget _buildMobileItems() {
    return Column(
      children: List.generate(_lines.length, (index) {
        final line = _lines[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.material.materialName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _removeLine(index);
                      },
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),

                Text(
                  '${line.material.materialCode}  •  ${line.material.unitCode}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: line.qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _isInwardType
                          ? TextFormField(
                              controller: line.rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Rate',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                              },
                            )
                          : const InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Rate',
                                border: OutlineInputBorder(),
                              ),
                              child: Text('AUTO'),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Amount: ${_lineAmount(line)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ============================================================
  // LINE AMOUNT
  // ============================================================

  String _lineAmount(_StockAdjustmentLine line) {
    if (!_isInwardType) {
      return 'AUTO';
    }

    final qty = double.tryParse(line.qtyController.text) ?? 0;

    final rate = double.tryParse(line.rateController.text) ?? 0;

    return (qty * rate).toStringAsFixed(2);
  }

  // ============================================================
  // BOTTOM
  // ============================================================

  Widget _buildBottomSection(bool isDesktop) {
    final total = _totalAmount();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      _isInwardType
                          ? 'Total Amount: ${total.toStringAsFixed(2)}'
                          : 'Rate and amount will use current stock average rate',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildSaveButton(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isInwardType
                        ? 'Total Amount: ${total.toStringAsFixed(2)}'
                        : 'Rate and amount will use current stock average rate',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSaveButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_saving ? 'SAVING...' : 'SAVE ADJUSTMENT'),
      ),
    );
  }

  double _totalAmount() {
    if (!_isInwardType) {
      return 0;
    }

    return _lines.fold(0, (sum, line) {
      final qty = double.tryParse(line.qtyController.text) ?? 0;

      final rate = double.tryParse(line.rateController.text) ?? 0;

      return sum + (qty * rate);
    });
  }
}

// ============================================================
// LOCAL LINE MODEL
// ============================================================

class _StockAdjustmentLine {
  final InventoryRawMaterial material;

  final TextEditingController qtyController;

  final TextEditingController rateController;

  _StockAdjustmentLine({required this.material})
    : qtyController = TextEditingController(text: '1'),
      rateController = TextEditingController(
        text: material.purchaseRate.toStringAsFixed(2),
      );

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
  }
}
