import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:restapp/models/hotel/hotel_housekeeping_history.dart';

import '../../models/hotel/hotel_housekeeping_room.dart';

class HotelHousekeepingService {
  final String baseUrl;
  final String token;

  HotelHousekeepingService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ------------------------------------------------------------
  // GET HOUSEKEEPING HISTORY
  //
  // GET /hotel/housekeeping/history
  // ------------------------------------------------------------

  Future<List<HotelHousekeepingHistory>> getHousekeepingHistory({
    required int outletId,
    String? fromDate,
    String? toDate,
    int? roomId,
  }) async {
    final queryParameters = <String, String>{'outletId': outletId.toString()};

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      queryParameters['fromDate'] = fromDate;
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      queryParameters['toDate'] = toDate;
    }

    if (roomId != null) {
      queryParameters['roomId'] = roomId.toString();
    }

    // final uri = Uri.parse(
    //   '$baseUrl/hotel/housekeeping/rooms?outletId=$outletId',
    // );

    final uri = Uri.parse(
      '$baseUrl/hotel/housekeeping/history',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load housekeeping history. '
        'Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid housekeeping history response');
    }

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load housekeeping history',
      );
    }

    final history = data['history'];

    if (history is! List) {
      return [];
    }

    return history
        .map(
          (item) =>
              HotelHousekeepingHistory.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // GET HOUSEKEEPING ROOMS
  //
  // GET /hotel/housekeeping/rooms?outletId=1
  // ------------------------------------------------------------

  Future<List<HotelHousekeepingRoom>> getHousekeepingRooms({
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/hotel/housekeeping/rooms?outletId=$outletId',
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load housekeeping rooms. '
        'Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid housekeeping rooms response');
    }

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load housekeeping rooms',
      );
    }

    final rooms = data['rooms'];

    if (rooms is! List) {
      return [];
    }

    return rooms
        .map(
          (item) =>
              HotelHousekeepingRoom.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // START HOUSEKEEPING
  //
  // POST /hotel/rooms/:roomId/housekeeping-start
  // ------------------------------------------------------------

  Future<void> startHousekeeping({required int roomId}) async {
    final uri = Uri.parse('$baseUrl/hotel/rooms/$roomId/housekeeping-start');

    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to start housekeeping. '
        'Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid housekeeping start response');
    }

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to start housekeeping',
      );
    }
  }

  // ------------------------------------------------------------
  // COMPLETE HOUSEKEEPING
  //
  // POST /hotel/rooms/:roomId/housekeeping-complete
  // ------------------------------------------------------------

  Future<void> completeHousekeeping({required int roomId}) async {
    final uri = Uri.parse('$baseUrl/hotel/rooms/$roomId/housekeeping-complete');

    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to complete housekeeping. '
        'Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid housekeeping completion response');
    }

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to complete housekeeping',
      );
    }
  }
}
