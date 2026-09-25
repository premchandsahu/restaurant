class UserOutlet {
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
  final bool isDefault;

  UserOutlet({
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
    required this.isDefault,
  });

  factory UserOutlet.fromJson(Map<String, dynamic> json) {
    return UserOutlet(
      outletId: json['outlet_id'],
      outletUuid: json['outlet_uuid'] ?? '',
      outletCode: json['outlet_code'] ?? '',
      outletName: json['outlet_name'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      address1: json['address1'],
      address2: json['address2'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}
