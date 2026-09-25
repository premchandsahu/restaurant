/*import 'package:flutter/material.dart';

import '../../models/pos/pos_category.dart';
import '../../models/pos/pos_menu_item.dart';
import '../../widgets/pos/pos_category_panel.dart';
import '../../widgets/pos/pos_menu_panel.dart';

class PosMenuTestScreen extends StatefulWidget {
  const PosMenuTestScreen({super.key});

  @override
  State<PosMenuTestScreen> createState() => _PosMenuTestScreenState();
}

class _PosMenuTestScreenState extends State<PosMenuTestScreen> {
  final categories = const [
    PosCategory(categoryId: 1, categoryName: 'Starters'),

    PosCategory(categoryId: 2, categoryName: 'Main Course'),

    PosCategory(categoryId: 3, categoryName: 'Breads'),

    PosCategory(categoryId: 4, categoryName: 'Beverages'),
  ];

  final items = const [
    PosMenuItem(
      menuItemId: 1,
      categoryId: 1,
      itemName: 'Paneer Tikka',
      saleRate: 220,
    ),

    PosMenuItem(
      menuItemId: 2,
      categoryId: 1,
      itemName: 'Chicken Tikka',
      saleRate: 280,
    ),

    PosMenuItem(
      menuItemId: 3,
      categoryId: 3,
      itemName: 'Butter Naan',
      saleRate: 55,
    ),

    PosMenuItem(
      menuItemId: 4,
      categoryId: 4,
      itemName: 'Cold Coffee',
      saleRate: 140,
    ),
  ];

  int selectedCategoryId = 1;

  @override
  Widget build(BuildContext context) {
    final filteredItems = items
        .where((item) => item.categoryId == selectedCategoryId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('POS Menu Test')),

      body: Row(
        children: [
          SizedBox(
            width: 180,

            child: PosCategoryPanel(
              categories: categories,

              selectedCategoryId: selectedCategoryId,

              onCategorySelected: (category) {
                setState(() {
                  selectedCategoryId = category.categoryId;
                });
              },
            ),
          ),

          Expanded(
            child: PosMenuPanel(
              items: filteredItems,

              onItemSelected: (item) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.itemName} selected')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
*/
