import '../../models/hotel/hotel_active_stay.dart';
import '../api_client.dart';

class HotelActiveStayService {
  final ApiClient apiClient;

  HotelActiveStayService({required this.apiClient});

  Future<List<HotelActiveStay>> getActiveStays({required int outletId}) async {
    final response = await apiClient.get(
      '/hotel/stays/active?outletId=$outletId',
    );

    if (response['success'] != true) {
      throw Exception(
        response['message'] ?? 'Unable to load active hotel stays',
      );
    }

    final List<dynamic> data = response['stays'] as List? ?? [];

    return data
        .map((e) => HotelActiveStay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
