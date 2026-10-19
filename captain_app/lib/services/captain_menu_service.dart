import 'dart:convert';

import 'package:http/http.dart' as http;

class CaptainMenuService {
  final String baseUrl;
  final String token;

  CaptainMenuService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> getItemDetails({
    required int outletId,
    required int itemId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/menu/items/$itemId'
        '?outletId=$outletId',
      ),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load menu item',
      );
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> getCategories({
    required int outletId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/menu/categories'
        '?outletId=$outletId',
      ),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load menu categories',
      );
    }

    final rows = data['categories'] as List? ?? [];

    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllItems({
    required int outletId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/menu/items'
        '?outletId=$outletId',
      ),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load menu items',
      );
    }

    final rows = data['items'] as List? ?? [];

    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getItems({
    required int outletId,
    required int categoryId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/menu/categories/'
        '$categoryId/items'
        '?outletId=$outletId',
      ),
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load menu items',
      );
    }

    final rows = data['items'] as List? ?? [];

    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

Map<String, dynamic> _decode(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Invalid API response');
  } catch (_) {
    throw Exception('Invalid response from server');
  }
}
