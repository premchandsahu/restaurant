class InventoryStockBalance {
  final int rawMaterialId;
  final String materialCode;
  final String materialName;

  final int unitId;
  final String unitCode;
  final String unitName;

  final double openingQty;
  final double purchaseQty;
  final double adjustmentInQty;
  final double adjustmentOutQty;
  final double consumptionQty;
  final double recipeWastageQty;
  final double wastageQty;
  final double damageQty;
  final double closingQty;

  final bool negativeStock;

  const InventoryStockBalance({
    required this.rawMaterialId,
    required this.materialCode,
    required this.materialName,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.openingQty,
    required this.purchaseQty,
    required this.adjustmentInQty,
    required this.adjustmentOutQty,
    required this.consumptionQty,
    required this.recipeWastageQty,
    required this.wastageQty,
    required this.damageQty,
    required this.closingQty,
    required this.negativeStock,
  });

  factory InventoryStockBalance.fromJson(Map<String, dynamic> json) {
    return InventoryStockBalance(
      rawMaterialId: _int(json['rawMaterialId']),

      materialCode: json['materialCode']?.toString() ?? '',

      materialName: json['materialName']?.toString() ?? '',

      unitId: _int(json['unitId']),

      unitCode: json['unitCode']?.toString() ?? '',

      unitName: json['unitName']?.toString() ?? '',

      openingQty: _double(json['openingQty']),

      purchaseQty: _double(json['purchaseQty']),

      adjustmentInQty: _double(json['adjustmentInQty']),

      adjustmentOutQty: _double(json['adjustmentOutQty']),

      consumptionQty: _double(json['consumptionQty']),

      recipeWastageQty: _double(json['recipeWastageQty']),

      wastageQty: _double(json['wastageQty']),

      damageQty: _double(json['damageQty']),

      closingQty: _double(json['closingQty']),

      negativeStock:
          json['negativeStock'] == true ||
          json['negativeStock'] == 1 ||
          json['negativeStock']?.toString() == 'true',
    );
  }

  double get totalInQty {
    return purchaseQty + adjustmentInQty;
  }

  double get totalOutQty {
    return adjustmentOutQty +
        consumptionQty +
        recipeWastageQty +
        wastageQty +
        damageQty;
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
