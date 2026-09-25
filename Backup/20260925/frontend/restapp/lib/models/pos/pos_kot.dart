class PosKot {
  final int kotId;
  final String kotUuid;
  final int outletId;
  final int orderId;
  final String kotNo;
  final DateTime? kotDate;
  final int? kitchenStationId;
  final String? stationCode;
  final String? stationName;
  final String status;
  final int printedCount;
  final int? createdBy;
  final DateTime? updatedAt;
  final List<PosKotItem> items;

  PosKot({
    required this.kotId,
    required this.kotUuid,
    required this.outletId,
    required this.orderId,
    required this.kotNo,
    this.kotDate,
    this.kitchenStationId,
    this.stationCode,
    this.stationName,
    required this.status,
    required this.printedCount,
    this.createdBy,
    this.updatedAt,
    required this.items,
  });

  factory PosKot.fromJson(Map<String, dynamic> json) {
    return PosKot(
      kotId: int.tryParse(json['kot_id']?.toString() ?? '') ?? 0,

      kotUuid: json['kot_uuid']?.toString() ?? '',

      outletId: int.tryParse(json['outlet_id']?.toString() ?? '') ?? 0,

      orderId: int.tryParse(json['order_id']?.toString() ?? '') ?? 0,

      kotNo: json['kot_no']?.toString() ?? '',

      kotDate: json['kot_date'] != null
          ? DateTime.tryParse(json['kot_date'].toString())
          : null,

      kitchenStationId: json['kitchen_station_id'] != null
          ? int.tryParse(json['kitchen_station_id'].toString())
          : null,

      stationCode: json['station_code']?.toString(),

      stationName: json['station_name']?.toString(),

      status: json['status']?.toString() ?? 'NEW',

      printedCount: int.tryParse(json['printed_count']?.toString() ?? '0') ?? 0,

      createdBy: json['created_by'] != null
          ? int.tryParse(json['created_by'].toString())
          : null,

      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,

      items:
          (json['items'] as List?)
              ?.map(
                (item) => PosKotItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          [],
    );
  }
}

class PosKotItem {
  final int kotItemId;
  final int kotId;
  final int orderItemId;
  final double qty;
  final String itemName;
  final String? variantName;
  final String? instruction;
  final String status;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? servedAt;

  PosKotItem({
    required this.kotItemId,
    required this.kotId,
    required this.orderItemId,
    required this.qty,
    required this.itemName,
    this.variantName,
    this.instruction,
    required this.status,
    this.startedAt,
    this.readyAt,
    this.servedAt,
  });

  factory PosKotItem.fromJson(Map<String, dynamic> json) {
    return PosKotItem(
      kotItemId: int.tryParse(json['kot_item_id']?.toString() ?? '') ?? 0,

      kotId: int.tryParse(json['kot_id']?.toString() ?? '') ?? 0,

      orderItemId: int.tryParse(json['order_item_id']?.toString() ?? '') ?? 0,

      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,

      itemName: json['item_name']?.toString() ?? '',

      variantName: json['variant_name']?.toString(),

      instruction: json['instruction']?.toString(),

      status: json['status']?.toString() ?? 'NEW',

      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,

      readyAt: json['ready_at'] != null
          ? DateTime.tryParse(json['ready_at'].toString())
          : null,

      servedAt: json['served_at'] != null
          ? DateTime.tryParse(json['served_at'].toString())
          : null,
    );
  }
}
