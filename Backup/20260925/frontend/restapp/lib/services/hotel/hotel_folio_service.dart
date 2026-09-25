import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/hotel/hotel_folio.dart';

class HotelFolioService {
  final String baseUrl;
  final String token;

  HotelFolioService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // -------------------------------------------------------
  // Add folio payment
  // -------------------------------------------------------

  Future<Map<String, dynamic>> addFolioPayment({
    required int folioId,
    required int stayId,
    required String paymentMethod,
    required double amount,
    String? referenceNo,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hotel/folio/payment'),
      headers: _headers,
      body: jsonEncode({
        'folioId': folioId,
        'stayId': stayId,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'referenceNo': referenceNo,
        'remarks': remarks,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add folio payment: ${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to add payment');
    }

    return Map<String, dynamic>.from(data);
  }

  // -------------------------------------------------------
  // Create or get folio
  // -------------------------------------------------------

  Future<HotelFolio> createOrGetFolio({required int stayId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hotel/stays/$stayId/folio'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to create hotel folio');
    }

    return _folioFromCreateResponse(Map<String, dynamic>.from(data));
  }

  // -------------------------------------------------------
  // Add non-restaurant folio charge
  // -------------------------------------------------------

  Future<void> addFolioCharge({
    required int stayId,
    required String entryType,
    required String description,
    required double quantity,
    required double rate,
    int? taxGroupId,
    String? remarks,
  }) async {
    final requestBody = <String, dynamic>{
      'stayId': stayId,
      'entryType': entryType,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'remarks': remarks,
    };

    // Only send taxGroupId when a tax group has actually
    // been selected.
    if (taxGroupId != null) {
      requestBody['taxGroupId'] = taxGroupId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/hotel/folio/add-charge'),
      headers: _headers,
      body: jsonEncode(requestBody),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to add folio charge');
    }

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Unable to add folio charge');
    }
  }

  // -------------------------------------------------------
  // Get complete folio
  // -------------------------------------------------------

  Future<HotelFolio> getStayFolio({required int stayId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hotel/stays/$stayId/folio'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get hotel folio');
    }

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Unable to get hotel folio');
    }

    final folioJson = Map<String, dynamic>.from(data['folio'] ?? {});

    return HotelFolio.fromJson(folioJson);
  }

  // -------------------------------------------------------
  // Convert create response
  // -------------------------------------------------------

  HotelFolio _folioFromCreateResponse(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data['folio'] ?? {});

    final monetary = json['monetary'] is Map
        ? Map<String, dynamic>.from(json['monetary'])
        : <String, dynamic>{};

    return HotelFolio(
      folioId: _toInt(json['folioId']),

      folioNo: json['folioNo']?.toString() ?? '',

      stayId: _toInt(json['stayId']),

      stayNo: json['stayNo']?.toString() ?? '',

      stayStatus: json['stayStatus']?.toString(),

      guest: HotelFolioGuest(
        guestId: _toInt(json['guestId']),
        firstName: _extractFirstName(json['guestName']),
      ),

      room: HotelFolioRoom(
        roomId: _toInt(json['roomId']),
        roomNo: json['roomNo']?.toString(),
      ),

      status: json['status']?.toString() ?? 'OPEN',

      entryAmount: _toDouble(monetary['entryAmount'] ?? json['entryAmount']),

      taxAmount: _toDouble(monetary['taxAmount'] ?? json['taxAmount']),

      totalAmount: _toDouble(monetary['totalAmount'] ?? json['totalAmount']),

      paidAmount: _toDouble(monetary['paidAmount'] ?? json['paidAmount']),

      balanceAmount: _toDouble(
        monetary['balanceAmount'] ?? json['balanceAmount'],
      ),

      entries: const [],
    );
  }

  // -------------------------------------------------------
  // Helpers
  // -------------------------------------------------------

  String? _extractFirstName(dynamic value) {
    if (value == null) {
      return null;
    }

    final name = value.toString().trim();

    if (name.isEmpty) {
      return null;
    }

    return name;
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
