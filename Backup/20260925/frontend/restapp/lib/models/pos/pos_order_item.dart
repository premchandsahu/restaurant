import 'pos_modifier.dart';

class PosOrderItem {
  final int orderItemId;
  final int menuItemId;
  final int? variantId;

  final String itemName;
  final String? variantName;

  final double qty;
  final double rate;

  final double grossAmount;
  final double discountAmount;
  final double taxableAmount;
  final double taxAmount;
  final double netAmount;

  final String status;
  final int? kitchenStationId;

  final String? specialInstruction;

  final List<PosModifier> modifiers;

  PosOrderItem({
    required this.orderItemId,
    required this.menuItemId,
    this.variantId,
    required this.itemName,
    this.variantName,
    required this.qty,
    required this.rate,
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.status,
    this.kitchenStationId,
    this.specialInstruction,
    this.modifiers = const [],
  });

  factory PosOrderItem.fromJson(Map<String, dynamic> json) {
    return PosOrderItem(
      orderItemId: int.parse(json['order_item_id'].toString()),

      menuItemId: int.parse(json['menu_item_id'].toString()),

      variantId: json['variant_id'] == null
          ? null
          : int.tryParse(json['variant_id'].toString()),

      itemName: json['item_name']?.toString() ?? '',

      variantName: json['variant_name']?.toString(),

      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,

      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0,

      grossAmount:
          double.tryParse(json['gross_amount']?.toString() ?? '0') ?? 0,

      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,

      taxableAmount:
          double.tryParse(json['taxable_amount']?.toString() ?? '0') ?? 0,

      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,

      netAmount: double.tryParse(json['net_amount']?.toString() ?? '0') ?? 0,

      status: json['status']?.toString() ?? 'OPEN',

      kitchenStationId: json['kitchen_station_id'] == null
          ? null
          : int.tryParse(json['kitchen_station_id'].toString()),

      specialInstruction: json['special_instruction']?.toString(),

      modifiers:
          (json['modifiers'] as List?)
              ?.map((e) => PosModifier.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}
