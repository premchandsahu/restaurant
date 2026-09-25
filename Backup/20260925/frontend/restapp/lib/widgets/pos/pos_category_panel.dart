import 'package:flutter/material.dart';

import '../../models/pos/pos_category.dart';

class PosCategoryPanel extends StatelessWidget {
  final List<PosCategory> categories;

  final int? selectedCategoryId;

  final ValueChanged<PosCategory> onCategorySelected;

  const PosCategoryPanel({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];

          final selected = category.categoryId == selectedCategoryId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,

              borderRadius: BorderRadius.circular(8),

              child: InkWell(
                borderRadius: BorderRadius.circular(8),

                onTap: () {
                  onCategorySelected(category);
                },

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),

                  child: Text(
                    category.categoryName,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
