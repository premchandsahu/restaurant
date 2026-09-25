class DiningArea {
  final int diningAreaId;
  final String areaName;
  final int displayOrder;

  DiningArea({
    required this.diningAreaId,
    required this.areaName,
    required this.displayOrder,
  });

  factory DiningArea.fromJson(Map<String, dynamic> json) {
    return DiningArea(
      diningAreaId: _toInt(json['dining_area_id']),

      areaName: json['area_name']?.toString() ?? '',

      displayOrder: _toInt(json['display_order']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
