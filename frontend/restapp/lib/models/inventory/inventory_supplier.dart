class InventorySupplier {
  final int supplierId;
  final String supplierUuid;
  final String supplierCode;
  final String supplierName;

  final String? mobile;
  final String? email;
  final String? gstin;

  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? pincode;

  final double openingBalance;
  final bool isActive;

  const InventorySupplier({
    required this.supplierId,
    required this.supplierUuid,
    required this.supplierCode,
    required this.supplierName,
    required this.mobile,
    required this.email,
    required this.gstin,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.openingBalance,
    required this.isActive,
  });

  factory InventorySupplier.fromJson(Map<String, dynamic> json) {
    return InventorySupplier(
      supplierId: _int(json['supplierId']),
      supplierUuid: json['supplierUuid']?.toString() ?? '',
      supplierCode: json['supplierCode']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      gstin: json['gstin']?.toString(),
      address1: json['address1']?.toString(),
      address2: json['address2']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      openingBalance: _double(json['openingBalance']),
      isActive: json['isActive'] == true || json['isActive'] == 1,
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
