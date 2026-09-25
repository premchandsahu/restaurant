import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/pos/active_hotel_stay.dart';

class HotelStayService {
  final String baseUrl;
  final String token;

  HotelStayService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> checkOut({required int stayId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hotel/stays/$stayId/check-out'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to check out guest');
    }

    return data;
  }

  Future<List<ActiveHotelStay>> getActiveStays({required int outletId}) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/hotel/stays/active'
        '?outletId=$outletId',
      ),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get active hotel stays');
    }

    final List<dynamic> rows = data['stays'] ?? [];

    return rows
        .map((row) => ActiveHotelStay.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
