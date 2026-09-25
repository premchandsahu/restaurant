class PosCategory {
  final int categoryId;
  final int outletId;
  final String categoryCode;
  final String categoryName;
  final int? parentCategoryId;
  final int displayOrder;

  const PosCategory({
    required this.categoryId,
    required this.outletId,
    required this.categoryCode,
    required this.categoryName,
    this.parentCategoryId,
    this.displayOrder = 0,
  });

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    return PosCategory(
      categoryId: _intValue(json['menu_category_id']),

      outletId: _intValue(json['outlet_id']),

      categoryCode: json['category_code']?.toString() ?? '',

      categoryName: json['category_name']?.toString() ?? '',

      parentCategoryId: _nullableInt(json['parent_category_id']),

      displayOrder: _intValue(json['display_order']),
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
}
