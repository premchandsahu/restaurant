import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_raw_material.dart';
import '../../models/pos/pos_tax.dart';

class InventoryCategoryOption {
  final int inventoryCategoryId;
  final String categoryCode;
  final String categoryName;

  const InventoryCategoryOption({
    required this.inventoryCategoryId,
    required this.categoryCode,
    required this.categoryName,
  });

  factory InventoryCategoryOption.fromJson(Map<String, dynamic> json) {
    return InventoryCategoryOption(
      inventoryCategoryId: _int(
        json['inventoryCategoryId'] ?? json['inventory_category_id'],
      ),
      categoryCode:
          (json['categoryCode'] ?? json['category_code'])?.toString() ?? '',
      categoryName:
          (json['categoryName'] ?? json['category_name'])?.toString() ?? '',
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class InventoryRawMaterialService {
  final String baseUrl;
  final String token;

  InventoryRawMaterialService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ============================================================
  // GET RAW MATERIALS
  // ============================================================

  Future<List<InventoryRawMaterial>> getRawMaterials({
    required int outletId,
    bool activeOnly = false,
  }) async {
    final queryParameters = <String, String>{'outletId': outletId.toString()};

    if (activeOnly) {
      queryParameters['active'] = 'true';
    }

    final uri = Uri.parse(
      '$baseUrl/inventory/raw-materials',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['rawMaterials'] as List? ?? const [];

    return rows
        .map((e) => InventoryRawMaterial.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ============================================================
  // GET SINGLE RAW MATERIAL
  // ============================================================

  Future<InventoryRawMaterial> getRawMaterial({
    required int rawMaterialId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/raw-materials/$rawMaterialId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventoryRawMaterial.fromJson(
      Map<String, dynamic>.from(data['rawMaterial'] as Map),
    );
  }

  // ============================================================
  // CREATE RAW MATERIAL
  // ============================================================

  Future<InventoryRawMaterial> createRawMaterial({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/raw-materials'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventoryRawMaterial.fromJson(
      Map<String, dynamic>.from(data['rawMaterial'] as Map),
    );
  }

  // ============================================================
  // UPDATE RAW MATERIAL
  // ============================================================

  Future<void> updateRawMaterial({
    required int rawMaterialId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/raw-materials/$rawMaterialId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);

    _throwIfFailed(response, data);
  }

  // ============================================================
  // GET INVENTORY CATEGORIES
  // ============================================================

  Future<List<InventoryCategoryOption>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/categories'),
      headers: _headers,
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['categories'] as List? ?? const [];

    return rows
        .map(
          (e) => InventoryCategoryOption.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  // ============================================================
  // GET UNITS
  // ============================================================

  Future<List<InventoryUnit>> getUnits() async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/units'),
      headers: _headers,
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['units'] as List? ?? const [];

    return rows
        .map((e) => InventoryUnit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ============================================================
  // GET TAX GROUPS
  // Uses existing POS Tax API
  // GET /tax/groups
  // ============================================================

  Future<List<PosTaxGroup>> getTaxGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tax/groups'),
      headers: _headers,
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['taxGroups'] as List? ?? const [];

    return rows
        .map((e) => PosTaxGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createInventoryCategory({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/categories'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    _throwIfCategoryMutationFailed(response);
  }

  Future<void> updateInventoryCategory({
    required int categoryId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/categories/$categoryId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    _throwIfCategoryMutationFailed(response);
  }

  void _throwIfCategoryMutationFailed(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        response.body.trim().isNotEmpty ? response.body : 'Request failed',
      );
    }

    final success = data is Map && data['success'] == true;
    if (response.statusCode < 200 || response.statusCode >= 300 || !success) {
      final message = data is Map ? data['message']?.toString() : null;
      throw Exception(message?.isNotEmpty == true ? message : 'Request failed');
    }
  }

  Future<InventoryUnit> createUnit({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/units'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryUnit.fromJson(
      Map<String, dynamic>.from(data['unit'] as Map),
    );
  }

  Future<void> updateUnit({
    required int unitId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/units/$unitId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'message': response.body};
    }
  }

  void _throwIfFailed(http.Response response, dynamic data) {
    final success = data is Map && data['success'] == true;

    if (response.statusCode < 200 || response.statusCode >= 300 || !success) {
      final message = data is Map ? data['message']?.toString() : null;

      throw Exception(message?.isNotEmpty == true ? message : 'Request failed');
    }
  }
}
