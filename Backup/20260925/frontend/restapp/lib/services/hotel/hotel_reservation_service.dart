import '../../models/hotel/hotel_reservation.dart';
import '../api_client.dart';

class HotelReservationService {
  final ApiClient apiClient;

  HotelReservationService({required this.apiClient});

  Future<List<HotelReservation>> getReservations({
    required int outletId,
    String? status,
    String? fromDate,
    String? toDate,
    String? guest,
    String? reservationNo,
  }) async {
    final queryParameters = <String, String>{'outletId': outletId.toString()};

    if (status != null && status.trim().isNotEmpty && status != 'ALL') {
      queryParameters['status'] = status.trim();
    }

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      queryParameters['fromDate'] = fromDate.trim();
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      queryParameters['toDate'] = toDate.trim();
    }

    if (guest != null && guest.trim().isNotEmpty) {
      queryParameters['guest'] = guest.trim();
    }

    if (reservationNo != null && reservationNo.trim().isNotEmpty) {
      queryParameters['reservationNo'] = reservationNo.trim();
    }

    final queryString = queryParameters.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final response = await apiClient.get('/hotel/reservations?$queryString');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to load reservations');
    }

    final List<dynamic> data = response['reservations'] as List? ?? [];

    return data
        .map(
          (item) => HotelReservation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
