class KitchenStation {
  final int kitchenStationId;
  final int outletId;
  final String stationCode;
  final String stationName;
  final int? printerId;
  final int displayOrder;

  KitchenStation({
    required this.kitchenStationId,
    required this.outletId,
    required this.stationCode,
    required this.stationName,
    this.printerId,
    required this.displayOrder,
  });

  factory KitchenStation.fromJson(Map<String, dynamic> json) {
    return KitchenStation(
      kitchenStationId:
          int.tryParse(json['kitchen_station_id']?.toString() ?? '') ?? 0,

      outletId: int.tryParse(json['outlet_id']?.toString() ?? '') ?? 0,

      stationCode: json['station_code']?.toString() ?? '',

      stationName: json['station_name']?.toString() ?? '',

      printerId: json['printer_id'] != null
          ? int.tryParse(json['printer_id'].toString())
          : null,

      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
    );
  }
}
