class InventoryMenuVariant {
  final int variantId;
  final String variantCode;
  final String variantName;
  final double rate;

  const InventoryMenuVariant({
    required this.variantId,
    required this.variantCode,
    required this.variantName,
    required this.rate,
  });

  factory InventoryMenuVariant.fromJson(Map<String, dynamic> json) {
    return InventoryMenuVariant(
      variantId: _int(json['variant_id']),
      variantCode: json['variant_code']?.toString() ?? '',
      variantName: json['variant_name']?.toString() ?? '',
      rate: _double(json['rate']),
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
}

class InventoryMenuItem {
  final int menuItemId;
  final String itemCode;
  final String itemName;
  final String itemType;
  final double baseRate;
  final bool isActive;
  final bool isAvailable;
  final List<InventoryMenuVariant> variants;

  const InventoryMenuItem({
    required this.menuItemId,
    required this.itemCode,
    required this.itemName,
    required this.itemType,
    required this.baseRate,
    required this.isActive,
    required this.isAvailable,
    required this.variants,
  });

  factory InventoryMenuItem.fromJson(
    Map<String, dynamic> json, {
    List<InventoryMenuVariant> variants = const [],
  }) {
    return InventoryMenuItem(
      menuItemId: _int(json['menu_item_id']),
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? 'FOOD',
      baseRate: _double(json['base_rate']),
      isActive: _bool(json['is_active']),
      isAvailable: _bool(json['is_available']),
      variants: variants,
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == '1' || text == 'true';
  }
}
