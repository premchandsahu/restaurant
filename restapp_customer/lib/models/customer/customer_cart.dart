import 'customer_menu.dart';

class CustomerCartItem {
  final MenuItem menuItem;
  final MenuVariant? variant;
  final List<ModifierOption> modifiers;

  int quantity;
  String specialInstruction;

  CustomerCartItem({
    required this.menuItem,
    this.variant,
    required this.modifiers,
    this.quantity = 1,
    this.specialInstruction = '',
  });

  double get baseRate {
    return variant?.rate ?? menuItem.baseRate;
  }

  double get modifierAmount {
    return modifiers.fold(0.0, (sum, modifier) => sum + modifier.extraRate);
  }

  double get unitRate {
    return baseRate + modifierAmount;
  }

  double get lineAmount {
    return unitRate * quantity;
  }

  String get displayName {
    if (variant != null) {
      return '${menuItem.itemName} - ${variant!.variantName}';
    }

    return menuItem.itemName ?? "";
  }

  String get modifierText {
    if (modifiers.isEmpty) {
      return '';
    }

    return modifiers.map((modifier) => modifier.optionName).join(', ');
  }

  /// Used to determine whether two selections represent
  /// the same cart line.
  bool isSameSelection({
    required MenuItem item,
    MenuVariant? selectedVariant,
    required List<ModifierOption> selectedModifiers,
  }) {
    if (menuItem.menuItemId != item.menuItemId) {
      return false;
    }

    if (variant?.variantId != selectedVariant?.variantId) {
      return false;
    }

    final currentIds = modifiers.map((e) => e.modifierOptionId).toSet();

    final selectedIds = selectedModifiers
        .map((e) => e.modifierOptionId)
        .toSet();

    if (currentIds.length != selectedIds.length) {
      return false;
    }

    return currentIds.containsAll(selectedIds);
  }
}

class CustomerCart {
  final List<CustomerCartItem> items = [];

  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.lineAmount);
  }

  bool get isEmpty => items.isEmpty;

  void addItem({
    required MenuItem menuItem,
    MenuVariant? variant,
    required List<ModifierOption> modifiers,
    int quantity = 1,
    String specialInstruction = '',
  }) {
    final existingIndex = items.indexWhere(
      (cartItem) => cartItem.isSameSelection(
        item: menuItem,
        selectedVariant: variant,
        selectedModifiers: modifiers,
      ),
    );

    if (existingIndex >= 0) {
      items[existingIndex].quantity += quantity;

      if (specialInstruction.trim().isNotEmpty) {
        items[existingIndex].specialInstruction = specialInstruction;
      }

      return;
    }

    items.add(
      CustomerCartItem(
        menuItem: menuItem,
        variant: variant,
        modifiers: List<ModifierOption>.from(modifiers),
        quantity: quantity,
        specialInstruction: specialInstruction,
      ),
    );
  }

  void increaseQuantity(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    items[index].quantity++;
  }

  void decreaseQuantity(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    if (items[index].quantity > 1) {
      items[index].quantity--;
    }
  }

  void removeItem(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    items.removeAt(index);
  }

  void updateInstruction(int index, String instruction) {
    if (index < 0 || index >= items.length) {
      return;
    }

    items[index].specialInstruction = instruction;
  }

  void clear() {
    items.clear();
  }
}
