class InventorySupplierPayment {
  final int paymentId;
  final int supplierId;
  final int outletId;

  final String paymentDate;
  final String paymentMode;

  final double amount;

  final String? referenceNo;
  final int? paidBy;
  final String? remarks;

  final String status;
  final String? createdAt;

  final double allocatedAmount;
  final double unallocatedAmount;

  final List<InventorySupplierPaymentAllocation> allocations;

  const InventorySupplierPayment({
    required this.paymentId,
    required this.supplierId,
    required this.outletId,
    required this.paymentDate,
    required this.paymentMode,
    required this.amount,
    required this.referenceNo,
    required this.paidBy,
    required this.remarks,
    required this.status,
    required this.createdAt,
    required this.allocatedAmount,
    required this.unallocatedAmount,
    required this.allocations,
  });

  factory InventorySupplierPayment.fromJson(Map<String, dynamic> json) {
    final allocationRows = json['allocations'] as List? ?? const [];

    return InventorySupplierPayment(
      paymentId: _toInt(json['paymentId']),
      supplierId: _toInt(json['supplierId']),
      outletId: _toInt(json['outletId']),
      paymentDate: json['paymentDate']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      referenceNo: _toNullableString(json['referenceNo']),
      paidBy: json['paidBy'] == null ? null : _toInt(json['paidBy']),
      remarks: _toNullableString(json['remarks']),
      status: json['status']?.toString() ?? '',
      createdAt: _toNullableString(json['createdAt']),
      allocatedAmount: _toDouble(json['allocatedAmount']),
      unallocatedAmount: _toDouble(json['unallocatedAmount']),
      allocations: allocationRows
          .map(
            (e) => InventorySupplierPaymentAllocation.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }
}

class InventorySupplierPaymentAllocation {
  final int allocationId;
  final int purchaseId;
  final String? purchaseNo;
  final String? purchaseDate;
  final double allocatedAmount;

  const InventorySupplierPaymentAllocation({
    required this.allocationId,
    required this.purchaseId,
    required this.purchaseNo,
    required this.purchaseDate,
    required this.allocatedAmount,
  });

  factory InventorySupplierPaymentAllocation.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventorySupplierPaymentAllocation(
      allocationId: _toInt(json['allocationId']),
      purchaseId: _toInt(json['purchaseId']),
      purchaseNo: _toNullableString(json['purchaseNo']),
      purchaseDate: _toNullableString(json['purchaseDate']),
      allocatedAmount: _toDouble(json['allocatedAmount']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }
}
