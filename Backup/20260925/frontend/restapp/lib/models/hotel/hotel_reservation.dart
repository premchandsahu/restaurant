class HotelReservation {
  final int reservationId;
  final String reservationNo;

  final int guestId;
  final String? guestCode;
  final String? guestFirstName;
  final String? guestLastName;
  final String? guestPhone;
  final String? guestEmail;

  final int roomTypeId;
  final String? roomTypeCode;
  final String? roomTypeName;

  final int? roomId;
  final String? roomNo;
  final String? roomName;
  final int? floorNo;
  final String? roomStatus;
  final String? housekeepingStatus;

  final String? bookingDate;
  final String expectedCheckIn;
  final String expectedCheckOut;

  final int adults;
  final int children;

  final double roomRate;
  final double advanceAmount;

  final String status;
  final String? bookingSource;
  final String? remarks;

  final String? createdAt;
  final String? updatedAt;

  const HotelReservation({
    required this.reservationId,
    required this.reservationNo,
    required this.guestId,
    this.guestCode,
    this.guestFirstName,
    this.guestLastName,
    this.guestPhone,
    this.guestEmail,
    required this.roomTypeId,
    this.roomTypeCode,
    this.roomTypeName,
    this.roomId,
    this.roomNo,
    this.roomName,
    this.floorNo,
    this.roomStatus,
    this.housekeepingStatus,
    this.bookingDate,
    required this.expectedCheckIn,
    required this.expectedCheckOut,
    required this.adults,
    required this.children,
    required this.roomRate,
    required this.advanceAmount,
    required this.status,
    this.bookingSource,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  factory HotelReservation.fromJson(Map<String, dynamic> json) {
    final guest = json['guest'] as Map<String, dynamic>? ?? {};

    final roomType = json['roomType'] as Map<String, dynamic>? ?? {};

    final room = json['room'] as Map<String, dynamic>?;

    return HotelReservation(
      reservationId: _toInt(json['reservationId']),

      reservationNo: json['reservationNo']?.toString() ?? '',

      guestId: _toInt(guest['guestId']),

      guestCode: guest['guestCode']?.toString(),

      guestFirstName: guest['firstName']?.toString(),

      guestLastName: guest['lastName']?.toString(),

      guestPhone: guest['phone']?.toString(),

      guestEmail: guest['email']?.toString(),

      roomTypeId: _toInt(roomType['roomTypeId']),

      roomTypeCode: roomType['typeCode']?.toString(),

      roomTypeName: roomType['typeName']?.toString(),

      roomId: room == null ? null : _toNullableInt(room['roomId']),

      roomNo: room?['roomNo']?.toString(),

      roomName: room?['roomName']?.toString(),

      floorNo: room == null ? null : _toNullableInt(room['floorNo']),

      roomStatus: room?['status']?.toString(),

      housekeepingStatus: room?['housekeepingStatus']?.toString(),

      bookingDate: json['bookingDate']?.toString(),

      expectedCheckIn: json['expectedCheckIn'].toString(),

      expectedCheckOut: json['expectedCheckOut'].toString(),

      adults: _toInt(json['adults']),

      children: _toInt(json['children']),

      roomRate: _toDouble(json['roomRate']),

      advanceAmount: _toDouble(json['advanceAmount']),

      status: json['status']?.toString() ?? '',

      bookingSource: json['bookingSource']?.toString(),

      remarks: json['remarks']?.toString(),

      createdAt: json['createdAt']?.toString(),

      updatedAt: json['updatedAt']?.toString(),
    );
  }

  String get guestName {
    final parts = [guestFirstName, guestLastName]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();

    return parts.isEmpty ? '-' : parts.join(' ');
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
