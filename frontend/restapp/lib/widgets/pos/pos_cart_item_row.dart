import 'package:flutter/material.dart';

import '../../models/pos/pos_cart_item.dart';

class PosCartItemRow extends StatelessWidget {
  final PosCartItem item;

  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  const PosCartItemRow({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // -----------------------------------------
          // Item name
          // -----------------------------------------
          Row(
            children: [
              Expanded(
                child: Text(
                  item.displayName,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

              IconButton(
                tooltip: 'Remove item',

                icon: const Icon(Icons.delete_outline, size: 20),

                onPressed: onDelete,
              ),
            ],
          ),

          // -----------------------------------------
          // Modifiers
          // -----------------------------------------
          if (item.modifierDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 30, bottom: 5),

              child: Text(
                item.modifierDisplay,

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: TextStyle(
                  fontSize: 12,

                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // -----------------------------------------
          // Quantity + amount
          // -----------------------------------------
          Row(
            children: [
              // Quantity controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),

                  borderRadius: BorderRadius.circular(6),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    InkWell(
                      onTap: onDecrement,

                      child: const Padding(
                        padding: EdgeInsets.all(6),

                        child: Icon(Icons.remove, size: 16),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),

                      child: Text(
                        _formatQuantity(item.quantity),

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    InkWell(
                      onTap: onIncrement,

                      child: const Padding(
                        padding: EdgeInsets.all(6),

                        child: Icon(Icons.add, size: 16),
                      ),
                    ),
                    item.isSentToKitchen
                        ? const Text(
                            '✓ Sent to Kitchen',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ],
                ),
              ),

              const Spacer(),

              // Amount
              Text(
                '₹${item.grossAmount.toStringAsFixed(2)}',

                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }
}
