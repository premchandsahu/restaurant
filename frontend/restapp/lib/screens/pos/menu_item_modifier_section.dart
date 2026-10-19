import 'package:flutter/material.dart';

import '../../models/pos/pos_tax.dart';
import '../../services/pos/pos_menu_service.dart';

/// Modifier Group/Option editor embedded in Menu Item Master.
/// Uses raw maps returned by GET /menu/modifier-groups so it does not
/// require any changes to the existing PosModifierGroup model.
class MenuItemModifierSection extends StatefulWidget {
  final int outletId;
  final int? menuItemId;
  final String baseUrl;
  final String token;
  final List<PosTaxGroup> taxGroups;

  const MenuItemModifierSection({
    super.key,
    required this.outletId,
    required this.menuItemId,
    required this.baseUrl,
    required this.token,
    required this.taxGroups,
  });

  @override
  State<MenuItemModifierSection> createState() =>
      _MenuItemModifierSectionState();
}

class _MenuItemModifierSectionState extends State<MenuItemModifierSection> {
  late final PosMenuService _service;

  List<Map<String, dynamic>> _groups = [];
  Set<int> _assignedGroupIds = {};
  bool _loading = false;
  bool _savingAssignment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = PosMenuService(baseUrl: widget.baseUrl, token: widget.token);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MenuItemModifierSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outletId != widget.outletId ||
        oldWidget.menuItemId != widget.menuItemId ||
        oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.token != widget.token) {
      _loadData();
    }
  }

  int _intValue(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _doubleValue(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _boolValue(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return fallback;
    final text = value.toString().toLowerCase();
    if (text == '1' || text == 'true' || text == 'yes') return true;
    if (text == '0' || text == 'false' || text == 'no') return false;
    return fallback;
  }

  int _groupId(Map<String, dynamic> group) =>
      _intValue(group['modifier_group_id'] ?? group['modifierGroupId']);

  int _optionId(Map<String, dynamic> option) =>
      _intValue(option['modifier_option_id'] ?? option['modifierOptionId']);

  bool _groupIsActive(Map<String, dynamic> group) =>
      _boolValue(group['is_active'] ?? group['isActive'], true);

  bool _optionIsActive(Map<String, dynamic> option) =>
      _boolValue(option['is_active'] ?? option['isActive'], true);

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final groupsFuture = _service.getModifierGroups(
        outletId: widget.outletId,
      );
      final assignedFuture = widget.menuItemId == null
          ? Future<List<int>>.value(<int>[])
          : _service.getAssignedModifierGroupIds(
              menuItemId: widget.menuItemId!,
              outletId: widget.outletId,
            );

      final results = await Future.wait<dynamic>([
        groupsFuture,
        assignedFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<Map<String, dynamic>>);
        _assignedGroupIds = (results[1] as List<int>).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addOrEditGroup([Map<String, dynamic>? group]) async {
    final result = await _showGroupDialog(group);
    if (result == null) return;

    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      ...result,
    };

    try {
      if (group == null) {
        await _service.createModifierGroup(payload: payload);
        _showMessage('Modifier group created successfully.');
      } else {
        await _service.updateModifierGroup(
          groupId: _groupId(group),
          payload: payload,
        );
        _showMessage('Modifier group updated successfully.');
      }
      await _loadData();
    } catch (e) {
      _showMessage('Unable to save modifier group: $e');
    }
  }

  Future<Map<String, dynamic>?> _showGroupDialog(
    Map<String, dynamic>? group,
  ) async {
    final nameController = TextEditingController(
      text: (group?['group_name'] ?? group?['groupName'] ?? '').toString(),
    );
    final minController = TextEditingController(
      text: _intValue(group?['min_selection'], 0).toString(),
    );
    final maxController = TextEditingController(
      text: _intValue(group?['max_selection'], 99).toString(),
    );
    final orderController = TextEditingController(
      text: _intValue(group?['display_order'], 0).toString(),
    );
    String selectionType =
        (group?['selection_type'] ?? 'MULTIPLE').toString().toUpperCase();
    bool isActive = _groupIsActive(group ?? <String, dynamic>{});
    String? validationError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Add Modifier Group' : 'Edit Modifier Group'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectionType,
                    decoration: const InputDecoration(
                      labelText: 'Selection Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SINGLE', child: Text('Single choice')),
                      DropdownMenuItem(value: 'MULTIPLE', child: Text('Multiple choice')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectionType = value;
                        if (value == 'SINGLE') maxController.text = '1';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maximum',
                            border: OutlineInputBorder(),
                          ),
                          enabled: selectionType != 'SINGLE',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setDialogState(
                      () => isActive = value ?? true,
                    ),
                  ),
                  if (validationError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final min = int.tryParse(minController.text.trim());
                final max = selectionType == 'SINGLE'
                    ? 1
                    : int.tryParse(maxController.text.trim());
                final order = int.tryParse(orderController.text.trim());

                if (name.isEmpty) {
                  setDialogState(() => validationError = 'Group name is required.');
                } else if (min == null || max == null || order == null ||
                    min < 0 || max < 0 || order < 0 || min > max) {
                  setDialogState(() => validationError = 'Enter valid selection limits and display order.');
                } else {
                  Navigator.pop(dialogContext, <String, dynamic>{
                    'groupName': name,
                    'selectionType': selectionType,
                    'minSelection': min,
                    'maxSelection': max,
                    'displayOrder': order,
                    'isActive': isActive,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    minController.dispose();
    maxController.dispose();
    orderController.dispose();
    return result;
  }

  Future<void> _addOrEditOption(
    Map<String, dynamic> group, [
    Map<String, dynamic>? option,
  ]) async {
    final result = await _showOptionDialog(option);
    if (result == null) return;

    final groupId = _groupId(group);
    final payload = <String, dynamic>{
      'outletId': widget.outletId,
      ...result,
    };

    try {
      if (option == null) {
        await _service.createModifierOption(
          groupId: groupId,
          payload: payload,
        );
        _showMessage('Modifier option created successfully.');
      } else {
        await _service.updateModifierOption(
          groupId: groupId,
          optionId: _optionId(option),
          payload: payload,
        );
        _showMessage('Modifier option updated successfully.');
      }
      await _loadData();
    } catch (e) {
      _showMessage('Unable to save modifier option: $e');
    }
  }

  Future<Map<String, dynamic>?> _showOptionDialog(
    Map<String, dynamic>? option,
  ) async {
    final nameController = TextEditingController(
      text: (option?['option_name'] ?? option?['optionName'] ?? '').toString(),
    );
    final rateController = TextEditingController(
      text: _doubleValue(option?['extra_rate'], 0).toStringAsFixed(2),
    );
    final orderController = TextEditingController(
      text: _intValue(option?['display_order'], 0).toString(),
    );
    bool isActive = _optionIsActive(option ?? <String, dynamic>{});
    final rawTaxGroupId = option?['tax_group_id'] ?? option?['taxGroupId'];
    int? taxGroupId = rawTaxGroupId == null || rawTaxGroupId == ''
        ? null
        : _intValue(rawTaxGroupId);
    if (taxGroupId != null &&
        !widget.taxGroups.any((taxGroup) => taxGroup.taxGroupId == taxGroupId)) {
      taxGroupId = null;
    }
    String? validationError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(option == null ? 'Add Modifier Option' : 'Edit Modifier Option'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Option Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Additional Rate',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: taxGroupId,
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
                      ...widget.taxGroups.map(
                        (taxGroup) => DropdownMenuItem<int?>(
                          value: taxGroup.taxGroupId,
                          child: Text(
                            '${taxGroup.taxGroupCode} - ${taxGroup.taxGroupName} '
                            '(${taxGroup.totalRate.toStringAsFixed(2)}%)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => taxGroupId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setDialogState(
                      () => isActive = value ?? true,
                    ),
                  ),
                  if (validationError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final rate = double.tryParse(rateController.text.trim());
                final order = int.tryParse(orderController.text.trim());

                if (name.isEmpty) {
                  setDialogState(() => validationError = 'Option name is required.');
                } else if (rate == null || rate < 0 || order == null || order < 0) {
                  setDialogState(() => validationError = 'Enter a valid rate and display order.');
                } else {
                  Navigator.pop(dialogContext, <String, dynamic>{
                    'optionName': name,
                    'extraRate': rate,
                    'taxGroupId': taxGroupId,
                    'displayOrder': order,
                    'isActive': isActive,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    rateController.dispose();
    orderController.dispose();
    return result;
  }

  Future<void> _saveAssignments() async {
    final menuItemId = widget.menuItemId;
    if (menuItemId == null) return;

    setState(() => _savingAssignment = true);
    try {
      final ids = _assignedGroupIds.toList()..sort();
      await _service.setMenuItemModifierGroups(
        menuItemId: menuItemId,
        outletId: widget.outletId,
        modifierGroupIds: ids,
      );
      _showMessage('Modifier groups assigned to menu item successfully.');
    } catch (e) {
      _showMessage('Unable to assign modifier groups: $e');
    } finally {
      if (mounted) setState(() => _savingAssignment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Modifier Groups & Options',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh modifier groups',
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Add modifier group',
                  onPressed: () => _addOrEditGroup(),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (widget.menuItemId == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Save or select a menu item to assign modifier groups to it. You can still maintain groups and options here.',
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_loading && _groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No modifier groups found. Use + to add one.'),
              ),
            ..._groups.map(_buildGroupTile),
            if (widget.menuItemId != null && _groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _savingAssignment ? null : _saveAssignments,
                  icon: _savingAssignment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Save Groups to This Menu Item'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final groupId = _groupId(group);
    final groupName = (group['group_name'] ?? group['groupName'] ?? '').toString();
    final active = _groupIsActive(group);
    final selected = _assignedGroupIds.contains(groupId);
    final options = (group['options'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        key: PageStorageKey<String>('modifier-group-$groupId'),
        leading: widget.menuItemId == null
            ? null
            : Checkbox(
                value: selected,
                onChanged: (!active && !selected)
                    ? null
                    : (value) {
                        setState(() {
                          if (value == true) {
                            _assignedGroupIds.add(groupId);
                          } else {
                            _assignedGroupIds.remove(groupId);
                          }
                        });
                      },
              ),
        title: Text(
          '$groupName${active ? '' : ' (INACTIVE)'}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? null : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: Text(
          '${(group['selection_type'] ?? 'MULTIPLE').toString()}  ·  '
          'Min ${_intValue(group['min_selection'])} / '
          'Max ${_intValue(group['max_selection'], 99)}  ·  '
          '${options.length} option(s)',
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Edit group',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addOrEditGroup(group),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Add option',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addOrEditOption(group),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        children: [
          if (options.isEmpty)
            const ListTile(
              dense: true,
              title: Text('No options added yet.'),
            ),
          ...options.map((option) {
            final optionName =
                (option['option_name'] ?? option['optionName'] ?? '').toString();
            final optionActive = _optionIsActive(option);
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 24, right: 12),
              title: Text(
                '$optionName${optionActive ? '' : ' (INACTIVE)'}',
                style: TextStyle(
                  color: optionActive ? null : Theme.of(context).disabledColor,
                ),
              ),
              subtitle: Text(
                'Extra rate: ₹${_doubleValue(option['extra_rate']).toStringAsFixed(2)}',
              ),
              trailing: IconButton(
                tooltip: 'Edit option',
                onPressed: () => _addOrEditOption(group, option),
                icon: const Icon(Icons.edit_outlined),
              ),
            );
          }),
        ],
      ),
    );
  }
}
