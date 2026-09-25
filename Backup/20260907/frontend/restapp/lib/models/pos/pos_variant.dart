class PosVariant {
  final int variantId;
  final String variantUuid;
  final int menuItemId;

  final String variantCode;
  final String variantName;

  final double rate;

  final int? taxGroupId;

  final int displayOrder;
  final bool isDefault;

  const PosVariant({
    required this.variantId,
    required this.variantUuid,
    required this.menuItemId,
    required this.variantCode,
    required this.variantName,
    required this.rate,
    this.taxGroupId,
    this.displayOrder = 0,
    this.isDefault = false,
  });

  factory PosVariant.fromJson(Map<String, dynamic> json) {
    return PosVariant(
      variantId: _int(json['variant_id']),

      variantUuid: json['variant_uuid']?.toString() ?? '',

      menuItemId: _int(json['menu_item_id']),

      variantCode: json['variant_code']?.toString() ?? '',

      variantName: json['variant_name']?.toString() ?? '',

      rate: _double(json['rate']),

      taxGroupId: _nullableInt(json['tax_group_id']),

      displayOrder: _int(json['display_order']),

      isDefault: _bool(json['is_default']),
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;

    return int.tryParse(value.toString());
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    return value?.toString() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }
}
