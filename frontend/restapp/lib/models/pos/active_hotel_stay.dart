class ActiveHotelStay {
  final int stayId;
  final String stayNo;

  final ActiveHotelGuest guest;
  final ActiveHotelRoom room;

  final String? checkIn;
  final String? expectedCheckOut;

  final int adults;
  final int children;

  final double roomRate;
  final String status;

  ActiveHotelStay({
    required this.stayId,
    required this.stayNo,
    required this.guest,
    required this.room,
    this.checkIn,
    this.expectedCheckOut,
    required this.adults,
    required this.children,
    required this.roomRate,
    required this.status,
  });

  factory ActiveHotelStay.fromJson(Map<String, dynamic> json) {
    return ActiveHotelStay(
      stayId: _toInt(json['stayId']),
      stayNo: json['stayNo']?.toString() ?? '',

      guest: ActiveHotelGuest.fromJson(json['guest'] ?? {}),

      room: ActiveHotelRoom.fromJson(json['room'] ?? {}),

      checkIn: json['checkIn']?.toString(),
      expectedCheckOut: json['expectedCheckOut']?.toString(),

      adults: _toInt(json['adults']),
      children: _toInt(json['children']),

      roomRate: _toDouble(json['roomRate']),

      status: json['status']?.toString() ?? 'CHECKED_IN',
    );
  }
}

class ActiveHotelGuest {
  final int guestId;
  final String? guestCode;
  final String? firstName;
  final String? lastName;
  final String? phone;

  ActiveHotelGuest({
    required this.guestId,
    this.guestCode,
    this.firstName,
    this.lastName,
    this.phone,
  });

  String get displayName {
    return [
      firstName,
      lastName,
    ].where((e) => e != null && e!.trim().isNotEmpty).join(' ');
  }

  factory ActiveHotelGuest.fromJson(Map<String, dynamic> json) {
    return ActiveHotelGuest(
      guestId: _toInt(json['guestId']),
      guestCode: json['guestCode']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class ActiveHotelRoom {
  final int roomId;
  final String? roomNo;
  final String? roomName;
  final String? roomTypeCode;
  final String? roomTypeName;

  ActiveHotelRoom({
    required this.roomId,
    this.roomNo,
    this.roomName,
    this.roomTypeCode,
    this.roomTypeName,
  });

  factory ActiveHotelRoom.fromJson(Map<String, dynamic> json) {
    return ActiveHotelRoom(
      roomId: _toInt(json['roomId']),
      roomNo: json['roomNo']?.toString(),
      roomName: json['roomName']?.toString(),
      roomTypeCode: json['roomTypeCode']?.toString(),
      roomTypeName: json['roomTypeName']?.toString(),
    );
  }
}

int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) return value;

  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}
