class RestaurantFloor {
  final int floorId;
  final String floorName;
  final int displayOrder;

  RestaurantFloor({
    required this.floorId,
    required this.floorName,
    required this.displayOrder,
  });

  factory RestaurantFloor.fromJson(Map<String, dynamic> json) {
    return RestaurantFloor(
      floorId: _toInt(json['floor_id']),
      floorName: json['floor_name']?.toString() ?? '',
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
