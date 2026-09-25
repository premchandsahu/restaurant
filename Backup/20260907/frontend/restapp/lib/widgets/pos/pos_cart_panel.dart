import 'package:flutter/material.dart';

import '../../models/pos/pos_cart_item.dart';
import 'pos_cart_item_row.dart';

class PosCartPanel extends StatelessWidget {
  final List<PosCartItem> items;

  final VoidCallback? onSendToKitchen;

  final ValueChanged<int>? onIncrement;

  final ValueChanged<int>? onDecrement;

  final ValueChanged<int>? onDelete;

  final String orderType;
  final int? tableId;
  final int guestCount;

  final ValueChanged<String?>? onOrderTypeChanged;
  final ValueChanged<int>? onGuestCountChanged;
  final VoidCallback? onSaveOrder;
  final VoidCallback? onCreateBill;
  final bool canCreateBill;
  const PosCartPanel({
    super.key,
    required this.items,
    this.onSendToKitchen,
    this.onIncrement,
    this.onDecrement,
    this.onDelete,
    required this.orderType,
    this.tableId,
    required this.guestCount,
    this.onOrderTypeChanged,
    this.onGuestCountChanged,
    this.onSaveOrder,
    this.onCreateBill,
    this.canCreateBill = true,
  });

  // --------------------------------------------------
  // Subtotal
  // --------------------------------------------------

  double get subtotal {
    double value = 0;

    for (final item in items) {
      value += item.grossAmount;
    }

    return value;
  }

  // --------------------------------------------------
  // Discount
  // --------------------------------------------------

  double get discount {
    double value = 0;

    for (final item in items) {
      value += item.discountAmount;
    }

    return value;
  }

  // --------------------------------------------------
  // Tax
  // --------------------------------------------------

  double get tax {
    return cgst + sgst + igst;
  }
  // --------------------------------------------------
  // Grand Total
  // --------------------------------------------------

  double get grandTotal {
    return subtotal - discount + tax;
  }

  Widget _buildOrderHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // -----------------------------------------
          // Order type + table
          // -----------------------------------------
          Row(
            children: [
              const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(width: 8),

              DropdownButton<String>(
                value: orderType,
                isDense: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'DINE_IN', child: Text('Dine-In')),
                  DropdownMenuItem(value: 'TAKEAWAY', child: Text('Takeaway')),
                  DropdownMenuItem(value: 'DELIVERY', child: Text('Delivery')),
                ],
                onChanged: onOrderTypeChanged,
              ),

              const Spacer(),

              if (orderType == 'DINE_IN' && tableId != null)
                Row(
                  children: [
                    const Icon(Icons.table_restaurant, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      'Table $tableId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 4),

          // -----------------------------------------
          // Guest count
          // -----------------------------------------
          Row(
            children: [
              const Text(
                'Guests',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const Spacer(),

              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: guestCount > 1
                    ? () {
                        onGuestCountChanged?.call(guestCount - 1);
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),

              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '$guestCount',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  onGuestCountChanged?.call(guestCount + 1);
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),

      child: Column(
        children: [
          _buildOrderHeader(context),
          // -----------------------------------------
          // Header
          // -----------------------------------------
          Container(
            padding: const EdgeInsets.all(14),

            child: Row(
              children: [
                const Text(
                  'CART',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const Spacer(),

                Text(
                  '${items.length} item'
                  '${items.length == 1 ? '' : 's'}',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // -----------------------------------------
          // Cart items
          // -----------------------------------------
          Expanded(
            child: items.isEmpty
                ? _buildEmptyCart()
                : ListView.builder(
                    itemCount: items.length,

                    itemBuilder: (context, index) {
                      final item = items[index];

                      return PosCartItemRow(
                        item: item,

                        onIncrement: () {
                          onIncrement?.call(index);
                        },

                        onDecrement: () {
                          onDecrement?.call(index);
                        },

                        onDelete: () {
                          onDelete?.call(index);
                        },
                      );
                    },
                  ),
          ),

          // -----------------------------------------
          // Totals
          // -----------------------------------------
          _buildTotals(context),

          // -----------------------------------------
          // Send to kitchen
          // -----------------------------------------
          if (onSendToKitchen != null)
            Padding(
              padding: const EdgeInsets.all(12),

              child: SizedBox(
                width: double.infinity,

                height: 48,

                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSaveOrder,
                        icon: const Icon(Icons.save),
                        label: const Text('SAVE ORDER'),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSendToKitchen,
                        icon: const Icon(Icons.restaurant),
                        label: const Text('SEND TO KITCHEN'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canCreateBill ? onCreateBill : null,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('BILL'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Empty cart
  // --------------------------------------------------

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(Icons.shopping_cart_outlined, size: 50),

          SizedBox(height: 10),

          Text('Cart is empty'),

          SizedBox(height: 5),

          Text('Select an item to add'),
        ],
      ),
    );
  }

  double get cgst {
    double value = 0;

    for (final item in items) {
      final rate = item.taxGroup?.cgst;

      if (rate != null && !rate.isInclusive) {
        value += item.taxableAmount * rate.rate / 100;
      }
    }

    return value;
  }

  double get sgst {
    double value = 0;

    for (final item in items) {
      final rate = item.taxGroup?.sgst;

      if (rate != null && !rate.isInclusive) {
        value += item.taxableAmount * rate.rate / 100;
      }
    }

    return value;
  }

  double get igst {
    double value = 0;

    for (final item in items) {
      final rate = item.taxGroup?.igst;

      if (rate != null && !rate.isInclusive) {
        value += item.taxableAmount * rate.rate / 100;
      }
    }

    return value;
  }

  // --------------------------------------------------
  // Totals
  // --------------------------------------------------

  Widget _buildTotals(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),

      child: Column(
        children: [
          _totalRow('Subtotal', subtotal),

          if (discount > 0) _totalRow('Discount', -discount),

          if (cgst > 0) _totalRow('CGST', cgst),

          if (sgst > 0) _totalRow('SGST', sgst),

          if (igst > 0) _totalRow('IGST', igst),

          const Divider(),

          Row(
            children: [
              const Text(
                'GRAND TOTAL',

                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),

              const Spacer(),

              Text(
                '₹${grandTotal.toStringAsFixed(2)}',

                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),

      child: Row(
        children: [
          Text(title),

          const Spacer(),

          Text('₹${amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
