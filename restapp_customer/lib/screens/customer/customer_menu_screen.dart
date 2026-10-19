import 'package:restapp_customer/models/customer/customer_cart.dart';
import 'package:restapp_customer/models/customer/customer_menu.dart';
import 'package:restapp_customer/screens/customer/customer_cart_screen.dart';
import 'package:restapp_customer/services/customer/customer_order_service.dart';

//import '../../models/pos/customer_cart.dart';
import 'package:flutter/material.dart';
//import 'package:restapp/screens/pos/customer_cart_screen.dart';
//import '../../models/pos/customer_menu.dart';
//import '../../services/pos/customer_order_service.dart';

class CustomerMenuScreen extends StatefulWidget {
  final String customerSessionToken;
  final String baseUrl;
  final int? existingOrderId;
  const CustomerMenuScreen({
    super.key,
    required this.customerSessionToken,
    required this.baseUrl,
    this.existingOrderId,
  });

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  late final CustomerOrderService _service;

  CustomerMenu? _customerMenu;

  bool _loading = true;
  String? _error;

  int _selectedCategoryIndex = 0;
  final TextEditingController _menuSearchController = TextEditingController();

  String _menuSearchText = '';
  // Temporary cart.
  // We will replace this with a proper cart model in the next step.
  final CustomerCart _cart = CustomerCart();
  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _service = CustomerOrderService(baseUrl: widget.baseUrl, token: '');

