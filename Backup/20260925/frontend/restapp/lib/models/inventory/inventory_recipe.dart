import 'inventory_raw_material.dart';

class InventoryRecipeItem {
  final int? recipeItemId;
  final int rawMaterialId;
  final String materialCode;
  final String materialName;
  final double qty;
  final int unitId;
  final String unitCode;
  final String unitName;
  final int stockUnitId;
  final String stockUnitCode;
  final String stockUnitName;
  final double wastagePercent;

  const InventoryRecipeItem({
    this.recipeItemId,
    required this.rawMaterialId,
    required this.materialCode,
    required this.materialName,
    required this.qty,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.stockUnitId,
    required this.stockUnitCode,
    required this.stockUnitName,
    required this.wastagePercent,
  });

  factory InventoryRecipeItem.fromJson(Map<String, dynamic> json) {
    return InventoryRecipeItem(
      recipeItemId: _nullableInt(json['recipeItemId'] ?? json['recipe_item_id']),
      rawMaterialId: _int(json['rawMaterialId'] ?? json['raw_material_id']),
      materialCode: (json['materialCode'] ?? json['material_code'])?.toString() ?? '',
      materialName: (json['materialName'] ?? json['material_name'])?.toString() ?? '',
      qty: _double(json['qty']),
      unitId: _int(json['unitId'] ?? json['unit_id']),
      unitCode: (json['unitCode'] ?? json['unit_code'])?.toString() ?? '',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ?? '',
      stockUnitId: _int(json['stockUnitId'] ?? json['stock_unit_id']),
      stockUnitCode: (json['stockUnitCode'] ?? json['stock_unit_code'])?.toString() ?? '',
      stockUnitName: (json['stockUnitName'] ?? json['stock_unit_name'])?.toString() ?? '',
      wastagePercent: _double(json['wastagePercent'] ?? json['wastage_percent']),
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _nullableInt(dynamic value) => value == null ? null : int.tryParse(value.toString());

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
}

class InventoryRecipe {
  final int recipeId;
  final String recipeUuid;
  final int menuItemId;
  final String itemCode;
  final String itemName;
  final int? variantId;
  final String? variantCode;
  final String? variantName;
  final String recipeName;
  final int versionNo;
  final String effectiveFrom;
  final String? effectiveTo;
  final double yieldQty;
  final int? yieldUnitId;
  final String? yieldUnitCode;
  final String? yieldUnitName;
  final bool isActive;
  final List<InventoryRecipeItem> items;

  const InventoryRecipe({
    required this.recipeId,
    required this.recipeUuid,
    required this.menuItemId,
    required this.itemCode,
    required this.itemName,
    this.variantId,
    this.variantCode,
    this.variantName,
    required this.recipeName,
    required this.versionNo,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.yieldQty,
    this.yieldUnitId,
    this.yieldUnitCode,
    this.yieldUnitName,
    required this.isActive,
    required this.items,
  });

  factory InventoryRecipe.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return InventoryRecipe(
      recipeId: _int(json['recipeId'] ?? json['recipe_id']),
      recipeUuid: (json['recipeUuid'] ?? json['recipe_uuid'])?.toString() ?? '',
      menuItemId: _int(json['menuItemId'] ?? json['menu_item_id']),
      itemCode: (json['itemCode'] ?? json['item_code'])?.toString() ?? '',
      itemName: (json['itemName'] ?? json['item_name'])?.toString() ?? '',
      variantId: _nullableInt(json['variantId'] ?? json['variant_id']),
      variantCode: (json['variantCode'] ?? json['variant_code'])?.toString(),
      variantName: (json['variantName'] ?? json['variant_name'])?.toString(),
      recipeName: (json['recipeName'] ?? json['recipe_name'])?.toString() ?? '',
      versionNo: _int(json['versionNo'] ?? json['version_no'] ?? 1),
      effectiveFrom: (json['effectiveFrom'] ?? json['effective_from'])?.toString() ?? '',
      effectiveTo: (json['effectiveTo'] ?? json['effective_to'])?.toString(),
      yieldQty: _double(json['yieldQty'] ?? json['yield_qty']),
      yieldUnitId: _nullableInt(json['yieldUnitId'] ?? json['yield_unit_id']),
      yieldUnitCode: (json['yieldUnitCode'] ?? json['yield_unit_code'])?.toString(),
      yieldUnitName: (json['yieldUnitName'] ?? json['yield_unit_name'])?.toString(),
      isActive: _bool(json['isActive'] ?? json['is_active']),
      items: rawItems is List
          ? rawItems
              .map((e) => InventoryRecipeItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  String get targetName {
    if (variantName == null || variantName!.trim().isEmpty) {
      return itemName;
    }
    return '$itemName - $variantName';
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _nullableInt(dynamic value) => value == null ? null : int.tryParse(value.toString());

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == '1' || text == 'true';
  }
}

class RecipeTarget {
  final int menuItemId;
  final String itemCode;
  final String itemName;
  final int? variantId;
  final String? variantCode;
  final String? variantName;
  final String coverageType;
  final String coverageStatus;
  final InventoryRecipe? recipe;

  const RecipeTarget({
    required this.menuItemId,
    required this.itemCode,
    required this.itemName,
    this.variantId,
    this.variantCode,
    this.variantName,
    required this.coverageType,
    required this.coverageStatus,
    this.recipe,
  });

  factory RecipeTarget.fromJson(Map<String, dynamic> json) {
    final rawRecipe = json['recipe'];

    return RecipeTarget(
      menuItemId: _int(json['menuItemId']),
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      variantId: _nullableInt(json['variantId']),
      variantCode: json['variantCode']?.toString(),
      variantName: json['variantName']?.toString(),
      coverageType: json['coverageType']?.toString() ?? '',
      coverageStatus: json['coverageStatus']?.toString() ?? 'MISSING',
      recipe: rawRecipe is Map
          ? InventoryRecipe.fromJson(Map<String, dynamic>.from(rawRecipe))
          : null,
    );
  }

  String get displayName => variantName == null ? itemName : '$itemName - $variantName';

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _nullableInt(dynamic value) => value == null ? null : int.tryParse(value.toString());
}

class RecipeCoverageSummary {
  final int menuItemCount;
  final int defaultRecipeTargets;
  final int variantRecipeTargets;
  final int configuredExactCount;
  final int fallbackToDefaultCount;
  final int missingCount;
  final bool coverageComplete;

  const RecipeCoverageSummary({
    required this.menuItemCount,
    required this.defaultRecipeTargets,
    required this.variantRecipeTargets,
    required this.configuredExactCount,
    required this.fallbackToDefaultCount,
    required this.missingCount,
    required this.coverageComplete,
  });

  factory RecipeCoverageSummary.fromJson(Map<String, dynamic> json) {
    return RecipeCoverageSummary(
      menuItemCount: _int(json['menuItemCount']),
      defaultRecipeTargets: _int(json['defaultRecipeTargets']),
      variantRecipeTargets: _int(json['variantRecipeTargets']),
      configuredExactCount: _int(json['configuredExactCount']),
      fallbackToDefaultCount: _int(json['fallbackToDefaultCount']),
      missingCount: _int(json['missingCount']),
      coverageComplete: json['coverageComplete'] == true,
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
