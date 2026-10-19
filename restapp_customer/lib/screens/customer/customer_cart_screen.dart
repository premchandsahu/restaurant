import 'package:flutter/material.dart';
import 'package:restapp_customer/models/customer/customer_cart.dart';
import 'package:restapp_customer/services/customer/customer_order_service.dart';

//import '../../models/pos/customer_cart.dart';
import 'customer_order_status_screen.dart';
//import '../../services/pos/customer_order_service.dart';

class CustomerCartScreen extends StatefulWidget {
  final CustomerCart cart;
  final String customerSessionToken;
  final String baseUrl;
  final int? existingOrderId;
  const CustomerCartScreen({
    super.key,
    required this.cart,
    required this.customerSessionToken,
    required this.baseUrl,
    this.existingOrderId,
  });

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  CustomerCart get cart => widget.cart;
  bool _placingOrder = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Order')),
      body: cart.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      return _buildCartItem(index);
                    },
                  ),
                ),

                _buildSummary(),
              ],
            ),
    );
  }

  // ----------------------------------------------------------
  // Empty cart
  // ----------------------------------------------------------

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious items from the menu.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('BACK TO MENU'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Cart item
  // ----------------------------------------------------------

  Widget _buildCartItem(int index) {
    final item = cart.items[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Remove',
                  onPressed: () {
                    setState(() {
                      cart.removeItem(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),

            // Modifiers
            if (item.modifierText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  item.modifierText,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),

            const SizedBox(height: 8),

            // Rate and quantity
            Row(
              children: [
                Text(
                  '₹${item.unitRate.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const Spacer(),

                _buildQuantityButton(
                  icon: Icons.remove,
                  onPressed: () {
                    setState(() {
                      cart.decreaseQuantity(index);
                    });
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _buildQuantityButton(
                  icon: Icons.add,
                  onPressed: () {
                    setState(() {
                      cart.increaseQuantity(index);
                    });
                  },
                ),

                const SizedBox(width: 16),

                Text(
                  '₹${item.lineAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Special instruction
            if (item.specialInstruction.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Note: ${item.specialInstruction}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Quantity button
  // ----------------------------------------------------------

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Icon(icon, size: 18),
      ),
    );
  }

  // ----------------------------------------------------------
  // Summary
  // ----------------------------------------------------------

  Widget _buildSummary() {
    return SafeArea(
      child: Container(
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
        child: Column(
          children: [
            Row(
              children: [
                const Text('Items'),
                const Spacer(),
                Text('${cart.totalItems}'),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '₹${cart.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _placingOrder ? null : _placeOrder,
                child: _placingOrder
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.existingOrderId != null
                            ? 'ADD TO ORDER'
                            : 'PLACE ORDER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Place order
  // ----------------------------------------------------------
  /*
  Future<void> _placeOrder() async {
    if (_placingOrder) {
      return;
    }

    if (cart.isEmpty) {
      return;
    }

    setState(() {
      _placingOrder = true;
    });

    try {
      final service = CustomerOrderService(baseUrl: widget.baseUrl, token: '');

      final result = await service.placeCustomerOrder(
        customerSessionToken: widget.customerSessionToken,
        cart: cart,
        guestCount: 1,
      );

      if (!mounted) return;

      final orderId = result['orderId'];

      cart.clear();

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Order Placed'),
            content: Text(
              orderId != null
                  ? 'Your order #$orderId has been placed successfully.'
                  : 'Your order has been placed successfully.',
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerOrderStatusScreen(
            customerSessionToken: widget.customerSessionToken,
            baseUrl: widget.baseUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }
*/
  Future<void> _placeOrder() async {
    if (_placingOrder) {
      return;
    }

    if (cart.isEmpty) {
      return;
    }

    setState(() {
      _placingOrder = true;
    });

    try {
      final service = CustomerOrderService(baseUrl: widget.baseUrl, token: '');

      Map<String, dynamic> result;

      if (widget.existingOrderId != null) {
        result = await service.addItemsToCustomerOrder(
          customerSessionToken: widget.customerSessionToken,
          orderId: widget.existingOrderId!,
          cart: cart,
        );
      } else {
        result = await service.placeCustomerOrder(
          customerSessionToken: widget.customerSessionToken,
          cart: cart,
          guestCount: 1,
        );
      }

      if (!mounted) return;

      final orderId = result['orderId'] ?? widget.existingOrderId;

      cart.clear();

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              widget.existingOrderId != null ? 'Items Added' : 'Order Placed',
            ),
            content: Text(
              widget.existingOrderId != null
                  ? 'Items have been added to Order #$orderId successfully.'
                  : 'Your order #$orderId has been placed successfully.',
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerOrderStatusScreen(
            customerSessionToken: widget.customerSessionToken,
            baseUrl: widget.baseUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }
}
