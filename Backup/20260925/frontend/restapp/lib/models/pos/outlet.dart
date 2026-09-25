class Outlet {
  final int outletId;
  final String outletUuid;
  final String outletCode;
  final String outletName;

  final String? gstin;
  final String? phone;
  final String? email;

  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? pincode;

  Outlet({
    required this.outletId,
    required this.outletUuid,
    required this.outletCode,
    required this.outletName,
    this.gstin,
    this.phone,
    this.email,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.pincode,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      outletId: _toInt(json['outlet_id']),
      outletUuid: json['outlet_uuid']?.toString() ?? '',
      outletCode: json['outlet_code']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? '',

      gstin: json['gstin']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),

      address1: json['address1']?.toString(),
      address2: json['address2']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
