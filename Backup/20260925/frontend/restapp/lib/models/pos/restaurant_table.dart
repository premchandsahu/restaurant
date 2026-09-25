class RestaurantTable {
  final int tableId;
  final String tableUuid;
  final String tableCode;
  final String tableName;
  final int capacity;

  final int? floorId;
  final int? diningAreaId;

  final String shape;

  final double posX;
  final double posY;
  final double width;
  final double height;
  final int activeOrderCount;
  final int activeGuestCount;
  final double activeOrderAmount;
  String status;

  RestaurantTable({
    required this.tableId,
    required this.tableUuid,
    required this.tableCode,
    required this.tableName,
    required this.capacity,
    this.floorId,
    this.diningAreaId,
    required this.shape,
    required this.posX,
    required this.posY,
    required this.width,
    required this.height,
    this.activeOrderCount = 0,
    this.activeGuestCount = 0,
    this.activeOrderAmount = 0,
    required this.status,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      tableId: _toInt(json['table_id']),
      tableUuid: json['table_uuid']?.toString() ?? '',
      tableCode: json['table_code']?.toString() ?? '',
      tableName: json['table_name']?.toString() ?? '',
      capacity: _toInt(json['capacity'], defaultValue: 2),

      floorId: json['floor_id'] == null ? null : _toInt(json['floor_id']),

      diningAreaId: json['dining_area_id'] == null
          ? null
          : _toInt(json['dining_area_id']),

      shape: json['shape']?.toString() ?? 'SQUARE',

      posX: _toDouble(json['pos_x']),
      posY: _toDouble(json['pos_y']),

      width: _toDouble(json['width'], defaultValue: 100),

      height: _toDouble(json['height'], defaultValue: 100),

      activeOrderCount:
          int.tryParse(json['active_order_count']?.toString() ?? '0') ?? 0,

      activeGuestCount:
          int.tryParse(json['active_guest_count']?.toString() ?? '0') ?? 0,

      activeOrderAmount:
          double.tryParse(json['active_order_amount']?.toString() ?? '0') ?? 0,

      status: json['status']?.toString() ?? 'AVAILABLE',
    );
  }

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _toDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? defaultValue;
  }
}
