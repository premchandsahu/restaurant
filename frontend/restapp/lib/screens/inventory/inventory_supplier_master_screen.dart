import 'package:flutter/material.dart';

import '../../models/inventory/inventory_supplier.dart';
import '../../services/inventory/inventory_supplier_payment_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class InventorySupplierMasterScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const InventorySupplierMasterScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventorySupplierMasterScreen> createState() =>
      _InventorySupplierMasterScreenState();
}

class _InventorySupplierMasterScreenState
    extends State<InventorySupplierMasterScreen> {
  late final InventorySupplierPaymentService _service;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  List<InventorySupplier> _suppliers = [];
  int? _editingSupplierId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => _editingSupplierId != null;

  @override
  void initState() {
    super.initState();
    _service = InventorySupplierPaymentService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadSuppliers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _openingBalanceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final suppliers = await _service.getSuppliersForMaster();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
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
    _searchController.clear();
    await _loadSuppliers();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _gstinController.clear();
    _address1Controller.clear();
    _address2Controller.clear();
    _cityController.clear();
    _stateController.clear();
    _pincodeController.clear();
    _openingBalanceController.text = '0';

    if (!mounted) return;
    setState(() {
      _editingSupplierId = null;
      _isActive = true;
    });
  }

  void _editSupplier(InventorySupplier supplier) {
    _codeController.text = supplier.supplierCode;
    _nameController.text = supplier.supplierName;
    _mobileController.text = supplier.mobile ?? '';
    _emailController.text = supplier.email ?? '';
    _gstinController.text = supplier.gstin ?? '';
    _address1Controller.text = supplier.address1 ?? '';
    _address2Controller.text = supplier.address2 ?? '';
    _cityController.text = supplier.city ?? '';
    _stateController.text = supplier.state ?? '';
    _pincodeController.text = supplier.pincode ?? '';
    _openingBalanceController.text = supplier.openingBalance.toString();

    setState(() {
      _editingSupplierId = supplier.supplierId;
      _isActive = supplier.isActive;
    });
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final openingBalance =
        double.tryParse(_openingBalanceController.text.trim()) ?? 0;
    final payload = <String, dynamic>{
      'supplierCode': _codeController.text.trim(),
      'supplierName': _nameController.text.trim(),
      'mobile': _optionalText(_mobileController),
      'email': _optionalText(_emailController),
      'gstin': _optionalText(_gstinController),
      'address1': _optionalText(_address1Controller),
      'address2': _optionalText(_address2Controller),
      'city': _optionalText(_cityController),
      'state': _optionalText(_stateController),
      'pincode': _optionalText(_pincodeController),
      'openingBalance': openingBalance,
      if (_isEditing) 'isActive': _isActive,
    };

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _service.updateSupplier(
          supplierId: _editingSupplierId!,
          payload: payload,
        );
        _showMessage('Supplier updated successfully.');
      } else {
        await _service.createSupplier(payload: payload);
        _showMessage('Supplier created successfully.');
      }

      if (!mounted) return;
      _clearForm();
      await _loadSuppliers();
    } catch (e) {
      _showMessage('Unable to save supplier: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<InventorySupplier> get _visibleSuppliers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _suppliers;

    return _suppliers.where((supplier) {
      return supplier.supplierCode.toLowerCase().contains(query) ||
          supplier.supplierName.toLowerCase().contains(query) ||
          (supplier.mobile ?? '').toLowerCase().contains(query) ||
          (supplier.email ?? '').toLowerCase().contains(query) ||
          (supplier.gstin ?? '').toLowerCase().contains(query) ||
          (supplier.city ?? '').toLowerCase().contains(query) ||
          (supplier.state ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterEntryScaffold(
      title: 'Supplier Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAndReset,
      onRetry: _refreshAndReset,
      form: _buildForm(),
      list: _buildList(),
      formWidth: 420,
      compactFormHeight: 540,
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
                  _isEditing ? 'Edit Supplier' : 'New Supplier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                MasterTextField(
                  controller: _codeController,
                  label: 'Supplier Code',
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Supplier code is required'
                          : null,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _nameController,
                  label: 'Supplier Name',
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Supplier name is required'
                          : null,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _mobileController,
                  label: 'Mobile',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _gstinController,
                  label: 'GSTIN',
                  validator: (value) {
                    final gstin = value?.trim() ?? '';
                    if (gstin.isNotEmpty && gstin.length > 15) {
                      return 'GSTIN cannot exceed 15 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _address1Controller,
                  label: 'Address Line 1',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _address2Controller,
                  label: 'Address Line 2',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _cityController,
                  label: 'City',
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _stateController,
                  label: 'State',
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _pincodeController,
                  label: 'PIN Code',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _openingBalanceController,
                  label: 'Opening Balance',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) {
                    final balance = double.tryParse(value?.trim() ?? '');
                    if (balance == null || !balance.isFinite) {
                      return 'Enter a valid opening balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: Text(
                    _isEditing
                        ? 'Inactive suppliers remain visible in this master.'
                        : 'New suppliers are created as active.',
                  ),
                  value: _isActive,
                  onChanged: _saving || !_isEditing
                      ? null
                      : (value) => setState(() => _isActive = value),
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

  Widget _buildList() {
    final suppliers = _visibleSuppliers;
    final query = _searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(title: 'Suppliers', count: suppliers.length),
          const SizedBox(height: 12),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search code, name, mobile, GSTIN or city...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: suppliers.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No suppliers found.'
                          : 'No matching supplier found.',
                    ),
                  )
                : ListView.separated(
                    itemCount: suppliers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final supplier = suppliers[index];
                      final location = [
                        supplier.city,
                        supplier.state,
                      ].whereType<String>().where((s) => s.trim().isNotEmpty)
                          .join(', ');
                      final contact = [
                        supplier.supplierCode,
                        supplier.mobile,
                        supplier.gstin,
                      ].whereType<String>().where((s) => s.trim().isNotEmpty)
                          .join(' • ');

                      return Card(
                        child: ListTile(
                          onTap: () => _editSupplier(supplier),
                          leading: CircleAvatar(
                            child: Text(
                              supplier.supplierName.isEmpty
                                  ? '?'
                                  : supplier.supplierName[0].toUpperCase(),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  supplier.supplierName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                supplier.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: supplier.isActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                if (contact.isNotEmpty) contact,
                                if (location.isNotEmpty) location,
                                'Opening balance: ${supplier.openingBalance.toStringAsFixed(2)}',
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit supplier',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editSupplier(supplier),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
