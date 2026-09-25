class HotelActiveStay {
  final int stayId;
  final String stayNo;

  final int guestId;
  final String? guestCode;
  final String? guestFirstName;
  final String? guestLastName;
  final String? guestPhone;

  final int roomId;
  final String? roomNo;
  final String? roomName;
  final String? roomTypeCode;
  final String? roomTypeName;

  final String? checkIn;
  final String? expectedCheckOut;

  final int adults;
  final int children;

  final double roomRate;
  final String status;

  const HotelActiveStay({
    required this.stayId,
    required this.stayNo,
    required this.guestId,
    this.guestCode,
    this.guestFirstName,
    this.guestLastName,
    this.guestPhone,
    required this.roomId,
    this.roomNo,
    this.roomName,
    this.roomTypeCode,
    this.roomTypeName,
    this.checkIn,
    this.expectedCheckOut,
    required this.adults,
    required this.children,
    required this.roomRate,
    required this.status,
  });

  factory HotelActiveStay.fromJson(Map<String, dynamic> json) {
    final guest = json['guest'] as Map<String, dynamic>? ?? {};

    final room = json['room'] as Map<String, dynamic>? ?? {};

    return HotelActiveStay(
      stayId: _toInt(json['stayId']),
      stayNo: json['stayNo']?.toString() ?? '',

      guestId: _toInt(guest['guestId']),
      guestCode: guest['guestCode']?.toString(),
      guestFirstName: guest['firstName']?.toString(),
      guestLastName: guest['lastName']?.toString(),
      guestPhone: guest['phone']?.toString(),

      roomId: _toInt(room['roomId']),
      roomNo: room['roomNo']?.toString(),
      roomName: room['roomName']?.toString(),
      roomTypeCode: room['roomTypeCode']?.toString(),
      roomTypeName: room['roomTypeName']?.toString(),

      checkIn: json['checkIn']?.toString(),
      expectedCheckOut: json['expectedCheckOut']?.toString(),

      adults: _toInt(json['adults']),
      children: _toInt(json['children']),

      roomRate: _toDouble(json['roomRate']),

      status: json['status']?.toString() ?? '',
    );
  }

  String get guestName {
    final parts = [guestFirstName, guestLastName]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();

    return parts.isEmpty ? guestCode ?? '-' : parts.join(' ');
  }

  String get displayRoom {
    if (roomNo != null && roomNo!.trim().isNotEmpty) {
      return roomNo!;
    }

    return roomTypeName ?? '-';
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