    _loadMenu();
  }

  bool matchesCustomerMenuSearch(String itemName, String searchText) {
    final queryWords = searchText
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) {
      return true;
    }

    final itemWords = itemName
        .toLowerCase()
        .split(RegExp(r'[\s\-_/,()]+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return queryWords.every(
      (queryWord) => itemWords.any((itemWord) => itemWord.contains(queryWord)),
    );
  }
  // ----------------------------------------------------------
  // Load menu
  // ----------------------------------------------------------

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getCustomerMenu(
        customerSessionToken: widget.customerSessionToken,
      );

      if (!mounted) return;

      setState(() {
        _customerMenu = result;
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

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _openCart,
                icon: const Icon(Icons.shopping_cart_outlined),
              ),

              if (!_cart.isEmpty)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_cart.totalItems}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_customerMenu == null) {
      return const Center(child: Text('Menu unavailable'));
    }

    return _buildMenu();
  }

  // ----------------------------------------------------------
  // Error
  // ----------------------------------------------------------

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMenu,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Menu
  // ----------------------------------------------------------
  /*
  Widget _buildMenuSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _menuSearchController,
        onChanged: (value) {
          setState(() {
            _menuSearchText = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search menu...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _menuSearchText.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _menuSearchController.clear();

                    setState(() {
                      _menuSearchText = '';
                    });
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

*/
  Widget _buildMenuSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _menuSearchController,
        onChanged: (value) {
          setState(() {
            _menuSearchText = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search menu...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _menuSearchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _menuSearchController.clear();

                    setState(() {
                      _menuSearchText = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  /*
  Widget _buildMenu() {
    final categories = _customerMenu!.menu;

    if (categories.isEmpty) {
      return const Center(child: Text('No menu items available'));
    }

    final safeIndex = _selectedCategoryIndex < categories.length
        ? _selectedCategoryIndex
        : 0;

    final selectedCategory = categories[safeIndex];

    final filteredItems = selectedCategory.items
        .where(
          (item) =>
              matchesCustomerMenuSearch(item.itemName ?? '', _menuSearchText),
        )
        .toList();

    return Column(
      children: [
        _buildCustomerHeader(),

        _buildCategoryBar(categories),

        _buildMenuSearch(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMenu,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMenuItemCard(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
*/
  Widget _buildMenu() {
    final categories = _customerMenu!.menu;

    if (categories.isEmpty) {
      return const Center(child: Text('No menu items available'));
    }

    final safeIndex = _selectedCategoryIndex <= categories.length
        ? _selectedCategoryIndex
        : 0;

    final bool isAllCategory = safeIndex == 0;

    final List<MenuItem> selectedCategoryItems = isAllCategory
        ? categories.expand((category) => category.items).toList()
        : categories[safeIndex - 1].items;

    // When search is active, search across ALL categories.
    // Otherwise, show only the selected category.
    final List<MenuItem> displayItems;

    if (_menuSearchText.trim().isNotEmpty) {
      displayItems = categories
          .expand((category) => category.items)
          .where(
            (item) =>
                matchesCustomerMenuSearch(item.itemName ?? '', _menuSearchText),
          )
          .toList();
    } else {
      displayItems = selectedCategoryItems;
    }
    return Column(
      children: [
        _buildCustomerHeader(),

        _buildCategoryBar(categories),

        _buildMenuSearch(),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMenu,
            child: displayItems.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'No matching items found',
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final item = displayItems[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildMenuItemCard(item),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
  // ----------------------------------------------------------
  // Customer header
  // ----------------------------------------------------------

  Widget _buildCustomerHeader() {
    final menu = _customerMenu!;

    final customerName = menu.customerSession.customerName ?? 'Customer';

    final tableCode =
        menu.table.tableCode ?? 'Table ${menu.table.tableId ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.restaurant),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $customerName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tableCode,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Category bar
  // ----------------------------------------------------------
  Widget _buildCategoryBar(List<MenuCategory> categories) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          // --------------------------------------------------
          // ALL category
          // --------------------------------------------------
          if (index == 0) {
            final selected = _selectedCategoryIndex == 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: const Text('ALL'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryIndex = 0;
                  });
                },
              ),
            );
          }

          // --------------------------------------------------
          // Normal category
          // --------------------------------------------------
          final category = categories[index - 1];

          final selected = index == _selectedCategoryIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category.categoryName ?? 'Category'),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
            ),
          );
        },
      ),
    );
  }
  // ----------------------------------------------------------
  // Menu item card
  // ----------------------------------------------------------

  Widget _buildMenuItemCard(MenuItem item) {
    final hasOptions = item.hasVariants || item.hasModifiers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFoodIcon(item),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName ?? 'Item',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      if (item.isSpicy)
                        const Text('🌶', style: TextStyle(fontSize: 14)),
                    ],
                  ),

                  if (item.description != null && item.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        '₹${item.baseRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),

                      if (hasOptions) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Options available',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const Spacer(),

                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _addItem(item),
                          child: const Text('ADD'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Food indicator
  // ----------------------------------------------------------

  Widget _buildFoodIcon(MenuItem item) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.isVeg ? Colors.green : Colors.red),
      ),
      child: Icon(
        Icons.circle,
        size: 12,
        color: item.isVeg ? Colors.green : Colors.red,
      ),
    );
  }

  // ----------------------------------------------------------
  // Add item
  // ----------------------------------------------------------

  Future<void> _addItem(MenuItem item) async {
    if (item.hasVariants || item.hasModifiers) {
      await _showItemOptions(item);
      return;
    }

    setState(() {
      _cart.addItem(
        menuItem: item,
        variant: null,
        modifiers: const [],
        quantity: 1,
      );
    });

    _showAddedMessage(item);
  }

  // ----------------------------------------------------------
  // Options dialog
  // ----------------------------------------------------------

  Future<void> _showItemOptions(MenuItem item) async {
    MenuVariant? selectedVariant;

    final defaultVariants = item.variants.where((v) => v.isDefault);

    if (defaultVariants.isNotEmpty) {
      selectedVariant = defaultVariants.first;
    }

    final Map<int, Set<int>> selectedModifiers = {};

    for (final group in item.modifierGroups) {
      selectedModifiers[group.modifierGroupId] = {};
    }

    final result = await showModalBottomSheet<CustomerItemSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildOptionsSheet(
              item: item,
              selectedVariant: selectedVariant,
              selectedModifiers: selectedModifiers,
              onVariantChanged: (variant) {
                setDialogState(() {
                  selectedVariant = variant;
                });
              },
              onModifierChanged: (group, option) {
                setDialogState(() {
                  final selected = selectedModifiers[group.modifierGroupId]!;

                  if (group.isSingle) {
                    selected.clear();
                    selected.add(option.modifierOptionId);
                  } else {
                    if (selected.contains(option.modifierOptionId)) {
                      selected.remove(option.modifierOptionId);
                    } else {
                      if (selected.length < group.maxSelection) {
                        selected.add(option.modifierOptionId);
                      }
                    }
                  }
                });
              },
              onAdd: () {
                final validation = _validateSelections(
                  item,
                  selectedVariant,
                  selectedModifiers,
                );

                if (validation != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(validation)));
                  return;
                }

                final selectedOptions = <ModifierOption>[];

                for (final group in item.modifierGroups) {
                  for (final option in group.options) {
                    if (selectedModifiers[group.modifierGroupId]!.contains(
                      option.modifierOptionId,
                    )) {
                      selectedOptions.add(option);
                    }
                  }
                }

                Navigator.pop(
                  context,
                  CustomerItemSelection(
                    variant: selectedVariant,
                    modifiers: selectedOptions,
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      _cart.addItem(
        menuItem: item,
        variant: result.variant,
        modifiers: result.modifiers,
        quantity: 1,
      );
    });

    _showAddedMessage(item);
  }

  // ----------------------------------------------------------
  // Options sheet
  // ----------------------------------------------------------

  Widget _buildOptionsSheet({
    required MenuItem item,
    required MenuVariant? selectedVariant,
    required Map<int, Set<int>> selectedModifiers,
    required ValueChanged<MenuVariant?> onVariantChanged,
    required void Function(ModifierGroup, ModifierOption) onModifierChanged,
    required VoidCallback onAdd,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName ?? 'Item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              if (item.variants.isNotEmpty)
                _buildVariantSelection(item, selectedVariant, onVariantChanged),

              ...item.modifierGroups.map(
                (group) => _buildModifierGroup(
                  group,
                  selectedModifiers[group.modifierGroupId]!,
                  onModifierChanged,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAdd,
                  child: const Text('ADD TO CART'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Variant selection
  // ----------------------------------------------------------

  Widget _buildVariantSelection(
    MenuItem item,
    MenuVariant? selectedVariant,
    ValueChanged<MenuVariant?> onVariantChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Variant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        const SizedBox(height: 8),

        ...item.variants.map(
          (variant) => RadioListTile<MenuVariant>(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${variant.variantName} '
              '₹${variant.rate.toStringAsFixed(2)}',
            ),
            value: variant,
            groupValue: selectedVariant,
            onChanged: onVariantChanged,
          ),
        ),

        const Divider(),
      ],
    );
  }

  // ----------------------------------------------------------
  // Modifier group
  // ----------------------------------------------------------

  Widget _buildModifierGroup(
    ModifierGroup group,
    Set<int> selected,
    void Function(ModifierGroup, ModifierOption) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Text(
          group.isRequired
              ? '${group.groupName} *'
              : group.groupName ?? 'Options',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        if (group.maxSelection > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              group.isSingle
                  ? 'Select one'
                  : 'Select up to ${group.maxSelection}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),

        ...group.options.map((option) {
          final checked = selected.contains(option.modifierOptionId);

          return InkWell(
            onTap: () => onChanged(group, option),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    group.isSingle
                        ? (checked
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked)
                        : (checked
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                  ),

                  const SizedBox(width: 8),

                  Expanded(child: Text(option.optionName ?? 'Option')),

                  Text(
                    option.extraRate == 0
                        ? ''
                        : '+₹${option.extraRate.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          );
        }),

        const Divider(),
      ],
    );
  }

  // ----------------------------------------------------------
  // Validate selections
  // ----------------------------------------------------------

  String? _validateSelections(
    MenuItem item,
    MenuVariant? selectedVariant,
    Map<int, Set<int>> selectedModifiers,
  ) {
    if (item.variants.isNotEmpty && selectedVariant == null) {
      return 'Please select a variant';
    }

    for (final group in item.modifierGroups) {
      final count = selectedModifiers[group.modifierGroupId]!.length;

      if (count < group.minSelection) {
        return 'Please select ${group.minSelection} '
            'option(s) from ${group.groupName}';
      }

      if (group.maxSelection > 0 && count > group.maxSelection) {
        return 'Maximum ${group.maxSelection} '
            'option(s) allowed in ${group.groupName}';
      }
    }

    return null;
  }

  // ----------------------------------------------------------
  // Added message
  // ----------------------------------------------------------

  void _showAddedMessage(MenuItem item) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.itemName ?? 'Item'} added to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  // ----------------------------------------------------------
  // Cart
  // ----------------------------------------------------------

  void _openCart() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCartScreen(
          cart: _cart,
          customerSessionToken: widget.customerSessionToken,
          baseUrl: widget.baseUrl,
          existingOrderId: widget.existingOrderId,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }
}

bool matchesCustomerMenuSearch(String itemName, String searchText) {
  final queryWords = searchText
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (queryWords.isEmpty) {
    return true;
  }

  final itemWords = itemName
      .toLowerCase()
      .split(RegExp(r'[\s\-_/,()]+'))
      .where((word) => word.isNotEmpty)
      .toList();

  return queryWords.every(
    (queryWord) => itemWords.any((itemWord) => itemWord.contains(queryWord)),
  );
}

// ==========================================================
// Temporary cart classes
// ==========================================================

class CustomerItemSelection {
  final MenuVariant? variant;
  final List<ModifierOption> modifiers;

  CustomerItemSelection({this.variant, this.modifiers = const []});
}
