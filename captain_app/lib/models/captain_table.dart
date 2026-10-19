class CaptainTable {
  final int tableId;
  final String tableCode;
  final String tableName;
  final int capacity;

  final int? floorId;
  final String? floorName;

  final int? diningAreaId;
  final String? diningAreaName;

  final String status;

  CaptainTable({
    required this.tableId,
    required this.tableCode,
    required this.tableName,
    required this.capacity,
    this.floorId,
    this.floorName,
    this.diningAreaId,
    this.diningAreaName,
    required this.status,
  });

  factory CaptainTable.fromJson(
    Map<String, dynamic> json, {
    Map<int, String> floorNames = const {},
    Map<int, String> diningAreaNames = const {},
  }) {
    final floorId = _toInt(json['floorId'] ?? json['floor_id']);

    final diningAreaId = _toInt(json['diningAreaId'] ?? json['dining_area_id']);

    return CaptainTable(
      tableId: _toInt(json['tableId'] ?? json['table_id']) ?? 0,
      tableCode:
          json['tableCode']?.toString() ?? json['table_code']?.toString() ?? '',
      tableName:
          json['tableName']?.toString() ?? json['table_name']?.toString() ?? '',
      capacity: _toInt(json['capacity']) ?? 0,
      floorId: floorId,
      floorName:
          json['floorName']?.toString() ??
          json['floor_name']?.toString() ??
          (floorId != null ? floorNames[floorId] : null),
      diningAreaId: diningAreaId,
      diningAreaName:
          json['diningAreaName']?.toString() ??
          json['dining_area_name']?.toString() ??
          (diningAreaId != null ? diningAreaNames[diningAreaId] : null),
      status: json['status']?.toString() ?? 'AVAILABLE',
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}
