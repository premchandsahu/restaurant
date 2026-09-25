class HotelFolio {
  final int folioId;
  final String folioNo;

  final int stayId;
  final String stayNo;
  final String? stayStatus;

  final HotelFolioGuest guest;
  final HotelFolioRoom room;

  final String? checkIn;
  final String? expectedCheckOut;

  final String status;

  final double entryAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;

  final List<HotelFolioEntry> entries;
  final List<HotelFolioPayment> payments;
  HotelFolio({
    required this.folioId,
    required this.folioNo,
    required this.stayId,
    required this.stayNo,
    this.stayStatus,
    required this.guest,
    required this.room,
    this.checkIn,
    this.expectedCheckOut,
    required this.status,
    required this.entryAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.entries,
    this.payments = const [],
  });

  factory HotelFolio.fromJson(Map<String, dynamic> json) {
    final monetary = json['monetary'] as Map<String, dynamic>?;

    return HotelFolio(
      folioId: _toInt(json['folioId']),
      folioNo: json['folioNo']?.toString() ?? '',
      stayId: _toInt(json['stayId']),
      stayNo: json['stayNo']?.toString() ?? '',
      stayStatus: json['stayStatus']?.toString(),

      guest: HotelFolioGuest.fromJson(json['guest'] ?? {}),

      room: HotelFolioRoom.fromJson(json['room'] ?? {}),

      checkIn: json['checkIn']?.toString(),

      expectedCheckOut: json['expectedCheckOut']?.toString(),

      status: json['status']?.toString() ?? 'OPEN',

      entryAmount: _toDouble(monetary?['entryAmount']),

      taxAmount: _toDouble(monetary?['taxAmount']),

      totalAmount: _toDouble(monetary?['totalAmount'] ?? json['totalAmount']),

      paidAmount: _toDouble(monetary?['paidAmount'] ?? json['paidAmount']),

      balanceAmount: _toDouble(
        monetary?['balanceAmount'] ?? json['balanceAmount'],
      ),

      entries: (json['entries'] as List? ?? [])
          .map((e) => HotelFolioEntry.fromJson(e as Map<String, dynamic>))
          .toList(),

      payments: (json['payments'] as List? ?? [])
          .map((e) => HotelFolioPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HotelFolioGuest {
  final int guestId;
  final String? guestCode;
  final String? firstName;
  final String? lastName;
  final String? phone;

  HotelFolioGuest({
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

  factory HotelFolioGuest.fromJson(Map<String, dynamic> json) {
    return HotelFolioGuest(
      guestId: _toInt(json['guestId']),
      guestCode: json['guestCode']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class HotelFolioRoom {
  final int roomId;
  final String? roomNo;
  final String? roomName;

  HotelFolioRoom({required this.roomId, this.roomNo, this.roomName});

  factory HotelFolioRoom.fromJson(Map<String, dynamic> json) {
    return HotelFolioRoom(
      roomId: _toInt(json['roomId']),
      roomNo: json['roomNo']?.toString(),
      roomName: json['roomName']?.toString(),
    );
  }
}

class HotelFolioTax {
  final int folioEntryTaxId;
  final int taxGroupId;
  final int taxRateId;
  final String taxName;
  final String taxType;
  final double rate;
  final double taxableAmount;
  final double taxAmount;

  HotelFolioTax({
    required this.folioEntryTaxId,
    required this.taxGroupId,
    required this.taxRateId,
    required this.taxName,
    required this.taxType,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory HotelFolioTax.fromJson(Map<String, dynamic> json) {
    return HotelFolioTax(
      folioEntryTaxId: _toInt(json['folioEntryTaxId']),

      taxGroupId: _toInt(json['taxGroupId']),

      taxRateId: _toInt(json['taxRateId']),

      taxName: json['taxName']?.toString() ?? '',

      taxType: json['taxType']?.toString() ?? '',

      rate: _toDouble(json['rate']),

      taxableAmount: _toDouble(json['taxableAmount']),

      taxAmount: _toDouble(json['taxAmount']),
    );
  }
}

class HotelFolioEntry {
  final int folioEntryId;
  final String? entryDate;
  final String entryType;
  final String description;

  final double quantity;
  final double rate;
  final double amount;

  final String? sourceType;
  final int? sourceId;
  final int? referenceEntryId;

  final String status;
  final String? remarks;
  final List<HotelFolioTax> taxes;
  HotelFolioEntry({
    required this.folioEntryId,
    this.entryDate,
    required this.entryType,
    required this.description,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.sourceType,
    this.sourceId,
    this.referenceEntryId,
    required this.status,
    this.remarks,
    required this.taxes,
  });

  factory HotelFolioEntry.fromJson(Map<String, dynamic> json) {
    return HotelFolioEntry(
      folioEntryId: _toInt(json['folioEntryId']),

      entryDate: json['entryDate']?.toString(),

      entryType: json['entryType']?.toString() ?? 'OTHER',

      description: json['description']?.toString() ?? '',

      quantity: _toDouble(json['quantity']),

      rate: _toDouble(json['rate']),

      amount: _toDouble(json['amount']),

      sourceType: json['sourceType']?.toString(),

      sourceId: json['sourceId'] == null ? null : _toInt(json['sourceId']),

      referenceEntryId: json['referenceEntryId'] == null
          ? null
          : _toInt(json['referenceEntryId']),

      status: json['status']?.toString() ?? 'POSTED',

      remarks: json['remarks']?.toString(),
      taxes: (json['taxes'] as List? ?? [])
          .map((e) => HotelFolioTax.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HotelFolioPayment {
  final int paymentId;
  final int folioId;
  final int stayId;
  final int outletId;

  final String paymentMethod;
  final double amount;

  final String? referenceNo;
  final String? remarks;

  final String status;
  final DateTime? createdAt;

  HotelFolioPayment({
    required this.paymentId,
    required this.folioId,
    required this.stayId,
    required this.outletId,
    required this.paymentMethod,
    required this.amount,
    this.referenceNo,
    this.remarks,
    required this.status,
    this.createdAt,
  });

  factory HotelFolioPayment.fromJson(Map<String, dynamic> json) {
    return HotelFolioPayment(
      paymentId: _toInt(json['paymentId']),
      folioId: _toInt(json['folioId']),
      stayId: _toInt(json['stayId']),
      outletId: _toInt(json['outletId']),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      referenceNo: json['referenceNo']?.toString(),
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
    );
  }
}

// ---------------------------------------------------------
// Helpers
// ---------------------------------------------------------

int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) return value;

  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is double) return value;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}
