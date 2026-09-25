class CustomerMenu {
  final CustomerMenuSession customerSession;
  final CustomerMenuTable table;
  final List<MenuCategory> menu;

  CustomerMenu({
    required this.customerSession,
    required this.table,
    required this.menu,
  });

  factory CustomerMenu.fromJson(Map<String, dynamic> json) {
    return CustomerMenu(
      customerSession: CustomerMenuSession.fromJson(
        json['customer_session'] ?? {},
      ),
      table: CustomerMenuTable.fromJson(json['table'] ?? {}),
      menu: (json['menu'] as List? ?? [])
          .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerMenuSession {
  final int? customerSessionId;
  final String? customerName;
  final String? customerPhone;

  CustomerMenuSession({
    this.customerSessionId,
    this.customerName,
    this.customerPhone,
  });

  factory CustomerMenuSession.fromJson(Map<String, dynamic> json) {
    return CustomerMenuSession(
      customerSessionId: _toInt(json['customer_session_id']),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
    );
  }
}

class CustomerMenuTable {
  final int? tableId;
  final String? tableCode;
  final String? tableName;
  final int? capacity;

  CustomerMenuTable({
    this.tableId,
    this.tableCode,
    this.tableName,
    this.capacity,
  });

  factory CustomerMenuTable.fromJson(Map<String, dynamic> json) {
    return CustomerMenuTable(
      tableId: _toInt(json['table_id']),
      tableCode: json['table_code']?.toString(),
      tableName: json['table_name']?.toString(),
      capacity: _toInt(json['capacity']),
    );
  }
}

class MenuCategory {
  final int categoryId;
  final String? categoryCode;
  final String? categoryName;
  final int displayOrder;
  final List<MenuItem> items;

  MenuCategory({
    required this.categoryId,
    this.categoryCode,
    this.categoryName,
    this.displayOrder = 0,
    this.items = const [],
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      categoryId: _toInt(json['category_id']) ?? 0,
      categoryCode: json['category_code']?.toString(),
      categoryName: json['category_name']?.toString(),
      displayOrder: _toInt(json['display_order']) ?? 0,
      items: (json['items'] as List? ?? [])
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MenuItem {
  final int menuItemId;
  final String? itemCode;
  final String? itemName;
  final String? description;
  final String? itemType;
  final double baseRate;

  final bool isVeg;
  final bool isEgg;
  final bool isSpicy;

  final String? imageUrl;

  final List<MenuVariant> variants;
  final List<ModifierGroup> modifierGroups;

  MenuItem({
    required this.menuItemId,
    this.itemCode,
    this.itemName,
    this.description,
    this.itemType,
    this.baseRate = 0,
    this.isVeg = false,
    this.isEgg = false,
    this.isSpicy = false,
    this.imageUrl,
    this.variants = const [],
    this.modifierGroups = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      menuItemId: _toInt(json['menu_item_id']) ?? 0,

      itemCode: json['item_code']?.toString(),

      itemName: json['item_name']?.toString(),

      description: json['description']?.toString(),

      itemType: json['item_type']?.toString(),

      baseRate: _toDouble(json['base_rate']),

      isVeg: _toBool(json['is_veg']),

      isEgg: _toBool(json['is_egg']),

      isSpicy: _toBool(json['is_spicy']),

      imageUrl: json['image_url']?.toString(),

      variants: (json['variants'] as List? ?? [])
          .map((e) => MenuVariant.fromJson(e as Map<String, dynamic>))
          .toList(),

      modifierGroups: (json['modifierGroups'] as List? ?? [])
          .map((e) => ModifierGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasVariants => variants.isNotEmpty;

  bool get hasModifiers => modifierGroups.isNotEmpty;
}

class MenuVariant {
  final int variantId;
  final String? variantCode;
  final String? variantName;
  final double rate;
  final bool isDefault;

  MenuVariant({
    required this.variantId,
    this.variantCode,
    this.variantName,
    this.rate = 0,
    this.isDefault = false,
  });

  factory MenuVariant.fromJson(Map<String, dynamic> json) {
    return MenuVariant(
      variantId: _toInt(json['variant_id']) ?? 0,

      variantCode: json['variant_code']?.toString(),

      variantName: json['variant_name']?.toString(),

      rate: _toDouble(json['rate']),

      isDefault: _toBool(json['is_default']),
    );
  }
}

class ModifierGroup {
  final int modifierGroupId;
  final String? groupName;
  final String? selectionType;

  final int minSelection;
  final int maxSelection;

  final List<ModifierOption> options;

  ModifierGroup({
    required this.modifierGroupId,
    this.groupName,
    this.selectionType,
    this.minSelection = 0,
    this.maxSelection = 0,
    this.options = const [],
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final groupId = _toInt(json['modifier_group_id']) ?? 0;

    return ModifierGroup(
      modifierGroupId: groupId,

      groupName: json['group_name']?.toString(),

      selectionType: json['selection_type']?.toString(),

      minSelection: _toInt(json['min_selection']) ?? 0,

      maxSelection: _toInt(json['max_selection']) ?? 0,

      options: (json['options'] as List? ?? [])
          .map(
            (e) => ModifierOption.fromJson(
              e as Map<String, dynamic>,
              modifierGroupId: groupId,
            ),
          )
          .toList(),
    );
  }

  bool get isSingle => selectionType == 'SINGLE';

  bool get isMultiple => selectionType == 'MULTIPLE';

  bool get isRequired => minSelection > 0;
}

class ModifierOption {
  final int modifierOptionId;
  final int modifierGroupId;
  final String? optionName;
  final double extraRate;

  ModifierOption({
    required this.modifierOptionId,
    required this.modifierGroupId,
    this.optionName,
    this.extraRate = 0,
  });

  factory ModifierOption.fromJson(
    Map<String, dynamic> json, {
    required int modifierGroupId,
  }) {
    return ModifierOption(
      modifierOptionId: _toInt(json['modifier_option_id']) ?? 0,
      modifierGroupId: modifierGroupId,
      optionName: json['option_name']?.toString(),
      extraRate: _toDouble(json['extra_rate']),
    );
  }
}

// ---------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------

int? _toInt(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

bool _toBool(dynamic value) {
  if (value == true || value == 1) {
    return true;
  }

  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }

  return false;
}
