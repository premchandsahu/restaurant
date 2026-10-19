import 'dart:convert';

import 'package:http/http.dart' as http;

class MenuCategoryMasterRecord {
  final int categoryId;
  final int outletId;
  final String categoryCode;
  final String categoryName;
  final int? parentCategoryId;
  final String? parentCategoryName;
  final int displayOrder;
  final bool isActive;

  const MenuCategoryMasterRecord({
    required this.categoryId,
    required this.outletId,
    required this.categoryCode,
    required this.categoryName,
    required this.parentCategoryId,
    required this.parentCategoryName,
    required this.displayOrder,
    required this.isActive,
  });

  factory MenuCategoryMasterRecord.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic value) {
      if (value == null || value == '') return null;
      return int.tryParse(value.toString());
    }

    int parseInt(dynamic value, [int fallback = 0]) =>
        int.tryParse(value?.toString() ?? '') ?? fallback;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase();
      return text == '1' || text == 'true' || text == 'yes';
    }

    return MenuCategoryMasterRecord(
      categoryId: parseInt(json['menu_category_id'] ?? json['categoryId']),
      outletId: parseInt(json['outlet_id'] ?? json['outletId']),
      categoryCode: (json['category_code'] ?? json['categoryCode'] ?? '').toString(),
      categoryName: (json['category_name'] ?? json['categoryName'] ?? '').toString(),
      parentCategoryId: parseNullableInt(
        json['parent_category_id'] ?? json['parentCategoryId'],
      ),
      parentCategoryName: (json['parent_category_name'] ??
                  json['parentCategoryName']) ==
              null
          ? null
          : (json['parent_category_name'] ?? json['parentCategoryName']).toString(),
      displayOrder: parseInt(json['display_order'] ?? json['displayOrder']),
      isActive: parseBool(json['is_active'] ?? json['isActive']),
    );
  }
}

class MenuCategoryMasterService {
  final String baseUrl;
  final String token;

  MenuCategoryMasterService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from menu category API');
    }
  }

  void _checkResponse(http.Response response, dynamic data, String fallback) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['success'] != true) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : '$fallback (${response.statusCode})',
      );
    }
  }

  Future<List<MenuCategoryMasterRecord>> getCategories({
    required int outletId,
  }) async {
    final uri = Uri.parse('$baseUrl/menu/category-master').replace(
      queryParameters: {'outletId': outletId.toString()},
    );

    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    _checkResponse(response, data, 'Unable to load menu categories');

    final rows = data['categories'] as List? ?? const [];
    return rows
        .map((row) => MenuCategoryMasterRecord.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<void> createCategory({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu/category-master'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    _checkResponse(response, data, 'Unable to create menu category');
  }

  Future<void> updateCategory({
    required int categoryId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/category-master/$categoryId'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    _checkResponse(response, data, 'Unable to update menu category');
  }
}
