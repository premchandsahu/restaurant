import 'package:flutter/material.dart';

import '../../models/inventory/inventory_raw_material.dart';
import '../../models/pos/pos_tax.dart';
import '../../services/inventory/inventory_raw_material_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class InventoryRawMaterialScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryRawMaterialScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryRawMaterialScreen> createState() =>
      _InventoryRawMaterialScreenState();
}

class _InventoryRawMaterialScreenState
    extends State<InventoryRawMaterialScreen> {
  late final InventoryRawMaterialService _service;

  final _formKey = GlobalKey<FormState>();

  final _materialCodeController = TextEditingController();
  final _materialNameController = TextEditingController();
  final _purchaseRateController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _reorderQtyController = TextEditingController();
  final _materialSearchController = TextEditingController();
  List<InventoryRawMaterial> _materials = [];
  List<InventoryCategoryOption> _categories = [];
  List<InventoryUnit> _units = [];
  List<PosTaxGroup> _taxGroups = [];

  InventoryCategoryOption? _selectedCategory;
  InventoryUnit? _selectedUnit;
  PosTaxGroup? _selectedTaxGroup;

  bool _isActive = true;

  bool _loading = true;
  bool _saving = false;

  int? _editingMaterialId;

  String? _errorMessage;

  bool get _isEditing => _editingMaterialId != null;

  @override
  void initState() {
    super.initState();

    _service = InventoryRawMaterialService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadAll();
  }

  @override
  void dispose() {
    _materialCodeController.dispose();
    _materialNameController.dispose();
    _purchaseRateController.dispose();
    _reorderLevelController.dispose();
    _reorderQtyController.dispose();
    _materialSearchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD MASTER DATA
  // ============================================================

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getRawMaterials(outletId: widget.outletId, activeOnly: false),
        _service.getCategories(),
        _service.getUnits(),
        _service.getTaxGroups(),
      ]);

      _materials = results[0] as List<InventoryRawMaterial>;

      _categories = results[1] as List<InventoryCategoryOption>;

      _units = results[2] as List<InventoryUnit>;

      _taxGroups = results[3] as List<PosTaxGroup>;
    } catch (e) {
      _errorMessage = e.toString();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _materialCodeController.clear();
    _materialNameController.clear();
    _purchaseRateController.clear();
    _reorderLevelController.clear();
    _reorderQtyController.clear();

    setState(() {
      _editingMaterialId = null;
      _selectedCategory = null;
      _selectedUnit = null;
      _selectedTaxGroup = null;
      _isActive = true;
    });
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editMaterial(InventoryRawMaterial material) async {
    try {
      final detail = await _service.getRawMaterial(
        rawMaterialId: material.rawMaterialId,
        outletId: widget.outletId,
      );

      final category = _categories
          .where((c) => c.inventoryCategoryId == detail.inventoryCategoryId)
          .firstOrNull;

      final unit = _units.where((u) => u.unitId == detail.unitId).firstOrNull;

      final taxGroup = _taxGroups
          .where((t) => t.taxGroupId == detail.taxGroupId)
          .firstOrNull;

      _materialCodeController.text = detail.materialCode;

      _materialNameController.text = detail.materialName;

      _purchaseRateController.text = _formatNumber(detail.purchaseRate);

      _reorderLevelController.text = _formatNumber(detail.reorderLevel);

      _reorderQtyController.text = _formatNumber(detail.reorderQty);

      setState(() {
        _editingMaterialId = detail.rawMaterialId;

        _selectedCategory = category;
        _selectedUnit = unit;
        _selectedTaxGroup = taxGroup;

        _isActive = detail.isActive;
      });
    } catch (e) {
      _showMessage('Unable to load raw material: $e');
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUnit == null) {
      _showMessage('Please select a base unit.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = {
        'outletId': widget.outletId,
        'inventoryCategoryId': _selectedCategory?.inventoryCategoryId,
        'materialCode': _materialCodeController.text.trim(),
        'materialName': _materialNameController.text.trim(),
        'unitId': _selectedUnit!.unitId,
        'purchaseRate':
            double.tryParse(_purchaseRateController.text.trim()) ?? 0,
        'reorderLevel':
            double.tryParse(_reorderLevelController.text.trim()) ?? 0,
        'reorderQty': double.tryParse(_reorderQtyController.text.trim()) ?? 0,
        'taxGroupId': _selectedTaxGroup?.taxGroupId,
        'isActive': _isActive,
      };

      if (_isEditing) {
        await _service.updateRawMaterial(
          rawMaterialId: _editingMaterialId!,
          payload: payload,
        );

        _showMessage('Raw material updated successfully.');
      } else {
        await _service.createRawMaterial(payload: payload);

        _showMessage('Raw material created successfully.');
      }

      _clearForm();

      await _loadAll();
    } catch (e) {
      _showMessage('Unable to save raw material: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // CATEGORY DIALOG
  // ============================================================

  Future<InventoryCategoryOption?> _showCategoryDialog() async {
    final controller = TextEditingController();

    try {
      return await showDialog<InventoryCategoryOption>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final search = controller.text.trim().toLowerCase();

              final filtered = _categories.where((item) {
                if (search.isEmpty) {
                  return true;
                }

                return item.categoryCode.toLowerCase().contains(search) ||
                    item.categoryName.toLowerCase().contains(search);
              }).toList();

              return AlertDialog(
                title: const Text('Select Inventory Category'),
                content: SizedBox(
                  width: 450,
                  height: 450,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search category...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No category found'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];

                                  return ListTile(
                                    dense: true,
                                    title: Text(item.categoryName),
                                    subtitle: Text(item.categoryCode),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop(item);
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
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('CANCEL'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // TAX GROUP DIALOG
  // ============================================================

  Future<PosTaxGroup?> _showTaxGroupDialog() async {
    final controller = TextEditingController();

    try {
      return await showDialog<PosTaxGroup>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final search = controller.text.trim().toLowerCase();

              final filtered = _taxGroups.where((tax) {
                if (search.isEmpty) {
                  return true;
                }

                return tax.taxGroupCode.toLowerCase().contains(search) ||
                    tax.taxGroupName.toLowerCase().contains(search);
              }).toList();

              return AlertDialog(
                title: const Text('Select Tax Group'),
                content: SizedBox(
                  width: 450,
                  height: 450,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search tax group...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No tax group found'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final tax = filtered[index];

                                  return ListTile(
                                    dense: true,
                                    title: Text(tax.taxGroupName),
                                    subtitle: Text(
                                      '${tax.taxGroupCode}  |  ${_formatNumber(tax.totalRate)}%',
                                    ),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop(tax);
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
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('CANCEL'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Raw Material Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _loadAll,
      onRetry: _loadAll,
      form: _buildForm(),
      list: _buildList(),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Raw Material' : 'New Raw Material',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 16),

                MasterTextField(
                  controller: _materialCodeController,
                  label: 'Material Code',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Material code is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                MasterTextField(
                  controller: _materialNameController,
                  label: 'Material Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Material name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _buildCategorySelector(),

                const SizedBox(height: 12),

                _buildUnitSelector(),

                const SizedBox(height: 12),

                _buildTaxGroupSelector(),

                const SizedBox(height: 12),

                MasterTextField(
                  controller: _purchaseRateController,
                  label: 'Purchase Rate',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount < 0) {
                      return 'Enter a valid purchase rate';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                MasterTextField(
                  controller: _reorderLevelController,
                  label: 'Reorder Level',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount < 0) {
                      return 'Enter a valid reorder level';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                MasterTextField(
                  controller: _reorderQtyController,
                  label: 'Reorder Quantity',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount < 0) {
                      return 'Enter a valid reorder quantity';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                MasterSaveActions(
                  isSaving: _saving,
                  isEditing: _isEditing,
                  onSave: _save,
                  onClear: _clearForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY SELECTOR
  // ============================================================

  Widget _buildCategorySelector() {
    return MasterLookupField(
      label: 'Inventory Category',
      placeholder: 'Select category',
      value: _selectedCategory == null
          ? null
          : '${_selectedCategory!.categoryCode} - '
                '${_selectedCategory!.categoryName}',
      onTap: () async {
        final category = await _showCategoryDialog();
        if (category != null) {
          setState(() {
            _selectedCategory = category;
          });
        }
      },
    );
  }

  // ============================================================
  // UNIT SELECTOR
  // ============================================================

  Widget _buildUnitSelector() {
    return MasterDropdownField<InventoryUnit>(
      label: 'Base Unit',
      value: _selectedUnit,
      items: _units.map((unit) {
        return DropdownMenuItem<InventoryUnit>(
          value: unit,
          child: Text('${unit.unitCode} - ${unit.unitName}'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedUnit = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a unit';
        }
        return null;
      },
    );
  }

  // ============================================================
  // TAX GROUP SELECTOR
  // ============================================================

  Widget _buildTaxGroupSelector() {
    return MasterLookupField(
      label: 'Tax Group',
      placeholder: 'Select tax group',
      value: _selectedTaxGroup == null
          ? null
          : '${_selectedTaxGroup!.taxGroupCode} - '
                '${_selectedTaxGroup!.taxGroupName} '
                '(${_formatNumber(_selectedTaxGroup!.totalRate)}%)',
      onTap: () async {
        final tax = await _showTaxGroupDialog();
        if (tax != null) {
          setState(() {
            _selectedTaxGroup = tax;
          });
        }
      },
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildList() {
    final searchText = _materialSearchController.text.trim().toLowerCase();

    final filteredMaterials = _materials.where((material) {
      if (searchText.isEmpty) {
        return true;
      }

      final code = material.materialCode.toLowerCase();
      final name = material.materialName.toLowerCase();
      final category = material.categoryName?.toLowerCase() ?? '';

      return code.contains(searchText) ||
          name.contains(searchText) ||
          category.contains(searchText);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(
            title: 'Raw Materials',
            count: filteredMaterials.length,
          ),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _materialSearchController,
            hintText: 'Search material code, name or category...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredMaterials.isEmpty
                ? Center(
                    child: Text(
                      searchText.isEmpty
                          ? 'No raw materials found.'
                          : 'No matching raw material found.',
                    ),
                  )
                : Card(
                    child: Scrollbar(
                      child: ListView.separated(
                        itemCount: filteredMaterials.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final material = filteredMaterials[index];
                          final taxGroup = _taxGroups
                              .where(
                                (tax) => tax.taxGroupId == material.taxGroupId,
                              )
                              .firstOrNull;

                          return ListTile(
                            dense: true,
                            title: Text(material.materialName),
                            subtitle: Text(
                              '${material.materialCode}'
                              '  |  '
                              '${material.unitCode}'
                              '  |  '
                              'Rate: ${_formatNumber(material.purchaseRate)}'
                              '${taxGroup == null ? '' : '  |  GST: ${_formatNumber(taxGroup.totalRate)}%'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editMaterial(material),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

// ============================================================
// ITERABLE HELPER
// ============================================================

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
