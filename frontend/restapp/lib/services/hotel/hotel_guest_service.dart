import '../../models/hotel/hotel_guest.dart';
import '../api_client.dart';

class HotelGuestService {
  final ApiClient apiClient;

  HotelGuestService({required this.apiClient});

  Future<List<HotelGuest>> searchGuests({
    required int outletId,
    required String search,
  }) async {
    final response = await apiClient.get(
      '/hotel/guests?outletId=$outletId'
      '&search=${Uri.encodeQueryComponent(search)}',
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to search guests');
    }

    final List<dynamic> data = response['guests'] as List? ?? [];

    return data
        .map((e) => HotelGuest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<HotelGuest>> getGuests({
    required int outletId,
    String? search,
  }) async {
    final queryParameters = <String, String>{'outletId': outletId.toString()};

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final queryString = queryParameters.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final response = await apiClient.get('/hotel/guests?$queryString');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to load hotel guests');
    }

    final List<dynamic> data = response['guests'] as List? ?? [];

    return data
        .map((item) => HotelGuest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<HotelGuest> createGuest({
    required int outletId,
    required String firstName,
    String? lastName,
    required String phone,
    String? email,
    String? address,
    String? idType,
    String? idNumber,
  }) async {
    final response = await apiClient.post('/hotel/guests', {
      'outletId': outletId,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'address': address,
      'idType': idType,
      'idNumber': idNumber,
    });

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to create guest');
    }

    return HotelGuest.fromJson(Map<String, dynamic>.from(response['guest']));
  }
}
