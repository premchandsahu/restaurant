class InventoryStockAdjustment {
  final int stockAdjustmentId;
  final String adjustmentUuid;
  final int outletId;
  final String adjustmentNo;
  final String adjustmentDate;
  final String adjustmentType;
  final String? reason;
  final int createdBy;

  // Available in list response
  final int itemCount;
  final double totalAmount;

  // Available in detail/create response
  final List<InventoryStockAdjustmentItem> items;

  InventoryStockAdjustment({
    required this.stockAdjustmentId,
    required this.adjustmentUuid,
    required this.outletId,
    required this.adjustmentNo,
    required this.adjustmentDate,
    required this.adjustmentType,
    required this.reason,
    required this.createdBy,
    this.itemCount = 0,
    this.totalAmount = 0,
    this.items = const [],
  });

  factory InventoryStockAdjustment.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    return InventoryStockAdjustment(
      stockAdjustmentId: _int(json['stockAdjustmentId']),
      adjustmentUuid: json['adjustmentUuid']?.toString() ?? '',
      outletId: _int(json['outletId']),
      adjustmentNo: json['adjustmentNo']?.toString() ?? '',
      adjustmentDate: json['adjustmentDate']?.toString() ?? '',
      adjustmentType: json['adjustmentType']?.toString() ?? '',
      reason: json['reason']?.toString(),
      createdBy: _int(json['createdBy']),
      itemCount: _int(json['itemCount']),
      totalAmount: _double(json['totalAmount']),
      items: rawItems
          .map(
            (e) => InventoryStockAdjustmentItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static int _int(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================
// STOCK ADJUSTMENT ITEM
// ============================================================

class InventoryStockAdjustmentItem {
  final int stockAdjustmentItemId;
  final int stockAdjustmentId;

  final int rawMaterialId;
  final String materialCode;
  final String materialName;

  final double qty;

  final int unitId;
  final String unitCode;
  final String unitName;

  final double rate;
  final double amount;

  // Available in create response
  final double qtyIn;
  final double qtyOut;
  final double balanceQty;
  final double averageRate;
  final int? stockTransactionId;

  InventoryStockAdjustmentItem({
    required this.stockAdjustmentItemId,
    required this.stockAdjustmentId,
    required this.rawMaterialId,
    required this.materialCode,
    required this.materialName,
    required this.qty,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.rate,
    required this.amount,
    this.qtyIn = 0,
    this.qtyOut = 0,
    this.balanceQty = 0,
    this.averageRate = 0,
    this.stockTransactionId,
  });

  factory InventoryStockAdjustmentItem.fromJson(Map<String, dynamic> json) {
    return InventoryStockAdjustmentItem(
      stockAdjustmentItemId: _int(json['stockAdjustmentItemId']),
      stockAdjustmentId: _int(json['stockAdjustmentId']),
      rawMaterialId: _int(json['rawMaterialId']),
      materialCode: json['materialCode']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? '',
      qty: _double(json['qty']),
      unitId: _int(json['unitId']),
      unitCode: json['unitCode']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      rate: _double(json['rate']),
      amount: _double(json['amount']),
      qtyIn: _double(json['qtyIn']),
      qtyOut: _double(json['qtyOut']),
      balanceQty: _double(json['balanceQty']),
      averageRate: _double(json['averageRate']),
      stockTransactionId: json['stockTransactionId'] == null
          ? null
          : _int(json['stockTransactionId']),
    );
  }

  static int _int(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
