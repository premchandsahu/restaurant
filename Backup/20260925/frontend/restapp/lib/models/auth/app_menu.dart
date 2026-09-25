class AppMenu {
  final int menuId;
  final int? parentMenuId;
  final String menuCode;
  final String menuName;
  final String moduleName;
  final String? iconName;
  final String? routeName;
  final String? requiredPermission;
  final int displayOrder;
  final bool isGroup;
  final List<AppMenu> children;

  const AppMenu({
    required this.menuId,
    required this.parentMenuId,
    required this.menuCode,
    required this.menuName,
    required this.moduleName,
    required this.iconName,
    required this.routeName,
    required this.requiredPermission,
    required this.displayOrder,
    required this.isGroup,
    required this.children,
  });

  factory AppMenu.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List? ?? [];

    return AppMenu(
      menuId: json['menuId'] ?? 0,
      parentMenuId: json['parentMenuId'],
      menuCode: json['menuCode'] ?? '',
      menuName: json['menuName'] ?? '',
      moduleName: json['moduleName'] ?? '',
      iconName: json['iconName'],
      routeName: json['routeName'],
      requiredPermission: json['requiredPermission'],
      displayOrder: _toInt(json['displayOrder']),
      isGroup: json['isGroup'] == true || json['isGroup'] == 1,
      children: childrenJson
          .map((e) => AppMenu.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
