import 'package:flutter/material.dart';

import '../../models/inventory/inventory_menu_item.dart';
import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_recipe.dart';
import '../../services/inventory/inventory_recipe_service.dart';

class InventoryRecipeScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryRecipeScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryRecipeScreen> createState() => _InventoryRecipeScreenState();
}

class _InventoryRecipeScreenState extends State<InventoryRecipeScreen> {
  late final InventoryRecipeService _service;

  final _formKey = GlobalKey<FormState>();
  final _recipeNameController = TextEditingController();
  final _yieldQtyController = TextEditingController(text: '1');

  List<InventoryMenuItem> _menuItems = [];
  List<InventoryRawMaterial> _rawMaterials = [];
  List<InventoryUnit> _units = [];
  List<InventoryRecipe> _recipes = [];
  List<RecipeTarget> _targets = [];
  RecipeCoverageSummary? _coverage;

  InventoryMenuItem? _selectedMenuItem;
  int? _selectedVariantId;
  InventoryUnit? _selectedYieldUnit;
  String _effectiveFrom = _today();
  bool _isActive = true;
  int? _editingRecipeId;
  bool _creatingNewVersion = false;
  final List<_RecipeIngredientDraft> _ingredientRows = [];

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String _recipeSearchText = '';
  bool get _isEditing => _editingRecipeId != null;

