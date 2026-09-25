class InventoryUnit {
  final int unitId;
  final String unitCode;
  final String unitName;
  final int decimalPlaces;

  const InventoryUnit({
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.decimalPlaces,
  });

  factory InventoryUnit.fromJson(Map<String, dynamic> json) {
    return InventoryUnit(
      unitId: _int(json['unitId'] ?? json['unit_id']),
      unitCode: (json['unitCode'] ?? json['unit_code'])?.toString() ?? '',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ?? '',
      decimalPlaces: _int(json['decimalPlaces'] ?? json['decimal_places']),
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}

class InventoryRawMaterial {
  final int rawMaterialId;

  final int? inventoryCategoryId;
  final String? categoryCode;
  final String? categoryName;
  final String materialCode;
  final String materialName;
  final int unitId;
  final String unitCode;
  final String unitName;
  final int decimalPlaces;
  final double purchaseRate;
  final double reorderLevel;
  final double reorderQty;
  final int? taxGroupId;
  final String? taxGroupCode;
  final String? taxGroupName;
  final bool isActive;
  const InventoryRawMaterial({
    required this.rawMaterialId,
    required this.inventoryCategoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.materialCode,
    required this.materialName,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.decimalPlaces,
    required this.purchaseRate,
    required this.reorderLevel,
    required this.reorderQty,

    this.taxGroupId,
    this.taxGroupCode,
    this.taxGroupName,
    required this.isActive,
  });

  factory InventoryRawMaterial.fromJson(Map<String, dynamic> json) {
    return InventoryRawMaterial(
      rawMaterialId: _int(json['rawMaterialId'] ?? json['raw_material_id']),

      inventoryCategoryId: _nullableInt(
        json['inventoryCategoryId'] ?? json['inventory_category_id'],
      ),

      categoryCode: (json['categoryCode'] ?? json['category_code'])?.toString(),

      categoryName: (json['categoryName'] ?? json['category_name'])?.toString(),
      materialCode:
          (json['materialCode'] ?? json['material_code'])?.toString() ?? '',
      materialName:
          (json['materialName'] ?? json['material_name'])?.toString() ?? '',
      unitId: _int(json['unitId'] ?? json['unit_id']),
      unitCode: (json['unitCode'] ?? json['unit_code'])?.toString() ?? '',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ?? '',
      decimalPlaces: _int(json['decimalPlaces'] ?? json['decimal_places']),
      purchaseRate: _double(json['purchaseRate'] ?? json['purchase_rate']),

      reorderLevel: _double(json['reorderLevel'] ?? json['reorder_level']),

      reorderQty: _double(json['reorderQty'] ?? json['reorder_qty']),
      taxGroupId: json['taxGroupId'] == null ? null : _int(json['taxGroupId']),

      taxGroupCode: (json['taxGroupCode'] ?? json['tax_group_code'])
          ?.toString(),

      taxGroupName: (json['taxGroupName'] ?? json['tax_group_name'])
          ?.toString(),
      isActive: _bool(json['isActive'] ?? json['is_active']),
    );
  }
  static int? _nullableInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static bool _bool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().toLowerCase() == 'true' ||
        value?.toString() == '1';
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
