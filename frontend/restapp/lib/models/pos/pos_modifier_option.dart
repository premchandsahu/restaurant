class PosModifierOption {
  final int modifierOptionId;
  final int modifierGroupId;

  final String optionName;
  final double extraRate;

  final int? taxGroupId;

  final int displayOrder;

  const PosModifierOption({
    required this.modifierOptionId,
    required this.modifierGroupId,
    required this.optionName,
    required this.extraRate,
    this.taxGroupId,
    this.displayOrder = 0,
  });

  factory PosModifierOption.fromJson(Map<String, dynamic> json) {
    return PosModifierOption(
      modifierOptionId: _int(json['modifier_option_id']),

      modifierGroupId: _int(json['modifier_group_id']),

      optionName: json['option_name']?.toString() ?? '',

      extraRate: _double(json['extra_rate']),

      taxGroupId: _nullableInt(json['tax_group_id']),

      displayOrder: _int(json['display_order']),
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
}
