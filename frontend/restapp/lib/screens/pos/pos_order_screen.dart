import 'package:flutter/material.dart';
import 'package:restapp/models/pos/pos_order.dart';
import 'package:restapp/models/pos/pos_tax.dart';
import 'package:restapp/models/pos/pos_tax_service.dart';
import 'package:restapp/models/pos/pos_variant.dart';
import 'package:restapp/screens/pos/bill_payment_screen.dart';
import 'package:restapp/services/pos/pos_order_service.dart';
import 'package:restapp/widgets/pos/pos_item_selection_dialog.dart';
import 'package:restapp/screens/pos/pos_bill_screen.dart';
import '../../models/pos/pos_category.dart';
import '../../models/pos/pos_menu_item.dart';
import '../../services/pos/pos_menu_service.dart';
import '../../widgets/pos/pos_category_panel.dart';
import '../../widgets/pos/pos_menu_panel.dart';
import '../../models/pos/pos_cart_item.dart';
import '../../widgets/pos/pos_cart_panel.dart';
import 'package:restapp/screens/pos/pos_bill_preview_screen.dart';

class PosOrderScreen extends StatefulWidget {
  final int outletId;
  final int tableId;
  final int? orderId;

  final String baseUrl;
  final String token;

  const PosOrderScreen({
    super.key,
    required this.outletId,
    required this.tableId,
    this.orderId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  late final PosMenuService _menuService;
  late final PosTaxService _taxService;
  late final PosOrderService _orderService;

  bool _creatingBill = false;
  int? _orderId;
  String _orderType = 'DINE_IN';
  final TextEditingController _menuSearchController = TextEditingController();
  bool get _isOrderBilled => _orderStatus == 'BILLED';
  String _menuSearchText = '';
  int _guestCount = 1;
  String? _logicalTableCode;
  String? _logicalTableName;
  String? _orderStatus;
  bool _savingOrder = false;
  List<PosTaxGroup> _taxGroups = [];
  List<PosCategory> _categories = [];
  List<PosMenuItem> _menuItems = [];
  final List<PosCartItem> _cartItems = [];
  int? _selectedCategoryId;

  bool _loadingCategories = true;
  bool _loadingItems = false;

  String? _errorMessage;

  bool get _hasUnsavedItemChanges {
    return _cartItems.any((item) => item.unsavedQuantity > 0);
  }

  bool get _hasItemsPendingKOT {
    return _cartItems.any((item) => item.quantity > item.sentQuantity);
  }

  bool matchesMenuSearch(String itemName, String searchText) {
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

  PosTaxGroup? _findTaxGroup(int? taxGroupId) {
    if (taxGroupId == null) {
      return null;
    }

    for (final group in _taxGroups) {
      if (group.taxGroupId == taxGroupId) {
        return group;
      }
    }

    return null;
  }

  Future<void> _createBill() async {
    if (_creatingBill) return;

    if (_orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the order before billing')),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // --------------------------------------------------
    // Save any items that have not yet been saved.
    // --------------------------------------------------

    if (_cartItems.any((item) => item.unsavedQuantity > 0)) {
      final saved = await _saveOrder(showMessage: false);

      if (!saved || _orderId == null) {
        return;
      }
    }

    setState(() {
      _creatingBill = true;
    });

    try {
      // --------------------------------------------------
      // Get the latest server-calculated order.
      // No bill is created here.
      // --------------------------------------------------

      final order = await _orderService.getOrder(_orderId!);

      if (!mounted) return;

      // --------------------------------------------------
      // Show itemised bill preview.
      // --------------------------------------------------

      final createBill = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PosBillPreviewScreen(
            order: order,
            items: List<PosCartItem>.from(_cartItems),
            logicalTableCode: _logicalTableCode,
            logicalTableName: _logicalTableName,
          ),
        ),
      );

      if (!mounted) return;

      // User selected EDIT ORDER / CANCEL.
      if (createBill != true) {
        return;
      }

      // --------------------------------------------------
      // NOW create the actual bill.
      // --------------------------------------------------

      final bill = await _orderService.createBill(orderId: _orderId!);

      if (!mounted) return;

      final billNo = bill.billNo ?? bill.billId.toString();

      // --------------------------------------------------
      // Bill Generated dialog
      // --------------------------------------------------
      // --------------------------------------------------
      // Bill Generated dialog
      // --------------------------------------------------

      final viewBill = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Bill Generated'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill No: $billNo',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Amount: ₹'
                  '${bill.grandTotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                const Text('Bill has been created successfully.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('CLOSE'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('VIEW BILL'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------
      // Open bill screen only after the dialog is closed.
      // Navigation is now performed using the OrderScreen
      // context, not the dialog context.
      // --------------------------------------------------

      if (viewBill == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PosBillScreen(
              billId: bill.billId,
              baseUrl: widget.baseUrl,
              token: widget.token,
            ),
          ),
        );

        if (!mounted) {
          return;
        }
      }

      // --------------------------------------------------
      // Return to table screen.
      // --------------------------------------------------

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create bill: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _creatingBill = false;
        });
      }
    }
  }

  Future<void> _initScreen() async {
    await _loadTaxGroups();

    if (widget.orderId != null) {
      await _loadExistingOrder();
    }

    await _loadCategories();
  }

  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _menuService = PosMenuService(baseUrl: widget.baseUrl, token: widget.token);
    _taxService = PosTaxService(baseUrl: widget.baseUrl, token: widget.token);
    _orderService = PosOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _initScreen();

    debugPrint(
      'POS ORDER SCREEN: '
      'tableId=${widget.tableId}, '
      'orderId=${widget.orderId}',
    );
  }

  /*Future<void> _createBill() async {
    if (_creatingBill) return;

    if (_orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the order before creating the bill'),
        ),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // Save any unsaved items first.
    if (_cartItems.any((item) => item.unsavedQuantity > 0)) {
      final saved = await _saveOrder();

      if (!saved) {
        return;
      }
    }

    setState(() {
      _creatingBill = true;
    });

    try {
      final bill = await _orderService.createBill(orderId: _orderId!);

      if (!mounted) return;

      final billNo = bill.billNo ?? bill.billId.toString();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Bill Generated'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill No: $billNo',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Amount: ₹${bill.grandTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                const Text('Payment can be received later from Pending Bills.'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // Return to the previous POS/table screen.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create bill: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _creatingBill = false;
        });
      }
    }
  }
*/
  Future<bool> _saveOrder({bool showMessage = true}) async {
    if (_isOrderBilled) {
      return false;
    }
    if (!_hasUnsavedItemChanges) {
      return false;
    }

    if (_savingOrder || _cartItems.isEmpty) {
      return false;
    }

    setState(() {
      _savingOrder = true;
    });

    try {
      PosOrder order;

      // ----------------------------------------------
      // Create / update order header
      // ----------------------------------------------

      if (_orderId == null) {
        order = await _orderService.createOrder(
          outletId: widget.outletId,
          orderType: _orderType,
          tableId: widget.tableId,
          guestCount: _guestCount,
        );
      } else {
        order = await _orderService.updateOrder(
          orderId: _orderId!,
          orderType: _orderType,
          tableId: widget.tableId,
          guestCount: _guestCount,
        );
      }

      _orderId = order.orderId;
      _orderStatus = order.orderStatus;

      // ----------------------------------------------
      // Save only items not yet saved
      // ----------------------------------------------

      final unsavedItems = _cartItems
          .where((item) => item.unsavedQuantity > 0)
          .toList();

      for (final cartItem in unsavedItems) {
        final qty = cartItem.unsavedQuantity;

        final savedOrder = await _orderService.addItem(
          orderId: _orderId!,
          menuItemId: cartItem.menuItem.menuItemId,
          variantId: cartItem.variant?.variantId,
          qty: qty,
          specialInstruction: cartItem.specialInstruction,
          modifiers: _buildModifierPayload(cartItem),
        );

        _orderId = savedOrder.orderId;
        _orderStatus = savedOrder.orderStatus;

        // The item is now stored in the database.
        cartItem.savedQuantity += qty;
      }

      if (mounted) {
        setState(() {});
      }

      debugPrint('ORDER SAVED: $_orderId STATUS: $_orderStatus');

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved successfully')),
        );
      }

      return true;
    } catch (e) {
      debugPrint('SAVE ORDER ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save order: $e')));
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingOrder = false;
        });
      }
    }
  }

  Future<void> _loadExistingOrder() async {
    debugPrint('LOADING EXISTING ORDER: ${widget.orderId}');
    if (widget.orderId == null) {
      return;
    }

    try {
      setState(() {
        _savingOrder = true;
        _errorMessage = null;
      });

      final order = await _orderService.getOrder(widget.orderId!);
      debugPrint(
        'EXISTING ORDER: '
        '${order.orderId}, '
        'items=${order.items.length}',
      );
      if (!mounted) return;
      _orderType = order.orderType;
      _guestCount = order.guestCount ?? 1;

      _logicalTableCode = order.logicalCode;
      _logicalTableName = order.logicalName;
      _orderStatus = order.orderStatus;
      final List<PosCartItem> loadedItems = [];

      for (final orderItem in order.items) {
        // ------------------------------------------
        // Load complete menu item details
        // ------------------------------------------

        final details = await _menuService.getMenuItem(
          menuItemId: orderItem.menuItemId,
          outletId: widget.outletId,
        );

        // ------------------------------------------
        // Find variant
        // ------------------------------------------

        PosVariant? selectedVariant;

        if (orderItem.variantId != null) {
          for (final variant in details.variants) {
            if (variant.variantId == orderItem.variantId) {
              selectedVariant = variant;
              break;
            }
          }
        }

        // ------------------------------------------
        // Find tax group
        // ------------------------------------------

        final taxGroup = _findTaxGroup(details.item.taxGroupId);

        // ------------------------------------------
        // Reconstruct modifiers
        // ------------------------------------------

        final selectedModifiers = <PosSelectedModifier>[];

        for (final orderModifier in orderItem.modifiers) {
          for (final group in details.modifierGroups) {
            if (group.modifierGroupId != orderModifier.modifierGroupId) {
              continue;
            }

            for (final option in group.options) {
              if (option.modifierOptionId == orderModifier.modifierOptionId) {
                selectedModifiers.add(
                  PosSelectedModifier(
                    group: group,
                    option: option,
                    quantity: orderModifier.qty,
                  ),
                );

                break;
              }
            }
          }
        }
        final isSent =
            orderItem.status == 'SENT_TO_KITCHEN' ||
            orderItem.status == 'PREPARING' ||
            orderItem.status == 'READY' ||
            orderItem.status == 'SERVED';
        // ------------------------------------------
        // Create cart item
        // ------------------------------------------

        final cartItem = PosCartItem(
          menuItem: details.item,

          variant: selectedVariant,

          modifiers: selectedModifiers,

          quantity: orderItem.qty,

          rate: orderItem.rate,

          discountAmount: orderItem.discountAmount,

          specialInstruction: orderItem.specialInstruction,

          taxGroup: taxGroup,

          isSentToKitchen: isSent,

          sentQuantity: isSent ? orderItem.qty : 0,
          savedQuantity: orderItem.qty,
        );

        loadedItems.add(cartItem);
      }

      if (!mounted) return;

      setState(() {
        _orderId = order.orderId;

        _cartItems
          ..clear()
          ..addAll(loadedItems);

        _savingOrder = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _savingOrder = false;
        _errorMessage = 'Unable to load order: $e';
      });
    }
  }

  Widget _buildOrderHeader() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Order type
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Type:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(width: 8),

                DropdownButton<String>(
                  value: _orderType,
                  items: const [
                    DropdownMenuItem(value: 'DINE_IN', child: Text('Dine-In')),
                    DropdownMenuItem(
                      value: 'TAKEAWAY',
                      child: Text('Takeaway'),
                    ),
                    DropdownMenuItem(
                      value: 'DELIVERY',
                      child: Text('Delivery'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _orderType = value;
                    });
                  },
                ),
              ],
            ),

            // Table
            if (_orderType == 'DINE_IN')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant, size: 20),

                  const SizedBox(width: 6),

                  Text(
                    _logicalTableCode ?? 'Table ${widget.tableId}',

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            if (_orderId != null && _orderStatus != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 18),

                  const SizedBox(width: 5),

                  Text(
                    _orderStatus!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            // Guest count
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Guests:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                IconButton(
                  onPressed: _guestCount > 1
                      ? () {
                          setState(() {
                            _guestCount--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),

                Text(
                  '$_guestCount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      _guestCount++;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildModifierPayload(PosCartItem cartItem) {
    return cartItem.modifiers.map((modifier) {
      return {
        'modifierGroupId': modifier.group.modifierGroupId,

        'modifierOptionId': modifier.option.modifierOptionId,

        'qty': modifier.quantity,
      };
    }).toList();
  }

  Future<void> _sendToKitchen() async {
    if (_cartItems.isEmpty) {
      return;
    }

    if (_isOrderBilled) {
      return;
    }

    if (!_hasItemsPendingKOT) {
      return;
    }

    // ----------------------------------------------
    // Save order first
    // ----------------------------------------------
    if (_hasUnsavedItemChanges) {
      final saved = await _saveOrder(showMessage: false);

      if (!saved || _orderId == null) {
        return;
      }
    }
    if (_orderId == null) {
      return;
    }

    try {
      // ----------------------------------------------
      // Backend determines which OPEN items
      // need to be sent to kitchen.
      // ----------------------------------------------

      await _orderService.sendKOT(_orderId!);

      // ----------------------------------------------
      // Reload order
      // ----------------------------------------------

      final order = await _orderService.getOrder(_orderId!);

      if (!mounted) {
        return;
      }

      setState(() {
        _orderId = order.orderId;
        _orderStatus = order.orderStatus;

        // Everything currently in cart has now
        // been sent to kitchen.
        for (final item in _cartItems) {
          item.sentQuantity = item.quantity;
          item.isSentToKitchen = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KOT sent to kitchen successfully')),
      );
    } catch (e) {
      debugPrint('SEND KOT ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send KOT: $e')));
    }
  }

  Future<void> _loadTaxGroups() async {
    try {
      final groups = await _taxService.getTaxGroups();

      if (!mounted) return;

      setState(() {
        _taxGroups = groups;
      });
    } catch (e) {
      debugPrint('Unable to load tax groups: $e');
    }
  }

  void _addToCart(PosCartItem cartItem) {
    if (_isOrderBilled) return;

    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (existing) => existing.isSameConfiguration(
          cartItem.menuItem,
          cartItem.variant,
          cartItem.modifiers,
        ),
      );

      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity += cartItem.quantity;
      } else {
        _cartItems.add(cartItem);
      }
    });
  }

  void _incrementCartItem(int index) {
    if (_isOrderBilled) return;

    setState(() {
      _cartItems[index].quantity++;
    });
  }

  void _decrementCartItem(int index) {
    if (_isOrderBilled) return;

    setState(() {
      final item = _cartItems[index];

      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _deleteCartItem(int index) {
    if (_isOrderBilled) return;

    setState(() {
      _cartItems.removeAt(index);
    });
  }

  // --------------------------------------------------
  // Load Categories
  // --------------------------------------------------

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _errorMessage = null;
    });

    try {
      final categories = await _menuService.getCategories(
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _categories = categories;

        // ALL is selected by default
        _selectedCategoryId = null;

        // Category list is ready immediately
        _loadingCategories = false;
      });

      // Load ALL menu items in the background.
      // Do not wait for this before displaying categories.
      if (categories.isNotEmpty) {
        _loadAllMenuItems();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _loadingCategories = false;
      });
    }
  }

  // --------------------------------------------------
  // Load Menu Items
  // --------------------------------------------------

  Future<void> _loadMenuItems(int categoryId) async {
    setState(() {
      _loadingItems = true;
      _errorMessage = null;
    });

    try {
      final items = await _menuService.getMenuItems(
        outletId: widget.outletId,
        categoryId: categoryId,
      );

      if (!mounted) return;

      setState(() {
        _menuItems = items;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();

        _menuItems = [];
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingItems = false;
      });
    }
  }

  Future<void> _loadAllMenuItems() async {
    if (!mounted) return;

    setState(() {
      _loadingItems = true;
      _errorMessage = null;
    });

    try {
      final items = await _menuService.getAllMenuItems(
        outletId: widget.outletId,
      );

      // User may have selected another category
      // while ALL items were loading.
      if (!mounted || _selectedCategoryId != null) {
        return;
      }

      items.sort(
        (a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
      );

      setState(() {
        _menuItems = items;
      });
    } catch (e) {
      if (!mounted || _selectedCategoryId != null) {
        return;
      }

      setState(() {
        _errorMessage = e.toString();
        _menuItems = [];
      });
    } finally {
      if (mounted && _selectedCategoryId == null) {
        setState(() {
          _loadingItems = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // Category Selected
  // --------------------------------------------------

  Future<void> _onCategorySelected(PosCategory category) async {
    if (_selectedCategoryId == category.categoryId) {
      return;
    }

    _menuSearchController.clear();

    setState(() {
      _selectedCategoryId = category.categoryId;
      _menuSearchText = '';
      _menuItems = [];
    });

    await _loadMenuItems(category.categoryId);
  }

  Future<void> _onAllCategoriesSelected() async {
    if (_selectedCategoryId == null) {
      return;
    }

    _menuSearchController.clear();

    setState(() {
      _selectedCategoryId = null;
      _menuSearchText = '';
      _menuItems = [];
    });

    await _loadAllMenuItems();
  }
  // --------------------------------------------------
  // Menu Item Selected
  // --------------------------------------------------

  Future<void> _onMenuItemSelected(PosMenuItem item) async {
    if (_isOrderBilled) {
      return;
    }

    try {
      setState(() {
        _loadingItems = true;
      });

      final details = await _menuService.getMenuItem(
        menuItemId: item.menuItemId,
        outletId: widget.outletId,
      );

      if (!mounted) return;

      await _showItemDetails(details);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load item: $e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingItems = false;
      });
    }
  }

  // --------------------------------------------------
  // Temporary Item Details Dialog
  // --------------------------------------------------

  Future<void> _showItemDetails(PosMenuDetails details) async {
    final cartItem = await showDialog<PosCartItem>(
      context: context,

      builder: (context) {
        return PosItemSelectionDialog(
          details: details,
          taxGroup: _findTaxGroup(details.item.taxGroupId),
        );
      },
    );

    if (cartItem != null) {
      _addToCart(cartItem);
    }
  }

  // --------------------------------------------------
  // Desktop Layout
  // --------------------------------------------------

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 180, child: _buildCategoryPanel()),

        Expanded(child: _buildMenuPanel()),

        SizedBox(
          width: 340,

          child: PosCartPanel(
            items: _cartItems,

            orderType: _orderType,
            tableId: widget.tableId,
            guestCount: _guestCount,

            onOrderTypeChanged: _isOrderBilled
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _orderType = value;
                    });
                  },

            onGuestCountChanged: _isOrderBilled
                ? null
                : (value) {
                    setState(() {
                      _guestCount = value;
                    });
                  },

            onIncrement: _isOrderBilled ? null : _incrementCartItem,

            onDecrement: _isOrderBilled ? null : _decrementCartItem,

            onDelete: _isOrderBilled ? null : _deleteCartItem,

            onSendToKitchen: _sendToKitchen,

            canSendToKitchen: !_isOrderBilled && _hasItemsPendingKOT,

            onSaveOrder: () async {
              await _saveOrder();
            },

            canSaveOrder: !_isOrderBilled && _hasUnsavedItemChanges,

            onCreateBill: _createBill,

            canCreateBill: !_isOrderBilled,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // Category Panel
  // --------------------------------------------------
  /*
  Widget _buildCategoryPanel() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return PosCategoryPanel(
      categories: _categories,

      selectedCategoryId: _selectedCategoryId,

      onCategorySelected: _onCategorySelected,
    );
  }
*/

  Widget _buildCategoryPanel() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------
          // Category heading
          // ---------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // ---------------------------------------------
          // Category list
          // ---------------------------------------------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                // ---------------------------------------
                // ALL
                // ---------------------------------------
                if (index == 0) {
                  final selected = _selectedCategoryId == null;

                  return _buildDesktopCategoryItem(
                    label: 'ALL',
                    selected: selected,
                    colorScheme: colorScheme,
                    onTap: _onAllCategoriesSelected,
                  );
                }

                // ---------------------------------------
                // Normal category
                // ---------------------------------------
                final category = _categories[index - 1];

                final selected = category.categoryId == _selectedCategoryId;

                return _buildDesktopCategoryItem(
                  label: category.categoryName,
                  selected: selected,
                  colorScheme: colorScheme,
                  onTap: () {
                    _onCategorySelected(category);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCategoryItem({
    required String label,
    required bool selected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // -----------------------------------------
                // Selected indicator
                // -----------------------------------------
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 4,
                  height: selected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                SizedBox(width: selected ? 10 : 0),

                // -----------------------------------------
                // Category name
                // -----------------------------------------
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),

                // -----------------------------------------
                // Arrow for selected category
                // -----------------------------------------
                if (selected)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --------------------------------------------------
  // Menu Panel
  // --------------------------------------------------

  Widget _buildMenuPanel() {
    final filteredItems = _menuItems.where((item) {
      return matchesMenuSearch(item.itemName, _menuSearchText);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _menuSearchController,
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
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _menuSearchText = value;
              });
            },
          ),
        ),
        Expanded(
          child: PosMenuPanel(
            items: filteredItems,
            onItemSelected: _onMenuItemSelected,
          ),
        ),
      ],
    );
  }
  /*
  Widget _buildMenuPanel() {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }
    final filteredItems = _menuItems.where((item) {
      return matchesMenuSearch(item.itemName, _menuSearchText);
    }).toList();




    return PosMenuPanel(
      items: filteredItems,
      onItemSelected: _onMenuItemSelected,
    );
  }
*/
  // --------------------------------------------------
  // Temporary Cart
  // --------------------------------------------------

  Widget _buildCartPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),

      child: const Center(
        child: Text(
          'Cart\n\nComing in R6-2C',
          textAlign: TextAlign.center,

          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Mobile Layout
  // --------------------------------------------------

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SizedBox(height: 65, child: _buildMobileCategories()),

        Expanded(child: _buildMenuPanel()),
      ],
    );
  }

  // --------------------------------------------------
  // Mobile Categories
  // --------------------------------------------------
  /*
  Widget _buildMobileCategories() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),

      itemCount: _categories.length,

      itemBuilder: (context, index) {
        final category = _categories[index];

        final selected = category.categoryId == _selectedCategoryId;

        return Padding(
          padding: const EdgeInsets.only(right: 8),

          child: ChoiceChip(
            label: Text(category.categoryName),

            selected: selected,

            onSelected: (_) {
              _onCategorySelected(category);
            },
          ),
        );
      },
    );
  }
*/

  Widget _buildMobileCategories() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      itemCount: _categories.length + 1,
      itemBuilder: (context, index) {
        // -----------------------------------------
        // ALL
        // -----------------------------------------
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('ALL'),
              selected: _selectedCategoryId == null,
              onSelected: (_) {
                _onAllCategoriesSelected();
              },
            ),
          );
        }

        // -----------------------------------------
        // Normal category
        // -----------------------------------------
        final category = _categories[index - 1];

        final selected = category.categoryId == _selectedCategoryId;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(category.categoryName),
            selected: selected,
            onSelected: (_) {
              _onCategorySelected(category);
            },
          ),
        );
      },
    );
  } // --------------------------------------------------
  // Build
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Table ${widget.tableId}'
          '  •  '
          'POS Order',
        ),

        actions: [
          if (widget.orderId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),

              child: Center(
                child: Text(
                  'Order #'
                  '${widget.orderId}',
                ),
              ),
            ),
        ],
      ),

      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text(_errorMessage!, textAlign: TextAlign.center),

                  const SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: _loadCategories,

                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return _buildMobileLayout();
                }

                return _buildDesktopLayout();
              },
            ),
    );
  }
}
