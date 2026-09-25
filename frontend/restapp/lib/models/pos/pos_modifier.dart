class PosModifier {
  final int modifierGroupId;
  final int modifierOptionId;
  final String modifierName;
  final double qty;
  final double rate;
  final double amount;

  PosModifier({
    required this.modifierGroupId,
    required this.modifierOptionId,
    required this.modifierName,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory PosModifier.fromJson(Map<String, dynamic> json) {
    return PosModifier(
      modifierGroupId: int.parse(json['modifier_group_id'].toString()),

      modifierOptionId: int.parse(json['modifier_option_id'].toString()),

      modifierName: json['modifier_name']?.toString() ?? '',

      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,

      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0,

      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
    );
  }
}
