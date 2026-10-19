import 'package:flutter/material.dart';

import '../../services/pos/menu_category_master_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class MenuCategoryMasterScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const MenuCategoryMasterScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<MenuCategoryMasterScreen> createState() =>
      _MenuCategoryMasterScreenState();
}

class _MenuCategoryMasterScreenState extends State<MenuCategoryMasterScreen> {
  late final MenuCategoryMasterService _service;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _displayOrderController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  List<MenuCategoryMasterRecord> _categories = [];
  int? _editingCategoryId;
  int? _selectedParentCategoryId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => _editingCategoryId != null;

  @override
  void initState() {
    super.initState();
    _service = MenuCategoryMasterService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _displayOrderController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final categories = await _service.getCategories(
        outletId: widget.outletId,
      );
      if (!mounted) return;

      setState(() {
        _categories = categories;
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

  Future<void> _refreshAndReset() async {
    _clearForm();
    await _loadAll();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    _displayOrderController.text = '0';

    if (!mounted) return;
    setState(() {
      _editingCategoryId = null;
      _selectedParentCategoryId = null;
      _isActive = true;
    });
  }

  String _categoryLabel(MenuCategoryMasterRecord category) =>
      '${category.categoryCode} - ${category.categoryName}';

  String _nameForParent(int? parentId) {
    if (parentId == null) return 'None';
    for (final category in _categories) {
      if (category.categoryId == parentId) return category.categoryName;
    }
    return 'Category $parentId';
  }

  void _editCategory(MenuCategoryMasterRecord category) {
    _codeController.text = category.categoryCode;
    _nameController.text = category.categoryName;
    _displayOrderController.text = category.displayOrder.toString();

    setState(() {
      _editingCategoryId = category.categoryId;
      _selectedParentCategoryId = category.parentCategoryId == category.categoryId
          ? null
          : category.parentCategoryId;
      _isActive = category.isActive;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedParentCategoryId != null &&
        _selectedParentCategoryId == _editingCategoryId) {
      _showMessage('A category cannot be its own parent.');
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      'categoryCode': _codeController.text.trim(),
      'categoryName': _nameController.text.trim(),
      'parentCategoryId': _selectedParentCategoryId,
      'displayOrder': int.parse(_displayOrderController.text.trim()),
      'isActive': _isActive,
    };

    try {
      if (_isEditing) {
        await _service.updateCategory(
          categoryId: _editingCategoryId!,
          payload: payload,
        );
        _showMessage('Menu category updated successfully.');
      } else {
        await _service.createCategory(payload: payload);
        _showMessage('Menu category created successfully.');
      }

      if (!mounted) return;
      _clearForm();
      await _loadAll();
    } catch (e) {
      _showMessage('Unable to save menu category: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Menu Category Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAndReset,
      onRetry: _refreshAndReset,
      form: _buildForm(),
      list: _buildList(),
      formWidth: 420,
      compactFormHeight: 470,
    );
  }

  Widget _buildForm() {
    final parentCandidates = _categories
        .where((category) => category.categoryId != _editingCategoryId)
        .toList();

    final selectedParentExists = _selectedParentCategoryId == null ||
        parentCandidates.any(
          (category) => category.categoryId == _selectedParentCategoryId,
        );

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Menu Category' : 'New Menu Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  MasterTextField(
                    controller: _codeController,
                    label: 'Category Code',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Category code is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  MasterTextField(
                    controller: _nameController,
                    label: 'Category Name',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Category name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: selectedParentExists ? _selectedParentCategoryId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Parent Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No parent category'),
                      ),
                      ...parentCandidates.map(
                        (category) => DropdownMenuItem<int?>(
                          value: category.categoryId,
                          child: Text(
                            _categoryLabel(category),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedParentCategoryId = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  MasterTextField(
                    controller: _displayOrderController,
                    label: 'Display Order',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final order = int.tryParse(value?.trim() ?? '');
                      if (order == null || order < 0) {
                        return 'Enter a whole number greater than or equal to 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive categories are excluded from normal category selection.',
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _categories.where((category) {
      return query.isEmpty ||
          category.categoryCode.toLowerCase().contains(query) ||
          category.categoryName.toLowerCase().contains(query) ||
          (category.parentCategoryName ?? '').toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(title: 'Menu Categories', count: filtered.length),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search code, category or parent category...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No menu categories found.'
                          : 'No matching category found.',
                    ),
                  )
                : Card(
                    child: Scrollbar(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final category = filtered[index];
                          final activeText = category.isActive ? 'Active' : 'Inactive';
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              category.parentCategoryId == null
                                  ? Icons.folder_outlined
                                  : Icons.subdirectory_arrow_right,
                            ),
                            title: Text(category.categoryName),
                            subtitle: Text(
                              '${category.categoryCode}  |  '
                              'Parent: ${category.parentCategoryName ?? _nameForParent(category.parentCategoryId)}  |  '
                              'Order: ${category.displayOrder}  |  $activeText',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
