import 'pos_modifier_option.dart';

class PosModifierGroup {
  final int modifierGroupId;
  final String groupName;

  final String selectionType;

  final int minSelection;
  final int maxSelection;

  final int displayOrder;

  final List<PosModifierOption> options;

  const PosModifierGroup({
    required this.modifierGroupId,
    required this.groupName,
    required this.selectionType,
    required this.minSelection,
    required this.maxSelection,
    required this.displayOrder,
    this.options = const [],
  });

  factory PosModifierGroup.fromJson(Map<String, dynamic> json) {
    return PosModifierGroup(
      modifierGroupId: _int(json['modifier_group_id']),

      groupName: json['group_name']?.toString() ?? '',

      selectionType: json['selection_type']?.toString() ?? 'SINGLE',

      minSelection: _int(json['min_selection']),

      maxSelection: _int(json['max_selection']),

      displayOrder: _int(json['display_order']),

      options:
          (json['options'] as List?)
              ?.map(
                (e) => PosModifierOption.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          [],
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
