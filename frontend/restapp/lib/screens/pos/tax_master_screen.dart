import 'package:flutter/material.dart';

import '../../services/pos/pos_tax_service.dart';
import '../../widgets/common/master_entry_widgets.dart';

class TaxMasterScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const TaxMasterScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<TaxMasterScreen> createState() => _TaxMasterScreenState();
}

class _TaxMasterScreenState extends State<TaxMasterScreen> {
  late final PosTaxService _service;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  List<TaxGroupMasterRecord> _groups = [];
  int? _editingGroupId;
  bool _groupIsActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditingGroup => _editingGroupId != null;

  @override
  void initState() {
    super.initState();
    _service = PosTaxService(baseUrl: widget.baseUrl, token: widget.token);
    _loadGroups();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final groups = await _service.getTaxGroupsForMaster();
      if (!mounted) return;
      setState(() {
        _groups = groups;
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
    _clearGroupForm();
    await _loadGroups();
  }

  void _clearGroupForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    if (!mounted) return;
    setState(() {
      _editingGroupId = null;
      _groupIsActive = true;
    });
  }

  void _editGroup(TaxGroupMasterRecord group) {
    _codeController.text = group.taxGroupCode;
    _nameController.text = group.taxGroupName;
    setState(() {
      _editingGroupId = group.taxGroupId;
      _groupIsActive = group.isActive;
    });
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'taxGroupCode': _codeController.text.trim(),
      'taxGroupName': _nameController.text.trim(),
      'isActive': _groupIsActive,
    };

    try {
      if (_isEditingGroup) {
        await _service.updateTaxGroup(
          taxGroupId: _editingGroupId!,
          payload: payload,
        );
        _showMessage('Tax group updated successfully.');
      } else {
        await _service.createTaxGroup(payload: payload);
        _showMessage('Tax group created successfully.');
      }

      if (!mounted) return;
      _clearGroupForm();
      await _loadGroups();
    } catch (e) {
      _showMessage('Unable to save tax group: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showRateDialog(
    TaxGroupMasterRecord group, {
    TaxRateMasterRecord? rate,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: rate?.taxName ?? '');
    final rateController = TextEditingController(
      text: rate == null ? '' : _formatRate(rate.rate),
    );
    String taxType = rate?.taxType ?? 'CGST';
    bool isInclusive = rate?.isInclusive ?? false;
    bool isActive = rate?.isActive ?? true;

    try {
      final payload = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(rate == null
                ? 'Add Tax Rate — ${group.taxGroupName}'
                : 'Edit Tax Rate — ${group.taxGroupName}'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Tax Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Tax name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: taxType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tax Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CGST', child: Text('CGST')),
                          DropdownMenuItem(value: 'SGST', child: Text('SGST')),
                          DropdownMenuItem(value: 'IGST', child: Text('IGST')),
                          DropdownMenuItem(value: 'CESS', child: Text('CESS')),
                          DropdownMenuItem(value: 'OTHER', child: Text('OTHER')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => taxType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rate (%)',
                          hintText: 'e.g. 2.5',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null ||
                              !parsed.isFinite ||
                              parsed < 0 ||
                              parsed > 9999.9999) {
                            return 'Enter a rate from 0 to 9999.9999';
                          }
                          if ((value!.trim().split('.').length > 1) &&
                              value.trim().split('.')[1].length > 4) {
                            return 'Maximum 4 decimal places';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tax inclusive'),
                        subtitle: const Text(
                          'The item price already includes this tax',
                        ),
                        value: isInclusive,
                        onChanged: (value) => setDialogState(
                          () => isInclusive = value,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) => setDialogState(
                          () => isActive = value,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('CANCEL'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(dialogContext).pop(<String, dynamic>{
                    'taxName': nameController.text.trim(),
                    'taxType': taxType,
                    'rate': double.parse(rateController.text.trim()),
                    'isInclusive': isInclusive,
                    'isActive': isActive,
                  });
                },
                icon: const Icon(Icons.save),
                label: Text(rate == null ? 'ADD' : 'UPDATE'),
              ),
            ],
          ),
        ),
      );

      if (payload == null || !mounted) return;
      setState(() => _saving = true);
      try {
        if (rate == null) {
          await _service.createTaxRate(
            taxGroupId: group.taxGroupId,
            payload: payload,
          );
          _showMessage('Tax rate added successfully.');
        } else {
          await _service.updateTaxRate(
            taxRateId: rate.taxRateId,
            payload: payload,
          );
          _showMessage('Tax rate updated successfully.');
        }
        await _loadGroups();
      } catch (e) {
        _showMessage('Unable to save tax rate: $e');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } finally {
      nameController.dispose();
      rateController.dispose();
    }
  }

  String _formatRate(double value) {
    var text = value.toStringAsFixed(4);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  List<TaxGroupMasterRecord> get _visibleGroups {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _groups;
    return _groups.where((group) {
      return group.taxGroupCode.toLowerCase().contains(query) ||
          group.taxGroupName.toLowerCase().contains(query) ||
          group.rates.any((rate) =>
              rate.taxName.toLowerCase().contains(query) ||
              rate.taxType.toLowerCase().contains(query));
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
      title: 'Tax Group & Rate Master',
      isLoading: _loading,
      errorMessage: _errorMessage,
      onRefresh: _refreshAndReset,
      onRetry: _refreshAndReset,
      form: _buildGroupForm(),
      list: _buildGroupList(),
      formWidth: 390,
      compactFormHeight: 390,
    );
  }

  Widget _buildGroupForm() {
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
                  _isEditingGroup ? 'Edit Tax Group' : 'New Tax Group',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                MasterTextField(
                  controller: _codeController,
                  label: 'Tax Group Code',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tax group code is required';
                    }
                    if (value.trim().length > 50) {
                      return 'Maximum 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MasterTextField(
                  controller: _nameController,
                  label: 'Tax Group Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tax group name is required';
                    }
                    if (value.trim().length > 100) {
                      return 'Maximum 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive groups remain in the master list'),
                  value: _groupIsActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _groupIsActive = value),
                ),
                const SizedBox(height: 12),
                MasterSaveActions(
                  isSaving: _saving,
                  isEditing: _isEditingGroup,
                  onSave: _saveGroup,
                  onClear: _clearGroupForm,
                ),
                if (_isEditingGroup) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _saving ? null : _clearGroupForm,
                    icon: const Icon(Icons.add),
                    label: const Text('NEW TAX GROUP'),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(),
                const Text(
                  'Tax rates are maintained under each group in the list.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    final groups = _visibleGroups;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MasterListHeader(
            title: 'Tax Groups',
            count: groups.length,
          ),
          const SizedBox(height: 10),
          MasterSearchField(
            controller: _searchController,
            hintText: 'Search code, group or tax type',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: groups.isEmpty
                ? const Center(child: Text('No tax groups found.'))
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          key: PageStorageKey<String>(
                            'tax-group-${group.taxGroupId}',
                          ),
                          leading: Icon(
                            group.isActive
                                ? Icons.receipt_long
                                : Icons.receipt_long_outlined,
                            color: group.isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                          title: Text(
                            '${group.taxGroupCode} — ${group.taxGroupName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: group.isActive
                                  ? null
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                          subtitle: Text(
                            '${group.rates.length} rate(s) · '
                            '${group.isActive ? 'Active' : 'Inactive'}',
                          ),
                          trailing: SizedBox(
                            width: 96,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Edit tax group',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _saving ? null : () => _editGroup(group),
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _showRateDialog(group),
                                      icon: const Icon(Icons.add),
                                      label: const Text('ADD TAX RATE'),
                                    ),
                                  ),
                                  if (group.rates.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Text('No rates defined for this group.'),
                                    ),
                                  ...group.rates.map((rate) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          rate.isActive
                                              ? Icons.percent
                                              : Icons.do_not_disturb_on_outlined,
                                          color: rate.isActive
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).disabledColor,
                                        ),
                                        title: Text(
                                          '${rate.taxName} (${rate.taxType})',
                                          style: TextStyle(
                                            color: rate.isActive
                                                ? null
                                                : Theme.of(context).disabledColor,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${_formatRate(rate.rate)}% · '
                                          '${rate.isInclusive ? 'Inclusive' : 'Exclusive'} · '
                                          '${rate.isActive ? 'Active' : 'Inactive'}',
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Edit tax rate',
                                          onPressed: _saving
                                              ? null
                                              : () => _showRateDialog(group, rate: rate),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
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
