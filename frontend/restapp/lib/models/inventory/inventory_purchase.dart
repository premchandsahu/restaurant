class InventoryPurchase {
  final int purchaseId;
  final String purchaseUuid;
  final int outletId;
  final int supplierId;
  final String supplierCode;
  final String supplierName;
  final String purchaseNo;
  final String purchaseDate;
  final String status;
  final String? supplierInvoiceNo;

  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;

  final double paidAmount;
  final double balanceAmount;

  final String? remarks;

  final int? createdBy;

  final List<InventoryPurchaseItem> items;

  InventoryPurchase({
    required this.purchaseId,
    required this.purchaseUuid,
    required this.outletId,
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.purchaseNo,
    required this.purchaseDate,
    required this.status,
    required this.supplierInvoiceNo,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.balanceAmount,
    required this.remarks,
    required this.createdBy,
    required this.items,
  });

  factory InventoryPurchase.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List? ?? const [];

    return InventoryPurchase(
      purchaseId: _int(json['purchaseId']),
      purchaseUuid: json['purchaseUuid']?.toString() ?? '',
      outletId: _int(json['outletId']),
      supplierId: _int(json['supplierId']),
      supplierCode: json['supplierCode']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? '',
      purchaseNo: json['purchaseNo']?.toString() ?? '',
      purchaseDate: json['purchaseDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      supplierInvoiceNo: json['supplierInvoiceNo']?.toString(),
      subtotal: _double(json['subtotal']),
      taxAmount: _double(json['taxAmount']),
      discountAmount: _double(json['discountAmount']),
      grandTotal: _double(json['grandTotal']),
      paidAmount: _double(json['paidAmount']),
      balanceAmount: _double(json['balanceAmount']),
      remarks: json['remarks']?.toString(),
      createdBy: json['createdBy'] == null ? null : _int(json['createdBy']),
      items: rows
          .map(
            (e) => InventoryPurchaseItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
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

class InventoryPurchaseItem {
  final int purchaseItemId;
  final int purchaseId;

  final int rawMaterialId;
  final String materialCode;
  final String materialName;

  final String? batchNo;
  final String? expiryDate;

  final double qty;

  final int unitId;
  final String unitCode;
  final String unitName;

  final double conversionFactor;
  final double baseQty;

  final double rate;
  final double discountAmount;

  final int? taxGroupId;
  final double taxAmount;
  final double taxableAmount;
  final double amount;

  final List<InventoryPurchaseItemTax> taxes;

  InventoryPurchaseItem({
    required this.purchaseItemId,
    required this.purchaseId,
    required this.rawMaterialId,
    required this.materialCode,
    required this.materialName,
    required this.batchNo,
    required this.expiryDate,
    required this.qty,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.conversionFactor,
    required this.baseQty,
    required this.rate,
    required this.discountAmount,
    required this.taxGroupId,
    required this.taxAmount,
    required this.taxableAmount,
    required this.amount,
    required this.taxes,
  });

  factory InventoryPurchaseItem.fromJson(Map<String, dynamic> json) {
    final rows = json['taxes'] as List? ?? const [];

    return InventoryPurchaseItem(
      purchaseItemId: _int(json['purchaseItemId']),
      purchaseId: _int(json['purchaseId']),
      rawMaterialId: _int(json['rawMaterialId']),
      materialCode: json['materialCode']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? '',
      batchNo: json['batchNo']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      qty: _double(json['qty']),
      unitId: _int(json['unitId']),
      unitCode: json['unitCode']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      conversionFactor: _double(json['conversionFactor']),
      baseQty: _double(json['baseQty']),
      rate: _double(json['rate']),
      discountAmount: _double(json['discountAmount']),
      taxGroupId: json['taxGroupId'] == null ? null : _int(json['taxGroupId']),
      taxAmount: _double(json['taxAmount']),
      taxableAmount: _double(json['taxableAmount']),
      amount: _double(json['amount']),
      taxes: rows
          .map(
            (e) =>
                InventoryPurchaseItemTax.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
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

class InventoryPurchaseItemTax {
  final int purchaseItemTaxId;
  final int purchaseItemId;
  final int taxGroupId;
  final int taxRateId;

  final String taxName;
  final String taxType;

  final double rate;
  final double taxableAmount;
  final double taxAmount;

  InventoryPurchaseItemTax({
    required this.purchaseItemTaxId,
    required this.purchaseItemId,
    required this.taxGroupId,
    required this.taxRateId,
    required this.taxName,
    required this.taxType,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory InventoryPurchaseItemTax.fromJson(Map<String, dynamic> json) {
    return InventoryPurchaseItemTax(
      purchaseItemTaxId: _int(json['purchaseItemTaxId']),
      purchaseItemId: _int(json['purchaseItemId']),
      taxGroupId: _int(json['taxGroupId']),
      taxRateId: _int(json['taxRateId']),
      taxName: json['taxName']?.toString() ?? '',
      taxType: json['taxType']?.toString() ?? '',
      rate: _double(json['rate']),
      taxableAmount: _double(json['taxableAmount']),
      taxAmount: _double(json['taxAmount']),
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
