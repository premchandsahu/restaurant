import 'package:flutter/material.dart';

import '../../models/inventory/inventory_raw_material.dart';
import '../../services/inventory/inventory_raw_material_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class InventoryUnitMasterScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const InventoryUnitMasterScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryUnitMasterScreen> createState() =>
      _InventoryUnitMasterScreenState();
}

class _InventoryUnitMasterScreenState extends State<InventoryUnitMasterScreen> {
  late final InventoryRawMaterialService _service;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _decimalPlacesController = TextEditingController(text: '3');
  final _searchController = TextEditingController();

  List<InventoryUnit> _units = [];
  int? _editingUnitId;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => _editingUnitId != null;

  @override
  void initState() {
    super.initState();
    _service = InventoryRawMaterialService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadUnits();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _decimalPlacesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final units = await _service.getUnits();
      if (!mounted) return;
      setState(() {
        _units = units;
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
    await _loadUnits();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    _decimalPlacesController.text = '3';
    if (!mounted) return;
    setState(() => _editingUnitId = null);
  }

  void _editUnit(InventoryUnit unit) {
    _codeController.text = unit.unitCode;
    _nameController.text = unit.unitName;
    _decimalPlacesController.text = unit.decimalPlaces.toString();
    setState(() => _editingUnitId = unit.unitId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'unitCode': _codeController.text.trim(),
      'unitName': _nameController.text.trim(),
      'decimalPlaces': int.parse(_decimalPlacesController.text.trim()),
    };

    try {
      if (_isEditing) {
        await _service.updateUnit(
          unitId: _editingUnitId!,
          payload: payload,
        );
        _showMessage('Unit updated successfully.');
      } else {
        await _service.createUnit(payload: payload);
        _showMessage('Unit created successfully.');
      }

      if (!mounted) return;
      _clearForm();
      await _loadUnits();
    } catch (e) {
      _showMessage('Unable to save unit: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<InventoryUnit> get _visibleUnits {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _units;
    return _units.where((unit) =>
      unit.unitCode.toLowerCase().contains(query) ||
      unit.unitName.toLowerCase().contains(query) ||
      unit.decimalPlaces.toString().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Inventory Unit Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAndReset,
      onRetry: _refreshAndReset,
      form: _buildForm(),
      list: _buildList(),
      formWidth: 390,
      compactFormHeight: 390,
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
                  _isEditing ? 'Edit Unit' : 'New Unit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                MasterTextField(
                  controller: _codeController,
                  label: 'Unit Code',
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.isEmpty) return 'Unit code is required';
                    if (code.length > 20) return 'Maximum 20 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _nameController,
                  label: 'Unit Name',
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Unit name is required';
                    if (name.length > 50) return 'Maximum 50 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _decimalPlacesController,
                  label: 'Decimal Places (0–10)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final places = int.tryParse(value?.trim() ?? '');
                    if (places == null || places < 0 || places > 10) {
                      return 'Enter a whole number from 0 to 10';
                    }
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
    final units = _visibleUnits;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(title: 'Inventory Units', count: units.length),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search unit code, name or decimal places...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: units.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No units found.'
                          : 'No matching unit found.',
                    ),
                  )
                : Card(
                    child: Scrollbar(
                      child: ListView.separated(
                        itemCount: units.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final unit = units[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.straighten),
                            title: Text(unit.unitName),
                            subtitle: Text(
                              '${unit.unitCode}  |  '
                              'Decimal places: ${unit.decimalPlaces}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit),
                              onPressed: _saving ? null : () => _editUnit(unit),
                            ),
                            onTap: _saving ? null : () => _editUnit(unit),
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
