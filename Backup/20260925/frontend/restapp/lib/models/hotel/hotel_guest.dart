class HotelGuest {
  final int guestId;
  final String guestCode;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? address;
  final String? idType;
  final String? idNumber;

  const HotelGuest({
    required this.guestId,
    required this.guestCode,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.address,
    this.idType,
    this.idNumber,
  });

  factory HotelGuest.fromJson(Map<String, dynamic> json) {
    return HotelGuest(
      guestId: _toInt(json['guestId']),

      guestCode: json['guestCode']?.toString() ?? '',

      firstName: json['firstName']?.toString(),

      lastName: json['lastName']?.toString(),

      phone: json['phone']?.toString(),

      email: json['email']?.toString(),

      address: json['address']?.toString(),

      idType: json['idType']?.toString(),

      idNumber: json['idNumber']?.toString(),
    );
  }

  String get fullName {
    final parts = [firstName, lastName]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();

    return parts.isEmpty ? guestCode : parts.join(' ');
  }

  String get displayName {
    if (phone != null && phone!.trim().isNotEmpty) {
      return '$fullName • $phone';
    }

    return fullName;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
