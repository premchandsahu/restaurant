class HotelHousekeepingRoom {
  final int roomId;
  final int outletId;
  final int roomTypeId;
  final String roomNo;
  final String? roomName;
  final int? floorNo;
  final String? roomTypeCode;
  final String? roomTypeName;
  final String status;
  final String housekeepingStatus;

  final int? housekeepingLogId;
  final DateTime? startedAt;

  HotelHousekeepingRoom({
    required this.roomId,
    required this.outletId,
    required this.roomTypeId,
    required this.roomNo,
    this.roomName,
    this.floorNo,
    this.roomTypeCode,
    this.roomTypeName,
    required this.status,
    required this.housekeepingStatus,
    this.housekeepingLogId,
    this.startedAt,
  });

  factory HotelHousekeepingRoom.fromJson(Map<String, dynamic> json) {
    return HotelHousekeepingRoom(
      roomId: _toInt(json['roomId']),
      outletId: _toInt(json['outletId']),
      roomTypeId: _toInt(json['roomTypeId']),
      roomNo: json['roomNo']?.toString() ?? '',
      roomName: json['roomName']?.toString(),
      floorNo: _toNullableInt(json['floorNo']),
      roomTypeCode: json['roomTypeCode']?.toString(),
      roomTypeName: json['roomTypeName']?.toString(),
      status: json['status']?.toString() ?? '',
      housekeepingStatus: json['housekeepingStatus']?.toString() ?? '',

      housekeepingLogId: json['housekeepingLogId'] == null
          ? null
          : _toInt(json['housekeepingLogId']),

      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'].toString()),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }
}
