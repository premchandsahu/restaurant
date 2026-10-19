import 'package:flutter/material.dart';

import '../../models/pos/pos_category.dart';
import '../../models/pos/pos_menu_item.dart';
import '../../models/pos/pos_tax.dart';
import '../../models/pos/pos_tax_service.dart';
import '../../services/pos/pos_menu_service.dart';
import '../../widgets/common/master_entry_widgets.dart';
import '../../models/pos/pos_variant.dart';
import 'menu_item_modifier_section.dart';

class MenuItemMasterScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const MenuItemMasterScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<MenuItemMasterScreen> createState() => _MenuItemMasterScreenState();
}

class _MenuItemMasterScreenState extends State<MenuItemMasterScreen> {
  late final PosMenuService _menuService;
  late final PosTaxService _taxService;

  final _formKey = GlobalKey<FormState>();
  final _itemCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _baseRateController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _preparationTimeController = TextEditingController(text: '0');
  final _searchController = TextEditingController();
  // Variant form
  final _variantCodeController = TextEditingController();
  final _variantNameController = TextEditingController();
  final _variantRateController = TextEditingController();
  final _variantDisplayOrderController = TextEditingController(text: '0');

  List<PosVariant> _variants = [];

  int? _editingVariantId;
  int? _variantTaxGroupId;

  bool _variantIsDefault = false;
  bool _loadingVariants = false;
  bool _savingVariant = false;
  bool _variantIsActive = true;
  String? _variantError;
  List<PosMenuItem> _items = [];
  List<PosCategory> _categories = [];
  List<PosTaxGroup> _taxGroups = [];

  PosCategory? _selectedCategory;
  int? _selectedTaxGroupId;
  String _itemType = 'FOOD';

  bool _isVeg = false;
  bool _isEgg = false;
  bool _isSpicy = false;
  bool _allowDiscount = true;
  bool _isAvailable = true;
  bool _isActive = true;

  int? _editingItemId;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => _editingItemId != null;

  @override
  void initState() {
    super.initState();
    _menuService = PosMenuService(baseUrl: widget.baseUrl, token: widget.token);
    _taxService = PosTaxService(baseUrl: widget.baseUrl, token: widget.token);
    _loadAll();
  }

  @override
  void dispose() {
    _itemCodeController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _baseRateController.dispose();
    _imageUrlController.dispose();
    _barcodeController.dispose();
    _preparationTimeController.dispose();
    _searchController.dispose();
    _variantCodeController.dispose();
    _variantNameController.dispose();
    _variantRateController.dispose();
    _variantDisplayOrderController.dispose();
    super.dispose();
  }

  Future<T> _loadWithTimeout<T>(String label, Future<T> request) async {
    debugPrint('Menu Item Master: loading $label...');

    try {
      final result = await request.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timed out while loading $label after 30 seconds.');
        },
      );

