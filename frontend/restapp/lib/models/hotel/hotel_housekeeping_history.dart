class HotelHousekeepingHistory {
  final int housekeepingLogId;
  final int outletId;
  final int roomId;
  final String roomNo;
  final String? roomName;

  final String? roomTypeCode;
  final String? roomTypeName;

  final int? stayId;

  final String status;

  final DateTime? startedAt;
  final DateTime? completedAt;

  final int? durationMinutes;

  final int? startedBy;
  final int? completedBy;

  final String? remarks;

  HotelHousekeepingHistory({
    required this.housekeepingLogId,
    required this.outletId,
    required this.roomId,
    required this.roomNo,
    this.roomName,
    this.roomTypeCode,
    this.roomTypeName,
    this.stayId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.durationMinutes,
    this.startedBy,
    this.completedBy,
    this.remarks,
  });

  factory HotelHousekeepingHistory.fromJson(Map<String, dynamic> json) {
    return HotelHousekeepingHistory(
      housekeepingLogId: _toInt(json['housekeepingLogId']),

      outletId: _toInt(json['outletId']),

      roomId: _toInt(json['roomId']),

      roomNo: json['roomNo']?.toString() ?? '',

      roomName: json['roomName']?.toString(),

      roomTypeCode: json['roomTypeCode']?.toString(),

      roomTypeName: json['roomTypeName']?.toString(),

      stayId: json['stayId'] == null ? null : _toInt(json['stayId']),

      status: json['status']?.toString() ?? '',

      startedAt: _toDateTime(json['startedAt']),

      completedAt: _toDateTime(json['completedAt']),

      durationMinutes: json['durationMinutes'] == null
          ? null
          : _toInt(json['durationMinutes']),

      startedBy: json['startedBy'] == null ? null : _toInt(json['startedBy']),

      completedBy: json['completedBy'] == null
          ? null
          : _toInt(json['completedBy']),

      remarks: json['remarks']?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
