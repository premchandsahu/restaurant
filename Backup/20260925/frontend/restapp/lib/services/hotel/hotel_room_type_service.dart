import '../../models/hotel/hotel_room_type.dart';
import '../api_client.dart';

class HotelRoomTypeService {
  final ApiClient apiClient;

  HotelRoomTypeService({required this.apiClient});

  Future<List<HotelRoomType>> getRoomTypes({required int outletId}) async {
    final response = await apiClient.get(
      '/hotel/room-types?outletId=$outletId',
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to load room types');
    }

    final List<dynamic> data = response['roomTypes'] as List? ?? [];

    return data
        .map((item) => HotelRoomType.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
