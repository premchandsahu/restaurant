import 'package:flutter/material.dart';

import '../../models/pos/pos_menu_item.dart';

class PosMenuPanel extends StatelessWidget {
  final List<PosMenuItem> items;

  final ValueChanged<PosMenuItem> onItemSelected;

  const PosMenuPanel({
    super.key,
    required this.items,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items available'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),

      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 110,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),

      itemCount: items.length,

      itemBuilder: (context, index) {
        final item = items[index];

        return _MenuItemCard(
          item: item,
          onTap: () {
            onItemSelected(item);
          },
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final PosMenuItem item;
  final VoidCallback onTap;

  const _MenuItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rate = item.baseRate;

    return Card(
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: item.isAvailable ? onTap : null,

        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              // ------------------------------------
              // Item name
              // ------------------------------------
              Text(
                item.itemName,

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontWeight: FontWeight.bold,

                  fontSize: 15,
                ),
              ),

              // ------------------------------------
              // Rate + indicators
              // ------------------------------------
              Row(
                children: [
                  Text(
                    '₹${rate.toStringAsFixed(2)}',

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      fontSize: 16,
                    ),
                  ),

                  const Spacer(),

                  // Veg / Non-veg indicator
                  if (item.isVeg) const Icon(Icons.circle, size: 12),

                  if (!item.isVeg && item.isEgg)
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(Icons.circle, size: 12),
                    ),

                  // Spicy indicator
                  if (item.isSpicy)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.local_fire_department, size: 18),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