  @override
  void initState() {
    super.initState();
    _service = InventoryRecipeService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _recipeNameController.dispose();
    _yieldQtyController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<InventoryRawMaterial?> _showRawMaterialSearchDialog() async {
    final searchController = TextEditingController();

    try {
      return await showDialog<InventoryRawMaterial>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final searchText = searchController.text.trim().toLowerCase();

              final filteredMaterials = _rawMaterials.where((material) {
                if (searchText.isEmpty) {
                  return true;
                }

                final materialCode = material.materialCode.toLowerCase();

                final materialName = material.materialName.toLowerCase();

                return materialCode.contains(searchText) ||
                    materialName.contains(searchText);
              }).toList();

              return AlertDialog(
                title: const Text('Select Raw Material'),

                content: SizedBox(
                  width: 550,
                  height: 500,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search raw material...',
                          prefixIcon: const Icon(Icons.search),

                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {});
                                  },
                                ),

                          border: const OutlineInputBorder(),
                        ),

                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: filteredMaterials.isEmpty
                            ? const Center(child: Text('No raw material found'))
                            : ListView.separated(
                                itemCount: filteredMaterials.length,

                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),

                                itemBuilder: (context, index) {
                                  final material = filteredMaterials[index];

                                  return ListTile(
                                    dense: true,

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
      searchController.dispose();
    }
  }

  Future<InventoryMenuItem?> _showMenuItemSearchDialog() async {
    final searchController = TextEditingController();

    try {
      return await showDialog<InventoryMenuItem>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final searchText = searchController.text.trim().toLowerCase();

              final filteredItems = _menuItems.where((item) {
                if (searchText.isEmpty) {
                  return true;
                }

                final itemCode = item.itemCode.toLowerCase();

                final itemName = item.itemName.toLowerCase();

                return itemCode.contains(searchText) ||
                    itemName.contains(searchText);
              }).toList();

              return AlertDialog(
                title: const Text('Select Menu Item'),

                content: SizedBox(
                  width: 500,
                  height: 500,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,

                        autofocus: true,

                        decoration: InputDecoration(
                          hintText: 'Search item...',
                          prefixIcon: const Icon(Icons.search),

                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();

                                    setDialogState(() {});
                                  },
                                ),

                          border: const OutlineInputBorder(),
                        ),

                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: filteredItems.isEmpty
                            ? const Center(child: Text('No menu item found'))
                            : ListView.separated(
                                itemCount: filteredItems.length,

                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),

                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];

                                  return ListTile(
                                    dense: true,

                                    title: Text(item.itemName),

                                    subtitle: Text(item.itemCode),

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
      searchController.dispose();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getUnits(),
        _service.getRawMaterials(outletId: widget.outletId),
        _service.getMenuItems(outletId: widget.outletId),
        _service.getRecipes(outletId: widget.outletId),
        _service.getCoverage(outletId: widget.outletId, asOfDate: _today()),
      ]);

      if (!mounted) return;

      final units = results[0] as List<InventoryUnit>;

      final uniqueUnits = <int, InventoryUnit>{};

      for (final unit in units) {
        uniqueUnits[unit.unitId] = unit;
      }
      setState(() {
        _units = uniqueUnits.values.toList();
        _rawMaterials = results[1] as List<InventoryRawMaterial>;
        _menuItems = results[2] as List<InventoryMenuItem>;
        _recipes = results[3] as List<InventoryRecipe>;
        final coverageResult =
            results[4] as (RecipeCoverageSummary, List<RecipeTarget>);
        _coverage = coverageResult.$1;
        _targets = coverageResult.$2;
        if (_units.isEmpty) {
          _selectedYieldUnit = null;
        } else {
          _selectedYieldUnit = _units.firstWhere(
            (unit) => unit.unitCode.toUpperCase() == 'PCS',
            orElse: () => _units.first,
          );
        }
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

  void _startNewVersion(InventoryRecipe recipe) {
    final menuItem = _menuItems
        .where((item) => item.menuItemId == recipe.menuItemId)
        .firstOrNull;

    if (menuItem == null) {
      _showMessage('Menu item is not available');
      return;
    }

    for (final row in _ingredientRows) {
      row.dispose();
    }

    _ingredientRows.clear();

    final currentDate = _parseDate(recipe.effectiveFrom);

    final newEffectiveDate = currentDate == null
        ? DateTime.now().add(const Duration(days: 1))
        : currentDate.add(const Duration(days: 1));

    setState(() {
      // IMPORTANT:
      // Keep the CURRENT recipe id here.
      // The backend PUT will use it as the parent version
      // and create the next SCD Type 2 version.
      _editingRecipeId = recipe.recipeId;

      _creatingNewVersion = true;

      _selectedMenuItem = menuItem;

      _selectedVariantId = recipe.variantId;

      _recipeNameController.text = recipe.recipeName;

      _yieldQtyController.text = _trimNumber(recipe.yieldQty);

      _selectedYieldUnit = recipe.yieldUnitId == null
          ? null
          : _units.where((u) => u.unitId == recipe.yieldUnitId).firstOrNull;

      _effectiveFrom = _dateOnly(newEffectiveDate);

      _isActive = recipe.isActive;

      for (final item in recipe.items) {
        final row = _RecipeIngredientDraft(
          rawMaterial: _rawMaterials
              .where((rm) => rm.rawMaterialId == item.rawMaterialId)
              .firstOrNull,

          unit: _units.where((u) => u.unitId == item.unitId).firstOrNull,

          qty: item.qty,

          wastagePercent: item.wastagePercent,
        );

        _ingredientRows.add(row);
      }
    });

    _showMessage(
      'New version prepared. Review the effective date and ingredients.',
    );
  }

  void _resetForm() {
    for (final row in _ingredientRows) {
      row.dispose();
    }
    _ingredientRows.clear();

    setState(() {
      _editingRecipeId = null;
      _creatingNewVersion = false;
      _selectedMenuItem = null;
      _selectedVariantId = null;
      _recipeNameController.clear();
      _yieldQtyController.text = '1';
      _effectiveFrom = _today();
      _isActive = true;

      if (_units.isNotEmpty) {
        _selectedYieldUnit = _units.firstWhere(
          (unit) => unit.unitCode.toUpperCase() == 'PCS',
          orElse: () => _units.first,
        );
      } else {
        _selectedYieldUnit = null;
      }
    });
  }

  void _startNewForTarget(RecipeTarget target) {
    final menuItem = _menuItems
        .where((item) => item.menuItemId == target.menuItemId)
        .firstOrNull;

    if (menuItem == null) {
      _showMessage('Menu item is not available');
      return;
    }

    _resetForm();

    setState(() {
      _selectedMenuItem = menuItem;
      _selectedVariantId = target.variantId;
      _recipeNameController.text =
          '${menuItem.itemName}${target.variantName == null ? '' : ' - ${target.variantName}'} Recipe';
    });
  }

  Future<void> _editRecipe(InventoryRecipe recipe) async {
    final menuItem = _menuItems
        .where((item) => item.menuItemId == recipe.menuItemId)
        .firstOrNull;

    if (menuItem == null) {
      _showMessage('Menu item is not available');
      return;
    }

    try {
      setState(() {
        _saving = true;
        _errorMessage = null;
      });

      // The recipe list is a summary list.
      // Load the complete recipe including ingredient rows.
      final fullRecipe = await _service.getRecipe(
        outletId: widget.outletId,
        recipeId: recipe.recipeId,
      );

      if (!mounted) return;

      for (final row in _ingredientRows) {
        row.dispose();
      }

      _ingredientRows.clear();

      InventoryUnit? selectedYieldUnit;

      if (fullRecipe.yieldUnitId != null) {
        selectedYieldUnit = _units
            .where((unit) => unit.unitId == fullRecipe.yieldUnitId)
            .firstOrNull;
      }

      setState(() {
        _editingRecipeId = fullRecipe.recipeId;
        _creatingNewVersion = false;
        _selectedMenuItem = menuItem;

        _selectedVariantId = fullRecipe.variantId;

        _recipeNameController.text = fullRecipe.recipeName;

        _yieldQtyController.text = _trimNumber(fullRecipe.yieldQty);

        _selectedYieldUnit = selectedYieldUnit;

        _effectiveFrom = fullRecipe.effectiveFrom.isNotEmpty
            ? fullRecipe.effectiveFrom
            : _today();

        _isActive = fullRecipe.isActive;

        for (final item in fullRecipe.items) {
          _ingredientRows.add(
            _RecipeIngredientDraft(
              rawMaterial: _rawMaterials
                  .where((rm) => rm.rawMaterialId == item.rawMaterialId)
                  .firstOrNull,

              unit: _units
                  .where((unit) => unit.unitId == item.unitId)
                  .firstOrNull,

              qty: item.qty,

              wastagePercent: item.wastagePercent,
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to load recipe: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveRecipe() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMenuItem == null) {
      _showMessage('Select a menu item');
      return;
    }

    if (_selectedYieldUnit == null) {
      _showMessage('Select a yield unit');
      return;
    }

    if (_ingredientRows.isEmpty) {
      _showMessage('Add at least one ingredient');
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (final row in _ingredientRows) {
      if (row.rawMaterial == null) {
        _showMessage('Select a raw material for every ingredient');
        return;
      }

      if (row.unit == null) {
        _showMessage('Select a unit for every ingredient');
        return;
      }

      final qty = double.tryParse(row.qtyController.text.trim());
      final wastage = double.tryParse(row.wastageController.text.trim()) ?? 0;

      if (qty == null || qty <= 0) {
        _showMessage('Ingredient quantity must be greater than zero');
        return;
      }

      if (wastage < 0 || wastage > 100) {
        _showMessage('Wastage % must be between 0 and 100');
        return;
      }

      items.add({
        'rawMaterialId': row.rawMaterial!.rawMaterialId,
        'qty': qty,
        'unitId': row.unit!.unitId,
        'wastagePercent': wastage,
      });
    }

    final yieldQty = double.tryParse(_yieldQtyController.text.trim());
    if (yieldQty == null || yieldQty <= 0) {
      _showMessage('Yield quantity must be greater than zero');
      return;
    }

    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      'menuItemId': _selectedMenuItem!.menuItemId,
      'variantId': _selectedVariantId,
      'recipeName': _recipeNameController.text.trim(),
      'effectiveFrom': _effectiveFrom,
      'yieldQty': yieldQty,
      'yieldUnitId': _selectedYieldUnit!.unitId,
      'isActive': _isActive,
      'items': items,
    };

    setState(() => _saving = true);

    try {
      if (_editingRecipeId == null) {
        await _service.createRecipe(payload: payload);
      } else {
        await _service.updateRecipe(
          recipeId: _editingRecipeId!,
          payload: payload,
        );
      }

      if (!mounted) return;
      _showMessage(
        _editingRecipeId == null
            ? 'Recipe created successfully'
            : (_creatingNewVersion
                  ? 'New recipe version created successfully'
                  : 'Recipe updated successfully'),
      );
      _resetForm();
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredientRows.add(
        _RecipeIngredientDraft(
          rawMaterial: null,
          unit: _selectedYieldUnit ?? (_units.isNotEmpty ? _units.first : null),
          qty: 0,
          wastagePercent: 0,
        ),
      );
    });
  }

  void _removeIngredient(int index) {
    final row = _ingredientRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _pickEffectiveFrom() async {
    final initial = _parseDate(_effectiveFrom) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _effectiveFrom = _dateOnly(picked);
    });
  }

  Widget _buildHeader() {
    final coverage = _coverage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recipe Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _resetForm,
                  icon: const Icon(Icons.add),
                  label: const Text('NEW RECIPE'),
                ),
              ],
            ),
            if (coverage != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _summaryChip(
                    'Targets',
                    '${coverage.defaultRecipeTargets + coverage.variantRecipeTargets}',
                  ),
                  _summaryChip(
                    'Configured',
                    '${coverage.configuredExactCount}',
                  ),
                  _summaryChip(
                    'Fallback',
                    '${coverage.fallbackToDefaultCount}',
                  ),
                  _summaryChip('Missing', '${coverage.missingCount}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _creatingNewVersion
                    ? 'Create New Recipe Version'
                    : (_isEditing
                          ? 'Edit Current Recipe'
                          : 'Recipe Definition'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final fields = [
                    _buildMenuItemField(),
                    _buildVariantField(),
                    _buildRecipeNameField(),
                    _buildEffectiveDateField(),
                    _buildYieldQtyField(),
                    _buildYieldUnitField(),
                  ];

                  if (!wide) {
                    return Column(
                      children: [
                        ...fields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: field,
                          ),
                        ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: fields
                        .map(
                          (field) => SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: field,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildIngredientHeader(),
              const SizedBox(height: 6),
              if (_ingredientRows.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No ingredients. Click ADD INGREDIENT to start.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...List.generate(
                  _ingredientRows.length,
                  (index) => _buildIngredientRow(index),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD INGREDIENT'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      const Text('Active'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveRecipe,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'SAVING...' : 'SAVE RECIPE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemField() {
    return InkWell(
      onTap: _menuItems.isEmpty
          ? null
          : () async {
              final selected = await _showMenuItemSearchDialog();

              if (selected == null || !mounted) {
                return;
              }

              setState(() {
                _selectedMenuItem = selected;

                // Existing variant selection must be
                // cleared when menu item changes.
                _selectedVariantId = null;

                if (_recipeNameController.text.trim().isEmpty) {
                  _recipeNameController.text = '${selected.itemName} Recipe';
                }
              });
            },

      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Menu Item',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),

        child: Text(
          _selectedMenuItem == null
              ? 'Select menu item'
              : '${_selectedMenuItem!.itemCode} - '
                    '${_selectedMenuItem!.itemName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /* Widget _buildMenuItemField() {
    return DropdownButtonFormField<InventoryMenuItem>(
      value: _selectedMenuItem,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Menu Item',
        border: OutlineInputBorder(),
      ),
      items: _menuItems
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text('${item.itemCode} - ${item.itemName}'),
            ),
          )
          .toList(),
      onChanged: _isEditing
          ? null
          : (value) {
              setState(() {
                _selectedMenuItem = value;
                _selectedVariantId = null;
                if (value != null &&
                    _recipeNameController.text.trim().isEmpty) {
                  _recipeNameController.text = '${value.itemName} Recipe';
                }
              });
            },
      validator: (value) => value == null ? 'Select menu item' : null,
    );
  }
*/
  Widget _buildVariantField() {
    final variants =
        _selectedMenuItem?.variants ?? const <InventoryMenuVariant>[];
    return DropdownButtonFormField<int?>(
      value: _selectedVariantId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Variant',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Default / No Variant'),
        ),
        ...variants.map(
          (variant) => DropdownMenuItem<int?>(
            value: variant.variantId,
            child: Text('${variant.variantCode} - ${variant.variantName}'),
          ),
        ),
      ],
      onChanged: _isEditing
          ? null
          : (value) {
              setState(() {
                _selectedVariantId = value;
              });
            },
    );
  }

  Widget _buildRecipeNameField() {
    return TextFormField(
      controller: _recipeNameController,
      decoration: const InputDecoration(
        labelText: 'Recipe Name',
        border: OutlineInputBorder(),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Enter recipe name' : null,
    );
  }

  Widget _buildEffectiveDateField() {
    return InkWell(
      onTap: _pickEffectiveFrom,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Effective From',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month),
        ),
        child: Text(_effectiveFrom),
      ),
    );
  }

  Widget _buildYieldQtyField() {
    return TextFormField(
      controller: _yieldQtyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Yield Quantity',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final number = double.tryParse(value?.trim() ?? '');
        if (number == null || number <= 0) return 'Enter a valid yield';
        return null;
      },
    );
  }

  Widget _buildYieldUnitField() {
    // ------------------------------------------------------------
    // Remove duplicate units by unitId.
    //
    // This prevents DropdownButton from receiving the same logical
    // unit more than once.
    // ------------------------------------------------------------
    final uniqueUnits = <int, InventoryUnit>{};

    for (final unit in _units) {
      uniqueUnits[unit.unitId] = unit;
    }

    final dropdownUnits = uniqueUnits.values.toList();

    // ------------------------------------------------------------
    // Always use the InventoryUnit instance from dropdownUnits.
    //
    // This is important when the units list has been reloaded after
    // saving a recipe. _selectedYieldUnit may otherwise refer to an
    // older object instance.
    // ------------------------------------------------------------
    InventoryUnit? dropdownSelectedUnit;

    if (_selectedYieldUnit != null) {
      for (final unit in dropdownUnits) {
        if (unit.unitId == _selectedYieldUnit!.unitId) {
          dropdownSelectedUnit = unit;
          break;
        }
      }
    }

    return DropdownButtonFormField<InventoryUnit>(
      value: dropdownSelectedUnit,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Yield Unit',
        border: OutlineInputBorder(),
      ),

      items: dropdownUnits.map((unit) {
        return DropdownMenuItem<InventoryUnit>(
          value: unit,
          child: Text(
            '${unit.unitCode} - ${unit.unitName}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),

      onChanged: (value) {
        setState(() {
          _selectedYieldUnit = value;
        });
      },

      validator: (value) {
        if (value == null) {
          return 'Select yield unit';
        }

        return null;
      },
    );
  }

  Widget _buildIngredientHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'RAW MATERIAL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text('UNIT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'WASTAGE %',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(int index) {
    final row = _ingredientRows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return Column(
              children: [
                _buildRawMaterialDropdown(row),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildQtyField(row)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildUnitDropdown(row)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildWastageField(row)),
                    IconButton(
                      onPressed: () => _removeIngredient(index),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: _buildRawMaterialDropdown(row)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildQtyField(row)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildUnitDropdown(row)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildWastageField(row)),
              IconButton(
                onPressed: () => _removeIngredient(index),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRawMaterialDropdown(_RecipeIngredientDraft row) {
    return InkWell(
      onTap: _rawMaterials.isEmpty
          ? null
          : () async {
              final selected = await _showRawMaterialSearchDialog();

              if (selected == null || !mounted) {
                return;
              }

              setState(() {
                row.rawMaterial = selected;

                // When raw material is selected,
                // automatically use its base unit.
                row.unit = _units
                    .where((unit) => unit.unitId == selected.unitId)
                    .firstOrNull;
              });
            },

      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Raw Material',
          border: OutlineInputBorder(),
          isDense: true,
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

  Widget _buildQtyField(_RecipeIngredientDraft row) {
    return TextFormField(
      controller: row.qtyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Qty',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      validator: (value) {
        final qty = double.tryParse(value?.trim() ?? '');
        if (qty == null || qty <= 0) return 'Required';
        return null;
      },
    );
  }

  Widget _buildUnitDropdown(_RecipeIngredientDraft row) {
    final uniqueUnits = <int, InventoryUnit>{};

    for (final unit in _units) {
      uniqueUnits[unit.unitId] = unit;
    }

    final dropdownUnits = uniqueUnits.values.toList();

    InventoryUnit? selectedUnit;

    if (row.unit != null) {
      selectedUnit = dropdownUnits
          .where((unit) => unit.unitId == row.unit!.unitId)
          .firstOrNull;
    }

    return DropdownButtonFormField<InventoryUnit>(
      value: selectedUnit,
      isExpanded: true,

      decoration: const InputDecoration(
        labelText: 'Unit',
        border: OutlineInputBorder(),
        isDense: true,
      ),

      items: dropdownUnits
          .map(
            (unit) => DropdownMenuItem<InventoryUnit>(
              value: unit,
              child: Text(unit.unitCode),
            ),
          )
          .toList(),

      onChanged: (value) {
        setState(() {
          row.unit = value;
        });
      },
    );
  }

  Widget _buildWastageField(_RecipeIngredientDraft row) {
    return TextFormField(
      controller: row.wastageController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Wastage %',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildCoverageList() {
    final missing = _targets
        .where((target) => target.coverageStatus == 'MISSING')
        .toList();
    final configured = _targets
        .where((target) => target.coverageStatus != 'MISSING')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recipe Coverage',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (missing.isEmpty)
              const Text('All current recipe targets are covered.')
            else
              ...missing.map(
                (target) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: Text(target.displayName),
                  subtitle: Text(
                    target.variantId == null
                        ? 'Default recipe missing'
                        : 'Variant recipe missing',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _startNewForTarget(target),
                    child: const Text('CREATE'),
                  ),
                ),
              ),
            if (configured.isNotEmpty) ...[
              const Divider(),
              Text('Configured: ${configured.length}'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _viewRecipeVersion(InventoryRecipe summaryRecipe) async {
    try {
      final recipe = await _service.getRecipe(
        outletId: widget.outletId,
        recipeId: summaryRecipe.recipeId,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('${recipe.targetName} • Version ${recipe.versionNo}'),
            content: SizedBox(
              width: 750,
              height: 550,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.recipeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text('Version ${recipe.versionNo}')),
                      Chip(label: Text('From ${recipe.effectiveFrom}')),
                      if (recipe.effectiveTo != null)
                        Chip(label: Text('To ${recipe.effectiveTo}'))
                      else
                        const Chip(label: Text('Current')),
                      Chip(
                        label: Text(
                          'Yield ${_trimNumber(recipe.yieldQty)} '
                          '${recipe.yieldUnitCode ?? ''}',
                        ),
                      ),
                      Chip(
                        label: Text(recipe.isActive ? 'Active' : 'Inactive'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Ingredients',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: recipe.items.isEmpty
                        ? const Center(child: Text('No ingredients found.'))
                        : ListView.separated(
                            itemCount: recipe.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = recipe.items[index];

                              final wastageText = item.wastagePercent > 0
                                  ? ' • Wastage '
                                        '${_trimNumber(item.wastagePercent)}%'
                                  : '';

                              return ListTile(
                                dense: true,

                                title: Text(
                                  '${item.materialCode} - '
                                  '${item.materialName}',
                                ),

                                subtitle: Text(
                                  'Qty: '
                                  '${_trimNumber(item.qty)} '
                                  '${item.unitCode}'
                                  '$wastageText',
                                ),
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
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to load recipe version: $e');
    }
  }

  Future<void> _showRecipeHistory(InventoryRecipe recipe) async {
    final historyFuture = _service.getRecipeHistory(
      outletId: widget.outletId,
      menuItemId: recipe.menuItemId,
      variantId: recipe.variantId,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${recipe.targetName} • Recipe History'),
          content: SizedBox(
            width: 700,
            height: 500,
            child: FutureBuilder<List<InventoryRecipe>>(
              future: historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final history = snapshot.data ?? const <InventoryRecipe>[];

                if (history.isEmpty) {
                  return const Center(child: Text('No recipe history found.'));
                }

                return ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final version = history[index];

                    final isCurrent = version.effectiveTo == null;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('v${version.versionNo}'),
                      ),

                      title: Text(version.recipeName),

                      subtitle: Text(
                        'Effective from: '
                        '${version.effectiveFrom}'
                        '${version.effectiveTo == null ? '' : '  •  Until: ${version.effectiveTo}'}'
                        '\n'
                        'Yield: '
                        '${_trimNumber(version.yieldQty)} '
                        '${version.yieldUnitCode ?? ''}'
                        '  •  '
                        '${version.isActive ? 'Active' : 'Inactive'}',
                      ),

                      isThreeLine: true,

                      trailing: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();

                          _viewRecipeVersion(version);
                        },
                        child: const Text('VIEW'),
                      ),
                    );
                  },
                );
              },
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

  Widget _buildExistingRecipes() {
    final searchText = _recipeSearchText.trim().toLowerCase();

    final filteredRecipes = _recipes.where((recipe) {
      if (searchText.isEmpty) {
        return true;
      }

      final targetName = recipe.targetName.toLowerCase();

      final itemCode = recipe.itemCode.toLowerCase();

      final recipeName = recipe.recipeName.toLowerCase();

      final variantName = (recipe.variantName ?? '').toLowerCase();

      return targetName.contains(searchText) ||
          itemCode.contains(searchText) ||
          recipeName.contains(searchText) ||
          variantName.contains(searchText);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Current Recipes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),

                Text(
                  '${filteredRecipes.length} of ${_recipes.length}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search menu item, code or recipe...',
                prefixIcon: const Icon(Icons.search),

                suffixIcon: _recipeSearchText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() {
                            _recipeSearchText = '';
                          });
                        },
                      ),

                border: const OutlineInputBorder(),

                isDense: true,
              ),

              onChanged: (value) {
                setState(() {
                  _recipeSearchText = value;
                });
              },
            ),

            const SizedBox(height: 12),

            if (_recipes.isEmpty)
              const Text('No current recipes configured.')
            else if (filteredRecipes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: Text('No recipe found for the search criteria.'),
                ),
              )
            else
              ...filteredRecipes.map(
                (recipe) => ListTile(
                  contentPadding: EdgeInsets.zero,

                  title: Text(recipe.targetName),

                  subtitle: Text(
                    'v${recipe.versionNo} • '
                    '${recipe.recipeName} • '
                    'Yield '
                    '${_trimNumber(recipe.yieldQty)} '
                    '${recipe.yieldUnitCode ?? ''} • '
                    '${recipe.items.length} ingredient(s)',
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _startNewVersion(recipe),
                        icon: const Icon(Icons.add_box_outlined),
                        tooltip: 'Create new version',
                      ),

                      IconButton(
                        onPressed: () => _showRecipeHistory(recipe),
                        icon: const Icon(Icons.history),
                        tooltip: 'View recipe history',
                      ),

                      IconButton(
                        onPressed: recipe.effectiveTo == null
                            ? () => _editRecipe(recipe)
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit current version',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory • Recipe Management')),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;

            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_errorMessage != null) _errorBanner(),
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildForm(),
                  const SizedBox(height: 12),
                  _buildCoverageList(),
                  const SizedBox(height: 12),
                  _buildExistingRecipes(),
                  const SizedBox(height: 24),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_errorMessage != null) _errorBanner(),
                _buildHeader(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildForm()),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildCoverageList()),
                  ],
                ),
                const SizedBox(height: 12),
                _buildExistingRecipes(),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Unable to load recipe data'),
        subtitle: Text(_errorMessage ?? ''),
        trailing: IconButton(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh),
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

  static String _today() => _dateOnly(DateTime.now());

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String _trimNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toString()
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _RecipeIngredientDraft {
  InventoryRawMaterial? rawMaterial;
  InventoryUnit? unit;
  final TextEditingController qtyController;
  final TextEditingController wastageController;

  _RecipeIngredientDraft({
    required this.rawMaterial,
    required this.unit,
    required double qty,
    required double wastagePercent,
  }) : qtyController = TextEditingController(
         text: qty == 0 ? '' : _formatNumber(qty),
       ),
       wastageController = TextEditingController(
         text: _formatNumber(wastagePercent),
       );

  void dispose() {
    qtyController.dispose();
    wastageController.dispose();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
