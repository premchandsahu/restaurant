import 'package:flutter/material.dart';
import '../services/captain_order_service.dart';
import '../models/captain_table.dart';
import '../services/captain_menu_service.dart';

class CaptainOrderScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final CaptainTable table;
  final int? orderId;
  final int outletId;
  const CaptainOrderScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.table,
    this.orderId,
    required this.outletId,
  });

  @override
  State<CaptainOrderScreen> createState() => _CaptainOrderScreenState();
}

class _CaptainOrderScreenState extends State<CaptainOrderScreen> {
  late final CaptainMenuService _menuService;

  late final CaptainOrderService _orderService;

  int? _currentOrderId;
  int _guestCount = 1;

  bool _savingOrder = false;

  bool _requestingBill = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];

  int? _selectedCategoryId;

  bool _loadingCategories = true;
  bool _loadingItems = false;

  String? _error;

  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  final List<_CaptainCartItem> _cart = [];

  Map<String, dynamic>? _existingOrder;

  bool _loadingExistingOrder = false;

  @override
  void initState() {
    super.initState();

    _menuService = CaptainMenuService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _orderService = CaptainOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _currentOrderId = widget.orderId;

    _loadCategories();
    if (_currentOrderId != null) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadExistingOrder() async {
    if (_currentOrderId == null) {
      return;
    }

    setState(() {
      _loadingExistingOrder = true;
    });

    try {
      final data = await _orderService.getOrder(orderId: _currentOrderId!);

      if (!mounted) return;

      setState(() {
        _existingOrder = data['order'] is Map
            ? Map<String, dynamic>.from(data['order'])
            : data;

        _loadingExistingOrder = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingExistingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load order: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<bool> _saveOrder() async {
    if (_savingOrder) {
      return false;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );

      return false;
    }

    setState(() {
      _savingOrder = true;
    });

    try {
      // --------------------------------------------
      // Create order when required
      // --------------------------------------------

      if (_currentOrderId == null) {
        _currentOrderId = await _orderService.createOrder(
          outletId: _outletId,
          tableId: widget.table.tableId,
          guestCount: _guestCount,
        );
      }

      // --------------------------------------------
      // Add cart items
      // --------------------------------------------

      for (final item in _cart) {
        await _orderService.addItem(
          orderId: _currentOrderId!,
          menuItemId: item.menuItemId,
          variantId: item.variantId,
          quantity: item.quantity.toDouble(),
          modifiers: item.modifiers
              .map(
                (modifier) => {
                  'modifierGroupId': modifier.groupId,
                  'modifierOptionId': modifier.optionId,
                  'qty': 1,
                },
              )
              .toList(),
        );
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        _cart.clear();
      });

      await _loadExistingOrder();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #$_currentOrderId saved successfully')),
      );

      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save order: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingOrder = false;
        });
      }
    }
  }

  Future<void> _sendToKitchen() async {
    if (_savingOrder) {
      return;
    }

    // --------------------------------------------
    // Save pending cart items first
    // --------------------------------------------

    if (_cart.isNotEmpty) {
      final saved = await _saveOrder();

      if (!saved) {
        return;
      }
    }

    if (_currentOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items before sending to kitchen'),
        ),
      );

      return;
    }

    setState(() {
      _savingOrder = true;
    });

    try {
      await _orderService.sendToKitchen(orderId: _currentOrderId!);
      await _loadExistingOrder();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #$_currentOrderId sent to kitchen')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send to kitchen: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingOrder = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestBill() async {
    if (_requestingBill) {
      return;
    }

    if (_currentOrderId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final total = _toDouble(_existingOrder?['grand_total']);

        return AlertDialog(
          title: const Text('Request Bill'),
          content: Text(
            'Request bill for Order '
            '#$_currentOrderId?\n\n'
            'Amount: ₹${total.toStringAsFixed(2)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('REQUEST BILL'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _requestingBill = true;
    });

    try {
      await _orderService.requestBill(orderId: _currentOrderId!);

      if (!mounted) {
        return;
      }

      await _loadExistingOrder();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill requested successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to request bill: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _requestingBill = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _loadingCategories = true;
        _error = null;
      });

      final categories = await _menuService.getCategories(outletId: _outletId);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;

        if (_categories.isNotEmpty) {
          _selectedCategoryId = _toInt(_categories.first['menu_category_id']);
        }

        _loadingCategories = false;
      });

      if (_selectedCategoryId != null) {
        await _loadItems(_selectedCategoryId!);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCategories = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadItems(int categoryId) async {
    try {
      setState(() {
        _loadingItems = true;
      });

      final items = await _menuService.getItems(
        outletId: _outletId,
        categoryId: categoryId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingItems = false;
        _items = [];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onCategorySelected(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _items = [];
      _searchController.clear();
      _searchText = '';
      _loadingItems = true;
      _error = null;
    });

    try {
      final items = categoryId == null
          ? await _menuService.getAllItems(outletId: _outletId)
          : await _menuService.getItems(
              outletId: _outletId,
              categoryId: categoryId,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingItems = false;
        _items = [];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _addSelectionToCart(_CaptainItemSelection selection) {
    final existingIndex = _cart.indexWhere(
      (item) => item.isSameConfiguration(
        selection.menuItemId,
        selection.variantId,
        selection.modifiers,
      ),
    );

    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(
          _CaptainCartItem(
            menuItemId: selection.menuItemId,
            itemName: selection.itemName,
            variantId: selection.variantId,
            variantName: selection.variantName,
            modifiers: selection.modifiers,
            rate: selection.rate,
            quantity: 1,
          ),
        );
      }
    });
  }

  Future<void> _showItemSelectionDialog(Map<String, dynamic> details) async {
    final item = Map<String, dynamic>.from(details['item'] ?? {});

    final variants = (details['variants'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final modifierGroups = (details['modifierGroups'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    int? selectedVariantId;

    if (variants.isNotEmpty) {
      final defaultVariant = variants.firstWhere(
        (variant) =>
            variant['is_default'] == true || variant['is_default'] == 1,
        orElse: () => variants.first,
      );

      selectedVariantId = _toInt(defaultVariant['variant_id']);
    }

    final selectedModifiers = <int, List<int>>{};

    for (final group in modifierGroups) {
      final groupId = _toInt(group['modifier_group_id']);

      if (groupId == null) {
        continue;
      }

      selectedModifiers[groupId] = [];
    }

    final result = await showDialog<_CaptainItemSelection>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double selectedRate = _toDouble(item['base_rate']);

            if (selectedVariantId != null) {
              for (final variant in variants) {
                final variantId = _toInt(variant['variant_id']);

                if (variantId == selectedVariantId) {
                  selectedRate = _toDouble(variant['rate']);
                  break;
                }
              }
            }

            double modifierTotal = 0;

            for (final group in modifierGroups) {
              final groupId = _toInt(group['modifier_group_id']);

              if (groupId == null) {
                continue;
              }

              final selected = selectedModifiers[groupId] ?? [];

              final options = group['options'] as List? ?? [];

              for (final option in options) {
                final optionMap = Map<String, dynamic>.from(option);

                final optionId = _toInt(optionMap['modifier_option_id']);

                if (optionId != null && selected.contains(optionId)) {
                  modifierTotal += _toDouble(optionMap['extra_rate']);
                }
              }
            }

            final finalRate = selectedRate + modifierTotal;

            return AlertDialog(
              title: Text(item['item_name']?.toString() ?? 'Select Item'),

              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --------------------------------
                      // VARIANTS
                      // --------------------------------
                      if (variants.isNotEmpty) ...[
                        const Text(
                          'Variant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        ...variants.map((variant) {
                          final variantId = _toInt(variant['variant_id']);

                          final rate = _toDouble(variant['rate']);

                          return RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            value: variantId ?? 0,
                            groupValue: selectedVariantId,
                            title: Text(
                              variant['variant_name']?.toString() ?? 'Variant',
                            ),
                            subtitle: Text('₹${rate.toStringAsFixed(2)}'),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedVariantId = value;
                              });
                            },
                          );
                        }),

                        const Divider(),
                      ],

                      // --------------------------------
                      // MODIFIERS
                      // --------------------------------
                      ...modifierGroups.map((group) {
                        final groupId = _toInt(group['modifier_group_id']);

                        if (groupId == null) {
                          return const SizedBox();
                        }

                        final selectionType = group['selection_type']
                            ?.toString()
                            .toUpperCase();

                        final minSelection =
                            _toInt(group['min_selection']) ?? 0;

                        final maxSelection =
                            _toInt(group['max_selection']) ?? 99;

                        final options = group['options'] as List? ?? [];

                        final selected = selectedModifiers[groupId] ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group['group_name']?.toString() ?? 'Options',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              selectionType == 'SINGLE'
                                  ? 'Select one'
                                  : maxSelection < 99
                                  ? 'Select up to $maxSelection'
                                  : 'Select as required',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 5),

                            ...options.map((option) {
                              final optionMap = Map<String, dynamic>.from(
                                option,
                              );

                              final optionId = _toInt(
                                optionMap['modifier_option_id'],
                              );

                              if (optionId == null) {
                                return const SizedBox();
                              }

                              final isSelected = selected.contains(optionId);

                              final extraRate = _toDouble(
                                optionMap['extra_rate'],
                              );

                              if (selectionType == 'SINGLE') {
                                return RadioListTile<int>(
                                  contentPadding: EdgeInsets.zero,
                                  value: optionId,
                                  groupValue: selected.isEmpty
                                      ? null
                                      : selected.first,
                                  title: Text(
                                    optionMap['option_name']?.toString() ??
                                        'Option',
                                  ),
                                  subtitle: extraRate > 0
                                      ? Text(
                                          '+ ₹${extraRate.toStringAsFixed(2)}',
                                        )
                                      : null,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedModifiers[groupId] = value == null
                                          ? []
                                          : [value];
                                    });
                                  },
                                );
                              }

                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: isSelected,
                                title: Text(
                                  optionMap['option_name']?.toString() ??
                                      'Option',
                                ),
                                subtitle: extraRate > 0
                                    ? Text('+ ₹${extraRate.toStringAsFixed(2)}')
                                    : null,
                                onChanged: (checked) {
                                  setDialogState(() {
                                    final current = List<int>.from(
                                      selectedModifiers[groupId] ?? [],
                                    );

                                    if (checked == true) {
                                      if (current.length < maxSelection) {
                                        current.add(optionId);
                                      }
                                    } else {
                                      current.remove(optionId);
                                    }

                                    selectedModifiers[groupId] = current;
                                  });
                                },
                              );
                            }),

                            if (minSelection > 0 &&
                                selected.length < minSelection)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Minimum $minSelection selection'
                                  '${minSelection == 1 ? '' : 's'} required',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
                                ),
                              ),

                            const Divider(),
                          ],
                        );
                      }),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          const Text(
                            'Rate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '₹${finalRate.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('CANCEL'),
                ),

                ElevatedButton(
                  onPressed: () {
                    // ------------------------------
                    // Validate minimum selections
                    // ------------------------------

                    for (final group in modifierGroups) {
                      final groupId = _toInt(group['modifier_group_id']);

                      if (groupId == null) {
                        continue;
                      }

                      final minSelection = _toInt(group['min_selection']) ?? 0;

                      final selected = selectedModifiers[groupId] ?? [];

                      if (selected.length < minSelection) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please select at least '
                              '$minSelection option'
                              '${minSelection == 1 ? '' : 's'} '
                              'for ${group['group_name']}',
                            ),
                          ),
                        );

                        return;
                      }
                    }

                    // ------------------------------
                    // Build modifier list
                    // ------------------------------

                    final modifiers = <_CaptainCartModifier>[];

                    for (final group in modifierGroups) {
                      final groupId = _toInt(group['modifier_group_id']);

                      if (groupId == null) {
                        continue;
                      }

                      final selected = selectedModifiers[groupId] ?? [];

                      final options = group['options'] as List? ?? [];

                      for (final option in options) {
                        final optionMap = Map<String, dynamic>.from(option);

                        final optionId = _toInt(
                          optionMap['modifier_option_id'],
                        );

                        if (optionId == null || !selected.contains(optionId)) {
                          continue;
                        }

                        modifiers.add(
                          _CaptainCartModifier(
                            groupId: groupId,
                            optionId: optionId,
                            groupName: group['group_name']?.toString() ?? '',
                            optionName:
                                optionMap['option_name']?.toString() ?? '',
                            extraRate: _toDouble(optionMap['extra_rate']),
                          ),
                        );
                      }
                    }

                    String? variantName;

                    for (final variant in variants) {
                      if (_toInt(variant['variant_id']) == selectedVariantId) {
                        variantName = variant['variant_name']?.toString();
                        break;
                      }
                    }

                    Navigator.pop(
                      dialogContext,
                      _CaptainItemSelection(
                        menuItemId: _toInt(item['menu_item_id']) ?? 0,
                        itemName: item['item_name']?.toString() ?? 'Item',
                        variantId: selectedVariantId,
                        variantName: variantName,
                        modifiers: modifiers,
                        rate: finalRate,
                      ),
                    );
                  },
                  child: const Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    _addSelectionToCart(result);
  }

  List<Map<String, dynamic>> get _displayItems {
    final query = _searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return _items;
    }

    final words = query
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return _items.where((item) {
      final name = item['item_name']?.toString().toLowerCase() ?? '';

      final itemWords = name
          .split(RegExp(r'[\s\-_/,()]+'))
          .where((word) => word.isNotEmpty)
          .toList();

      return words.every(
        (queryWord) =>
            itemWords.any((itemWord) => itemWord.contains(queryWord)),
      );
    }).toList();
  }

  Future<void> _addItem(Map<String, dynamic> item) async {
    final itemId = _toInt(item['menu_item_id']);

    if (itemId == null) {
      return;
    }

    try {
      final details = await _menuService.getItemDetails(
        outletId: _outletId,
        itemId: itemId,
      );

      if (!mounted) {
        return;
      }

      await _showItemSelectionDialog(details);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load item: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  void _increaseCartItem(int index) {
    setState(() {
      _cart[index].quantity++;
    });
  }

  void _decreaseCartItem(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  double get _cartTotal {
    return _cart.fold(0, (sum, item) => sum + (item.rate * item.quantity));
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Order Cart',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('No items added'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final item = _cart[index];

                            return Card(
                              child: ListTile(
                                title: Text(
                                  item.variantName == null ||
                                          item.variantName!.isEmpty
                                      ? item.itemName
                                      : '${item.itemName} • ${item.variantName}',
                                ),
                                subtitle: item.modifiers.isEmpty
                                    ? Text('₹${item.rate.toStringAsFixed(2)}')
                                    : Text(
                                        '${item.modifiers.map((m) => m.optionName).join(', ')}\n'
                                        '₹${item.rate.toStringAsFixed(2)}',
                                      ),
                                leading: Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _decreaseCartItem(index);
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _increaseCartItem(index);
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, -2),
                        color: Colors.black12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_cartTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get _outletId => widget.outletId;

  Widget _buildBillRequestSection() {
    if (_existingOrder == null || _currentOrderId == null) {
      return const SizedBox.shrink();
    }

    final order = _existingOrder!;

    final billRequested =
        order['bill_requested'] == true ||
        order['bill_requested'] == 1 ||
        order['bill_requested']?.toString() == '1';

    final status = order['order_status']?.toString().toUpperCase() ?? 'OPEN';

    final total = _toDouble(order['grand_total']);

    // Bill already requested.
    if (billRequested) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.orange.withValues(alpha: 0.10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BILL REQUESTED',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Amount: ₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Do not request bill for closed orders.
    const blockedStatuses = ['BILLED', 'PAID', 'CANCELLED', 'VOID', 'MERGED'];

    if (blockedStatuses.contains(status)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Grand Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: _requestingBill ? null : _requestBill,
            icon: _requestingBill
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(_requestingBill ? 'REQUESTING...' : 'REQUEST BILL'),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingOrderSection() {
    if (_currentOrderId == null) {
      return const SizedBox.shrink();
    }

    if (_loadingExistingOrder) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_existingOrder == null) {
      return const SizedBox.shrink();
    }

    final order = _existingOrder!;

    final items = order['items'] is List
        ? (order['items'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final orderStatus = order['order_status']?.toString() ?? 'OPEN';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ORDER #$_currentOrderId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text(orderStatus.replaceAll('_', ' '))),
              ],
            ),

            const Divider(),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No items'),
              )
            else ...[
              const Text(
                'EXISTING ITEMS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 4),

              ...items.map((item) => _buildExistingOrderItem(item)),
              _buildBillRequestSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingOrderItem(Map<String, dynamic> item) {
    final itemName =
        item['item_name']?.toString() ??
        item['menu_item_name']?.toString() ??
        'Item';

    final variantName = item['variant_name']?.toString();

    final qty = item['qty']?.toString() ?? '0';

    final status = item['status']?.toString() ?? 'OPEN';

    final modifiers = item['modifiers'] is List
        ? (item['modifiers'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              qty,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),

                if (variantName != null && variantName.isNotEmpty)
                  Text(
                    variantName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                if (modifiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      modifiers
                          .map(
                            (m) =>
                                m['option_name']?.toString() ??
                                m['modifier_option_name']?.toString() ??
                                '',
                          )
                          .where((e) => e.isNotEmpty)
                          .join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _buildItemStatusChip(status),
        ],
      ),
    );
  }

  Widget _buildItemStatusChip(String status) {
    final normalizedStatus = status.toUpperCase();

    Color statusColor;

    switch (normalizedStatus) {
      case 'OPEN':
        statusColor = Colors.orange;
        break;

      case 'SENT_TO_KITCHEN':
        statusColor = Colors.deepOrange;
        break;

      case 'ACCEPTED':
        statusColor = Colors.blue;
        break;

      case 'PREPARING':
        statusColor = Colors.indigo;
        break;

      case 'READY':
        statusColor = Colors.green;
        break;

      case 'SERVED':
        statusColor = Colors.teal;
        break;

      case 'CANCELLED':
        statusColor = Colors.red;
        break;

      default:
        statusColor = Colors.grey;
    }

    String displayStatus;

    switch (normalizedStatus) {
      case 'SENT_TO_KITCHEN':
        displayStatus = 'KITCHEN';
        break;

      default:
        displayStatus = normalizedStatus.replaceAll('_', ' ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          ChoiceChip(
            label: const Text('ALL'),
            selected: _selectedCategoryId == null,
            onSelected: (_) {
              _onCategorySelected(null);
            },
          ),

          ..._categories.map((category) {
            final id = _toInt(category['menu_category_id']);

            final selected = id == _selectedCategoryId;

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(
                  category['category_name']?.toString() ?? 'Category',
                ),
                selected: selected,
                onSelected: (_) {
                  if (id != null) {
                    _onCategorySelected(id);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_displayItems.isEmpty) {
      return const Center(child: Text('No menu items found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisExtent: 125,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _displayItems.length,
      itemBuilder: (context, index) {
        final item = _displayItems[index];

        final name = item['item_name']?.toString() ?? 'Item';

        final rate = _toDouble(item['base_rate']);

        final isVeg = item['is_veg'] == true || item['is_veg'] == 1;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await _addItem(item);
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isVeg)
                        const Icon(Icons.circle, size: 10, color: Colors.green),

                      if (isVeg) const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    '₹${rate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Tap to add',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.orderId == null
        ? 'New Order'
        : 'Order #${widget.orderId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.table.tableName}'
          ' • '
          '$title',
        ),
        actions: [
          IconButton(
            onPressed: _showCart,
            icon: Badge(
              label: Text(
                _cart.fold(0, (sum, item) => sum + item.quantity).toString(),
              ),
              child: const Icon(Icons.shopping_cart),
            ),
          ),
        ],
      ),

      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // -------------------------
                // Search
                // -------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search menu',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchText.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _searchText = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                _buildExistingOrderSection(),

                if (_currentOrderId != null && _cart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'NEW ITEMS (${_cart.fold(0, (sum, item) => sum + item.quantity)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                // -------------------------
                // Categories
                // -------------------------
                _buildCategorySection(),

                const Divider(height: 1),

                // -------------------------
                // Menu
                // -------------------------
                Expanded(child: _buildItemsSection()),
              ],
            ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                offset: Offset(0, -2),
                color: Colors.black12,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cart.isEmpty || _savingOrder ? null : _saveOrder,
                  icon: const Icon(Icons.save),
                  label: const Text('SAVE ORDER'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (_cart.isEmpty && _currentOrderId == null) || _savingOrder
                      ? null
                      : _sendToKitchen,
                  icon: _savingOrder
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restaurant),
                  label: const Text('SEND TO KITCHEN'),
                ),
              ),

              const SizedBox(width: 10),

              IconButton(
                onPressed: _cart.isEmpty ? null : _showCart,
                icon: Badge(
                  label: Text(
                    _cart
                        .fold(0, (sum, item) => sum + item.quantity)
                        .toString(),
                  ),
                  child: const Icon(Icons.shopping_cart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptainCartItem {
  final int menuItemId;
  final String itemName;

  final int? variantId;
  final String? variantName;

  final List<_CaptainCartModifier> modifiers;

  final double rate;

  int quantity;

  _CaptainCartItem({
    required this.menuItemId,
    required this.itemName,
    required this.rate,
    required this.quantity,
    this.variantId,
    this.variantName,
    this.modifiers = const [],
  });

  bool isSameConfiguration(
    int menuItemId,
    int? variantId,
    List<_CaptainCartModifier> modifiers,
  ) {
    if (this.menuItemId != menuItemId) {
      return false;
    }

    if (this.variantId != variantId) {
      return false;
    }

    if (this.modifiers.length != modifiers.length) {
      return false;
    }

    for (final modifier in modifiers) {
      final exists = this.modifiers.any(
        (existing) =>
            existing.groupId == modifier.groupId &&
            existing.optionId == modifier.optionId,
      );

      if (!exists) {
        return false;
      }
    }

    return true;
  }
}

class _CaptainCartModifier {
  final int groupId;
  final int optionId;
  final String groupName;
  final String optionName;
  final double extraRate;

  _CaptainCartModifier({
    required this.groupId,
    required this.optionId,
    required this.groupName,
    required this.optionName,
    required this.extraRate,
  });
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

class _CaptainItemSelection {
  final int menuItemId;
  final String itemName;

  final int? variantId;
  final String? variantName;

  final List<_CaptainCartModifier> modifiers;

  final double rate;

  _CaptainItemSelection({
    required this.menuItemId,
    required this.itemName,
    required this.rate,
    this.variantId,
    this.variantName,
    this.modifiers = const [],
  });
}