      debugPrint('Menu Item Master: $label loaded.');
      return result;
    } catch (e) {
      debugPrint('Menu Item Master: $label failed: $e');
      rethrow;
    }
  }

  Future<void> _refreshAll() async {
    // Clear the main menu item form.
    _clearForm();

    // Clear the variant form and variant list.
    _clearVariantForm();

    if (mounted) {
      setState(() {
        _variants = [];
        _variantError = null;
      });
    }

    // Reload the latest data.
    await _loadAll();
  }

  Future<void> _loadAll() async {
    // Preserve the selected category ID before refreshing the data.
    final int? selectedCategoryId = _selectedCategory?.categoryId;

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _menuService.getAllMenuItems(outletId: widget.outletId),
        _menuService.getCategories(outletId: widget.outletId),
        _taxService.getTaxGroups(),
      ]);

      if (!mounted) return;

      final loadedItems = results[0] as List<PosMenuItem>;
      final loadedCategories = results[1] as List<PosCategory>;
      final loadedTaxGroups = results[2] as List<PosTaxGroup>;

      // Find the selected category in the refreshed list.
      // Use the new object, rather than the stale object.
      PosCategory? refreshedSelectedCategory;

      if (selectedCategoryId != null) {
        for (final category in loadedCategories) {
          if (category.categoryId == selectedCategoryId) {
            refreshedSelectedCategory = category;
            break;
          }
        }
      }

      setState(() {
        _items = loadedItems;
        _categories = loadedCategories;
        _taxGroups = loadedTaxGroups;

        // Rebind the dropdown value to an object in the current list.
        _selectedCategory = refreshedSelectedCategory;

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

  /*
  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _menuService.getAllMenuItems(outletId: widget.outletId),
        _menuService.getCategories(outletId: widget.outletId),
        _taxService.getTaxGroups(),
      ]);

      if (!mounted) return;
      setState(() {
        _items = results[0] as List<PosMenuItem>;
        _categories = results[1] as List<PosCategory>;
        _taxGroups = results[2] as List<PosTaxGroup>;
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
*/
  void _clearForm() {
    _formKey.currentState?.reset();
    _itemCodeController.clear();
    _itemNameController.clear();
    _descriptionController.clear();
    _baseRateController.clear();
    _imageUrlController.clear();
    _barcodeController.clear();
    _preparationTimeController.text = '0';

    setState(() {
      _editingItemId = null;
      _selectedCategory = null;
      _selectedTaxGroupId = null;
      _itemType = 'FOOD';
      _isVeg = false;
      _isEgg = false;
      _isSpicy = false;
      _allowDiscount = true;
      _isAvailable = true;
      _isActive = true;
    });
  }

  void _resetVariantFormFields() {
    _variantCodeController.clear();
    _variantNameController.clear();
    _variantRateController.clear();
    _variantDisplayOrderController.text = '0';

    _editingVariantId = null;
    _variantTaxGroupId = null;
    _variantIsDefault = false;
    _variantIsActive = true;
  }

  void _clearVariantForm() {
    _resetVariantFormFields();

    if (mounted) {
      setState(() {});
    }
  }

  void _editVariant(PosVariant variant) {
    _variantCodeController.text = variant.variantCode;
    _variantNameController.text = variant.variantName;
    _variantRateController.text = variant.rate.toStringAsFixed(2);
    _variantDisplayOrderController.text = variant.displayOrder.toString();

    setState(() {
      _editingVariantId = variant.variantId;
      _variantTaxGroupId = variant.taxGroupId;
      _variantIsDefault = variant.isDefault;
      _variantIsActive = variant.isActive;
    });
  }

  Future<void> _saveVariant() async {
    final menuItemId = _editingItemId;

    if (menuItemId == null) {
      _showMessage('Save the menu item first.');
      return;
    }

    final code = _variantCodeController.text.trim();
    final name = _variantNameController.text.trim();
    final rate = double.tryParse(_variantRateController.text.trim());
    final displayOrder = int.tryParse(
      _variantDisplayOrderController.text.trim(),
    );

    if (code.isEmpty || name.isEmpty) {
      _showMessage('Variant code and name are required.');
      return;
    }

    if (rate == null || !rate.isFinite || rate < 0) {
      _showMessage('Enter a valid variant rate.');
      return;
    }

    if (displayOrder == null || displayOrder < 0) {
      _showMessage('Enter a valid display order.');
      return;
    }

    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      'variantCode': code,
      'variantName': name,
      'rate': rate,
      'taxGroupId': _variantTaxGroupId,
      'displayOrder': displayOrder,
      'isDefault': _variantIsActive && _variantIsDefault,
      'isActive': _variantIsActive,
    };

    setState(() => _savingVariant = true);

    try {
      if (_editingVariantId != null) {
        await _menuService.updateMenuItemVariant(
          menuItemId: menuItemId,
          variantId: _editingVariantId!,
          payload: payload,
        );

        _showMessage('Variant updated successfully.');
      } else {
        await _menuService.createMenuItemVariant(
          menuItemId: menuItemId,
          payload: payload,
        );

        _showMessage('Variant created successfully.');
      }

      if (!mounted) return;

      _clearVariantForm();
      await _loadVariantsForItem(menuItemId);
    } catch (e) {
      _showMessage('Unable to save variant: $e');
    } finally {
      if (mounted) {
        setState(() => _savingVariant = false);
      }
    }
  }

  Future<void> _deactivateVariant(PosVariant variant) async {
    final menuItemId = _editingItemId;

    if (menuItemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Variant'),
          content: Text('Deactivate "${variant.variantName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DEACTIVATE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _savingVariant = true);

    try {
      await _menuService.updateMenuItemVariant(
        menuItemId: menuItemId,
        variantId: variant.variantId,
        payload: {
          'outletId': widget.outletId,
          'variantCode': variant.variantCode,
          'variantName': variant.variantName,
          'rate': variant.rate,
          'taxGroupId': variant.taxGroupId,
          'displayOrder': variant.displayOrder,
          'isDefault': false,
          'isActive': false,
        },
      );

      if (!mounted) return;

      if (_editingVariantId == variant.variantId) {
        _clearVariantForm();
      }

      await _loadVariantsForItem(menuItemId);

      _showMessage('Variant deactivated.');
    } catch (e) {
      _showMessage('Unable to deactivate variant: $e');
    } finally {
      if (mounted) {
        setState(() => _savingVariant = false);
      }
    }
  }

  Future<void> _editItem(PosMenuItem item) async {
    _itemCodeController.text = item.itemCode;
    _itemNameController.text = item.itemName;
    _descriptionController.text = item.description ?? '';
    _baseRateController.text = item.baseRate.toStringAsFixed(2);
    _imageUrlController.text = item.imageUrl ?? '';
    _barcodeController.text = item.barcode ?? '';
    _preparationTimeController.text = item.preparationTimeMinutes.toString();

    setState(() {
      _editingItemId = item.menuItemId;
      _selectedCategory = _findCategory(item.categoryId);
      _selectedTaxGroupId = item.taxGroupId;
      _itemType = item.itemType;

      _isVeg = item.isVeg;
      _isEgg = item.isEgg;
      _isSpicy = item.isSpicy;
      _allowDiscount = item.allowDiscount;
      _isAvailable = item.isAvailable;
      _isActive = item.isActive;

      _variants = [];
      _editingVariantId = null;
      _variantError = null;
    });

    _resetVariantFormFields();

    await _loadVariantsForItem(item.menuItemId);
  }

  Future<void> _loadVariantsForItem(int menuItemId) async {
    setState(() {
      _loadingVariants = true;
      _variantError = null;
    });

    try {
      final details = await _menuService.getMenuItem(
        menuItemId: menuItemId,
        outletId: widget.outletId,
        includeInactiveVariants: true,
      );

      if (!mounted || _editingItemId != menuItemId) return;

      setState(() {
        _variants = details.variants;
      });
    } catch (e) {
      if (!mounted || _editingItemId != menuItemId) return;

      setState(() {
        _variantError = e.toString();
      });
    } finally {
      if (mounted && _editingItemId == menuItemId) {
        setState(() {
          _loadingVariants = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      _showMessage('Please select a menu category.');
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      'menuCategoryId': _selectedCategory!.categoryId,
      'itemCode': _itemCodeController.text.trim(),
      'itemName': _itemNameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'itemType': _itemType,
      'baseRate': double.parse(_baseRateController.text.trim()),
      'taxGroupId': _selectedTaxGroupId,
      'isVeg': _isVeg,
      'isEgg': _isEgg,
      'isSpicy': _isSpicy,
      'imageUrl': _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      'preparationTimeMinutes':
          int.tryParse(_preparationTimeController.text.trim()) ?? 0,
      'allowDiscount': _allowDiscount,
      'isAvailable': _isAvailable,
      'isActive': _isActive,
    };

    try {
      if (_isEditing) {
        await _menuService.updateMenuItem(
          menuItemId: _editingItemId!,
          payload: payload,
        );
        _showMessage('Menu item updated successfully.');
      } else {
        await _menuService.createMenuItem(payload: payload);
        _showMessage('Menu item created successfully.');
      }

      if (!mounted) return;
      _clearForm();
      await _loadAll();
    } catch (e) {
      _showMessage('Unable to save menu item: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Menu Item Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAll,
      onRetry: _refreshAll,
      form: _buildForm(),
      list: _buildList(),
      formWidth: 440,
      compactFormHeight: 560,
    );
  }

  Widget _buildVariantsSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Variants', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            const Text('Maintain different sizes or rates for this menu item.'),
            const SizedBox(height: 12),

            MasterTextField(
              controller: _variantCodeController,
              label: 'Variant Code',
            ),
            const SizedBox(height: 10),

            MasterTextField(
              controller: _variantNameController,
              label: 'Variant Name',
            ),
            const SizedBox(height: 10),

            MasterTextField(
              controller: _variantRateController,
              label: 'Variant Rate',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<int?>(
              value: _variantTaxGroupId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tax Group (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Use item/default tax'),
                ),
                ..._taxGroups.map(
                  (group) => DropdownMenuItem<int?>(
                    value: group.taxGroupId,
                    child: Text(
                      '${group.taxGroupCode} - '
                      '${group.taxGroupName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _variantTaxGroupId = value);
              },
            ),
            const SizedBox(height: 10),

            MasterTextField(
              controller: _variantDisplayOrderController,
              label: 'Display Order',
              keyboardType: TextInputType.number,
            ),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Variant'),
              value: _variantIsDefault,
              onChanged: (value) {
                setState(() => _variantIsDefault = value ?? false);
              },
            ),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Active'),
              subtitle: const Text(
                'Inactive variants will not be available for new orders.',
              ),
              value: _variantIsActive,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _variantIsActive = value;

                  // An inactive variant cannot be the default.
                  if (!value) {
                    _variantIsDefault = false;
                  }
                });
              },
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _savingVariant ? null : _saveVariant,
                  icon: const Icon(Icons.save),
                  label: Text(
                    _editingVariantId == null
                        ? 'ADD VARIANT'
                        : 'UPDATE VARIANT',
                  ),
                ),
                OutlinedButton(
                  onPressed: _savingVariant ? null : _clearVariantForm,
                  child: const Text('CLEAR'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Existing Variants',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_loadingVariants)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),

            if (_variantError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _variantError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            if (!_loadingVariants && _variants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No active variants for this item.'),
              ),

            ..._variants.map(
              (variant) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  variant.variantName,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${variant.variantCode}  |  '
                  '₹${variant.rate.toStringAsFixed(2)}'
                  '${variant.isDefault ? '  |  DEFAULT' : ''}',
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Edit variant',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editVariant(variant),
                    ),
                    IconButton(
                      tooltip: 'Deactivate variant',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deactivateVariant(variant),
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
                  _isEditing ? 'Edit Menu Item' : 'New Menu Item',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                MasterTextField(
                  controller: _itemCodeController,
                  label: 'Item Code',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Item code is required'
                      : null,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _itemNameController,
                  label: 'Item Name',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Item name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                MasterDropdownField<PosCategory>(
                  label: 'Menu Category',
                  value: _selectedCategory,
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem<PosCategory>(
                          value: category,
                          child: Text(
                            '${category.categoryCode} - ${category.categoryName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? 'Select a category' : null,
                ),
                const SizedBox(height: 12),
                MasterDropdownField<String>(
                  label: 'Item Type',
                  value: _itemType,
                  items: const [
                    DropdownMenuItem(value: 'FOOD', child: Text('Food')),
                    DropdownMenuItem(
                      value: 'BEVERAGE',
                      child: Text('Beverage'),
                    ),

                    DropdownMenuItem(value: 'LIQUOR', child: Text('Liquor')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('Service')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => _itemType = value ?? 'FOOD'),
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _baseRateController,
                  label: 'Base Rate',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount < 0) {
                      return 'Enter a valid base rate';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedTaxGroupId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tax Group (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No tax group'),
                    ),
                    ..._taxGroups.map(
                      (group) => DropdownMenuItem<int?>(
                        value: group.taxGroupId,
                        child: Text(
                          '${group.taxGroupCode} - ${group.taxGroupName} '
                          '(${group.totalRate.toStringAsFixed(2)}%)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedTaxGroupId = value),
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _barcodeController,
                  label: 'Barcode (optional)',
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _imageUrlController,
                  label: 'Image URL (optional)',
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _preparationTimeController,
                  label: 'Preparation Time (minutes)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final minutes = int.tryParse(value?.trim() ?? '');
                    if (minutes == null || minutes < 0) {
                      return 'Enter a valid preparation time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vegetarian'),
                  value: _isVeg,
                  onChanged: (value) => setState(() => _isVeg = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contains Egg'),
                  value: _isEgg,
                  onChanged: (value) => setState(() => _isEgg = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Spicy'),
                  value: _isSpicy,
                  onChanged: (value) => setState(() => _isSpicy = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Discount'),
                  value: _allowDiscount,
                  onChanged: (value) => setState(() => _allowDiscount = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for Sale'),
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 12),
                MasterSaveActions(
                  isSaving: _saving,
                  isEditing: _isEditing,
                  onSave: _save,
                  onClear: _clearForm,
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                if (_editingItemId == null)
                  const Text('Save the menu item first to add its variants.')
                else
                  _buildVariantsSection(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                MenuItemModifierSection(
                  outletId: widget.outletId,
                  menuItemId: _editingItemId,
                  baseUrl: widget.baseUrl,
                  token: widget.token,
                  taxGroups: _taxGroups,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _items.where((item) {
      final category = _categoryName(item.categoryId).toLowerCase();

      return query.isEmpty ||
          item.itemCode.toLowerCase().contains(query) ||
          item.itemName.toLowerCase().contains(query) ||
          category.contains(query) ||
          (item.barcode ?? '').toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(title: 'Menu Items', count: filtered.length),

          const SizedBox(height: 12),

          MasterSearchField(
            controller: _searchController,
            hintText: 'Search item code, name, category or barcode...',
            onChanged: (_) {
              setState(() {});
            },
          ),

          const SizedBox(height: 12),

          // Do NOT use Expanded here.
          // MasterEntryScaffold already gives this widget
          // the required height.
          Flexible(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No menu items found.'
                          : 'No matching menu item found.',
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) {
                        return const Divider(height: 1);
                      },
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return ListTile(
                          dense: true,
                          title: Text(
                            item.itemName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.itemCode}  |  '
                            '${_categoryName(item.categoryId)}  |  '
                            '₹${item.baseRate.toStringAsFixed(2)}  |  '
                            '${item.itemType}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _editItem(item);
                            },
                          ),
                          onTap: () {
                            _editItem(item);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /*
  Widget _buildList() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      final category = _categoryName(item.categoryId).toLowerCase();
      return query.isEmpty ||
          item.itemCode.toLowerCase().contains(query) ||
          item.itemName.toLowerCase().contains(query) ||
          category.contains(query) ||
          (item.barcode ?? '').toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(title: 'Menu Items', count: filtered.length),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search item code, name, category or barcode...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No menu items found.'
                          : 'No matching menu item found.',
                    ),
                  )
                : Card(
                    child: Scrollbar(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.itemName),
                            subtitle: Text(
                              '${item.itemCode}  |  '
                              '${_categoryName(item.categoryId)}  |  '
                              '₹${item.baseRate.toStringAsFixed(2)}  |  '
                              '${item.itemType}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editItem(item),
                            ),
                            onTap: () => _editItem(item),
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
*/
  PosCategory? _findCategory(int categoryId) {
    for (final category in _categories) {
      if (category.categoryId == categoryId) return category;
    }
    return null;
  }

  String _categoryName(int categoryId) {
    for (final category in _categories) {
      if (category.categoryId == categoryId) {
        return category.categoryName;
      }
    }
    return 'Category $categoryId';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
