class InventoryStockLedger {
  final int outletId;
  final String fromDate;
  final String toDate;

  final InventoryStockLedgerMaterial rawMaterial;
  final InventoryStockLedgerSummary summary;

  final List<InventoryStockLedgerTransaction> transactions;

  const InventoryStockLedger({
    required this.outletId,
    required this.fromDate,
    required this.toDate,
    required this.rawMaterial,
    required this.summary,
    required this.transactions,
  });

  factory InventoryStockLedger.fromJson(Map<String, dynamic> json) {
    return InventoryStockLedger(
      outletId: _int(json['outletId']),

      fromDate: json['fromDate']?.toString() ?? '',

      toDate: json['toDate']?.toString() ?? '',

      rawMaterial: InventoryStockLedgerMaterial.fromJson(
        Map<String, dynamic>.from(json['rawMaterial'] as Map? ?? {}),
      ),

      summary: InventoryStockLedgerSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),

      transactions: (json['transactions'] as List? ?? const [])
          .map(
            (e) => InventoryStockLedgerTransaction.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================
// RAW MATERIAL
// ============================================================

class InventoryStockLedgerMaterial {
  final int rawMaterialId;
  final String materialCode;
  final String materialName;

  final int unitId;
  final String unitCode;
  final String unitName;

  final int decimalPlaces;

  const InventoryStockLedgerMaterial({
    required this.rawMaterialId,
    required this.materialCode,
    required this.materialName,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.decimalPlaces,
  });

  factory InventoryStockLedgerMaterial.fromJson(Map<String, dynamic> json) {
    return InventoryStockLedgerMaterial(
      rawMaterialId: _int(json['rawMaterialId']),

      materialCode: json['materialCode']?.toString() ?? '',

      materialName: json['materialName']?.toString() ?? '',

      unitId: _int(json['unitId']),

      unitCode: json['unitCode']?.toString() ?? '',

      unitName: json['unitName']?.toString() ?? '',

      decimalPlaces: _int(json['decimalPlaces']),
    );
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================
// SUMMARY
// ============================================================

class InventoryStockLedgerSummary {
  final double openingQty;
  final double periodInQty;
  final double periodOutQty;
  final double closingQty;
  final bool negativeStock;

  const InventoryStockLedgerSummary({
    required this.openingQty,
    required this.periodInQty,
    required this.periodOutQty,
    required this.closingQty,
    required this.negativeStock,
  });

  factory InventoryStockLedgerSummary.fromJson(Map<String, dynamic> json) {
    return InventoryStockLedgerSummary(
      openingQty: _double(json['openingQty']),

      periodInQty: _double(json['periodInQty']),

      periodOutQty: _double(json['periodOutQty']),

      closingQty: _double(json['closingQty']),

      negativeStock:
          json['negativeStock'] == true ||
          json['negativeStock'] == 1 ||
          json['negativeStock']?.toString() == 'true',
    );
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================
// TRANSACTION
// ============================================================

class InventoryStockLedgerTransaction {
  final String date;

  final String sourceType;

  final int sourceId;
  final int sourceLineId;

  final String? referenceNo;
  final String? description;

  final double quantityIn;
  final double quantityOut;

  final double rate;
  final double balanceQty;

  final String? remarks;

  const InventoryStockLedgerTransaction({
    required this.date,
    required this.sourceType,
    required this.sourceId,
    required this.sourceLineId,
    required this.referenceNo,
    required this.description,
    required this.quantityIn,
    required this.quantityOut,
    required this.rate,
    required this.balanceQty,
    required this.remarks,
  });

  factory InventoryStockLedgerTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryStockLedgerTransaction(
      date: json['date']?.toString() ?? '',

      sourceType: json['sourceType']?.toString() ?? '',

      sourceId: _int(json['sourceId']),

      sourceLineId: _int(json['sourceLineId']),

      referenceNo: json['referenceNo']?.toString(),

      description: json['description']?.toString(),

      quantityIn: _double(json['quantityIn']),

      quantityOut: _double(json['quantityOut']),

      rate: _double(json['rate']),

      balanceQty: _double(json['balanceQty']),

      remarks: json['remarks']?.toString(),
    );
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
