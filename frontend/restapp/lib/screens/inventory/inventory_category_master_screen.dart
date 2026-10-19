import 'package:flutter/material.dart';

import '../../services/inventory/inventory_raw_material_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class InventoryCategoryMasterScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const InventoryCategoryMasterScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryCategoryMasterScreen> createState() =>
      _InventoryCategoryMasterScreenState();
}

class _InventoryCategoryMasterScreenState
    extends State<InventoryCategoryMasterScreen> {
  late final InventoryRawMaterialService _service;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  List<InventoryCategoryOption> _categories = [];
  int? _editingCategoryId;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => _editingCategoryId != null;

  @override
  void initState() {
    super.initState();
    _service = InventoryRawMaterialService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadCategories();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    debugPrint('[InventoryCategoryMaster] Loading started');

    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[InventoryCategoryMaster] Calling GET /inventory/categories');
      final categories = await _service.getCategories().timeout(
        const Duration(seconds: 15),
      );
      debugPrint(
        '[InventoryCategoryMaster] Response received: ${categories.length} categories',
      );

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _errorMessage = null;
      });
      debugPrint('[InventoryCategoryMaster] Loading completed');
    } catch (e, stackTrace) {
      debugPrint('[InventoryCategoryMaster] ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshAndReset() async {
    _clearForm();
    await _loadCategories();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    if (!mounted) return;
    setState(() => _editingCategoryId = null);
  }

  void _editCategory(InventoryCategoryOption category) {
    _codeController.text = category.categoryCode;
    _nameController.text = category.categoryName;
    setState(() => _editingCategoryId = category.inventoryCategoryId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'categoryCode': _codeController.text.trim(),
      'categoryName': _nameController.text.trim(),
    };

    try {
      if (_isEditing) {
        await _service.updateInventoryCategory(
          categoryId: _editingCategoryId!,
          payload: payload,
        );
        _showMessage('Inventory category updated successfully.');
      } else {
        await _service.createInventoryCategory(payload: payload);
        _showMessage('Inventory category created successfully.');
      }

      if (!mounted) return;
      _clearForm();
      await _loadCategories();
    } catch (e) {
      _showMessage('Unable to save inventory category: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<InventoryCategoryOption> get _visibleCategories {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _categories;
    return _categories.where((category) {
      return category.categoryCode.toLowerCase().contains(query) ||
          category.categoryName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Inventory Category Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAndReset,
      onRetry: _refreshAndReset,
      form: _buildForm(),
      list: _buildList(),
      formWidth: 390,
      compactFormHeight: 340,
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
                  _isEditing
                      ? 'Edit Inventory Category'
                      : 'New Inventory Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                MasterTextField(
                  controller: _codeController,
                  label: 'Category Code',
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.isEmpty) return 'Category code is required';
                    if (code.length > 50) return 'Maximum 50 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _nameController,
                  label: 'Category Name',
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Category name is required';
                    if (name.length > 150) return 'Maximum 150 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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

  Widget _buildList() {
    final categories = _visibleCategories;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(
            title: 'Inventory Categories',
            count: categories.length,
          ),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search category code or name...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No inventory categories found.'
                          : 'No matching category found.',
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(category.categoryName),
                          subtitle: Text(category.categoryCode),
                          trailing: IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editCategory(category),
                          ),
                          onTap: () => _editCategory(category),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
