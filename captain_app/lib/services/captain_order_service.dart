import 'dart:convert';

import 'package:http/http.dart' as http;

class CaptainOrderService {
  final String baseUrl;
  final String token;

  CaptainOrderService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<void> requestBill({required int orderId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/request-bill'),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Unable to request bill');
    }
  }

  Future<int> createOrder({
    required int outletId,
    required int tableId,
    required int guestCount,
    String orderType = 'DINE_IN',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
      body: jsonEncode({
        'outletId': outletId,
        'orderType': orderType,
        'tableId': tableId,
        'guestCount': guestCount,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Unable to create order');
    }

    final order = Map<String, dynamic>.from(data['order'] ?? {});

    final orderId = _toInt(order['orderId'] ?? order['order_id']);

    if (orderId == null) {
      throw Exception('Order ID was not returned by server');
    }

    return orderId;
  }

  Future<void> addItem({
    required int orderId,
    required int menuItemId,
    int? variantId,
    required double quantity,
    List<Map<String, dynamic>> modifiers = const [],
    String? specialInstruction,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/items'),
      headers: _headers,
      body: jsonEncode({
        'menuItemId': menuItemId,
        'variantId': variantId,
        'qty': quantity,
        'specialInstruction': specialInstruction,
        'modifiers': modifiers,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Unable to add item');
    }
  }

  Future<void> sendToKitchen({required int orderId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/kot/orders/$orderId/kot'),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Unable to send KOT');
    }
  }

  Future<Map<String, dynamic>> getOrder({required int orderId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId'),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Unable to load order');
    }

    return data;
  }
}

Map<String, dynamic> _decode(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception();
  } catch (_) {
    throw Exception('Invalid response from server');
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}
