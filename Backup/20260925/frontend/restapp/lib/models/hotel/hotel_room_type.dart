class HotelRoomType {
  final int roomTypeId;
  final int outletId;

  final String typeCode;
  final String typeName;

  final int capacityAdult;
  final int capacityChild;

  final double baseRate;

  final bool isActive;

  const HotelRoomType({
    required this.roomTypeId,
    required this.outletId,
    required this.typeCode,
    required this.typeName,
    required this.capacityAdult,
    required this.capacityChild,
    required this.baseRate,
    required this.isActive,
  });

  factory HotelRoomType.fromJson(Map<String, dynamic> json) {
    return HotelRoomType(
      roomTypeId: _toInt(json['roomTypeId']),

      outletId: _toInt(json['outletId']),

      typeCode: json['typeCode']?.toString() ?? '',

      typeName: json['typeName']?.toString() ?? '',

      capacityAdult: _toInt(json['capacityAdult']),

      capacityChild: _toInt(json['capacityChild']),

      baseRate: _toDouble(json['baseRate']),

      isActive: json['isActive'] == true || json['isActive'] == 1,
    );
  }

  String get displayName {
    return '$typeName ($typeCode)';
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
