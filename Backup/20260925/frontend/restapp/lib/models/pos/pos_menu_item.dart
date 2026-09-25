class PosMenuItem {
  final int menuItemId;
  final String menuItemUuid;

  final int outletId;
  final int categoryId;

  final String itemCode;
  final String itemName;
  final String? description;

  final String itemType;

  final double baseRate;

  final int? taxGroupId;

  final bool isVeg;
  final bool isEgg;
  final bool isSpicy;

  final String? imageUrl;
  final String? barcode;

  final int preparationTimeMinutes;

  final bool allowDiscount;
  final bool isAvailable;
  final bool isActive;

  const PosMenuItem({
    required this.menuItemId,
    required this.menuItemUuid,
    required this.outletId,
    required this.categoryId,
    required this.itemCode,
    required this.itemName,
    this.description,
    required this.itemType,
    required this.baseRate,
    this.taxGroupId,
    required this.isVeg,
    required this.isEgg,
    required this.isSpicy,
    this.imageUrl,
    this.barcode,
    required this.preparationTimeMinutes,
    required this.allowDiscount,
    required this.isAvailable,
    required this.isActive,
  });

  factory PosMenuItem.fromJson(Map<String, dynamic> json) {
    return PosMenuItem(
      menuItemId: _intValue(json['menu_item_id']),

      menuItemUuid: json['menu_item_uuid']?.toString() ?? '',

      outletId: _intValue(json['outlet_id']),

      categoryId: _intValue(json['menu_category_id']),

      itemCode: json['item_code']?.toString() ?? '',

      itemName: json['item_name']?.toString() ?? '',

      description: json['description']?.toString(),

      itemType: json['item_type']?.toString() ?? 'FOOD',

      baseRate: _doubleValue(json['base_rate']),

      taxGroupId: _nullableInt(json['tax_group_id']),

      isVeg: _boolValue(json['is_veg']),

      isEgg: _boolValue(json['is_egg']),

      isSpicy: _boolValue(json['is_spicy']),

      imageUrl: json['image_url']?.toString(),

      barcode: json['barcode']?.toString(),

      preparationTimeMinutes: _intValue(json['preparation_time_minutes']),

      allowDiscount: _boolValue(json['allow_discount']),

      isAvailable: _boolValue(json['is_available']),

      isActive: _boolValue(json['is_active']),
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;

    return int.tryParse(value.toString());
  }

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    return value?.toString() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }
}
