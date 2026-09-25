import 'package:flutter/material.dart';

import '../../models/pos/customer_cart.dart';

class CustomerCartScreen extends StatefulWidget {
  final CustomerCart cart;

  const CustomerCartScreen({super.key, required this.cart});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  CustomerCart get cart => widget.cart;

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
                onPressed: _placeOrder,
                child: const Text(
                  'PLACE ORDER',
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

  void _placeOrder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Place Order will be connected to the API next.'),
      ),
    );
  }
}
