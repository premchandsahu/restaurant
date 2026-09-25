import 'dining_area.dart';
import 'floor.dart';
import 'outlet.dart';
import 'restaurant_table.dart';

class PosLayout {
  final Outlet outlet;

  final List<RestaurantFloor> floors;

  final List<DiningArea> diningAreas;

  final List<RestaurantTable> tables;

  PosLayout({
    required this.outlet,
    required this.floors,
    required this.diningAreas,
    required this.tables,
  });

  factory PosLayout.fromJson(Map<String, dynamic> json) {
    return PosLayout(
      outlet: Outlet.fromJson(Map<String, dynamic>.from(json['outlet'] ?? {})),

      floors: (json['floors'] as List? ?? [])
          .map(
            (item) => RestaurantFloor.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),

      diningAreas: (json['diningAreas'] as List? ?? [])
          .map((item) => DiningArea.fromJson(Map<String, dynamic>.from(item)))
          .toList(),

      tables: (json['tables'] as List? ?? [])
          .map(
            (item) => RestaurantTable.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}
