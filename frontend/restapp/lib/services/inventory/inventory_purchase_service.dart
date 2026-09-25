import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_purchase.dart';
import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_supplier.dart';
import '../../models/pos/pos_tax.dart';

class InventoryPurchaseService {
  final String baseUrl;
  final String token;

  InventoryPurchaseService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

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

  Future<void> deletePurchase({
    required int purchaseId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/purchases/$purchaseId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.delete(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);
  }

  Future<List<InventoryPurchase>> getPurchases({
    required int outletId,
    int? supplierId,
    String? status,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    final query = <String, String>{'outletId': outletId.toString()};

    if (supplierId != null) {
      query['supplierId'] = supplierId.toString();
    }

    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim().toUpperCase();
    }

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      query['fromDate'] = fromDate.trim();
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      query['toDate'] = toDate.trim();
    }

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/inventory/purchases',
    ).replace(queryParameters: query);

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['purchases'] as List? ?? const [];

    return rows
        .map((e) => InventoryPurchase.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InventoryPurchase> getPurchase({
    required int outletId,
    required int purchaseId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/purchases/$purchaseId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryPurchase.fromJson(
      Map<String, dynamic>.from(data['purchase'] as Map),
    );
  }

  Future<InventoryPurchase> createPurchase({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/purchases'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryPurchase.fromJson(
      Map<String, dynamic>.from(data['purchase'] as Map),
    );
  }

  Future<InventoryPurchase> updatePurchase({
    required int purchaseId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/purchases/$purchaseId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryPurchase.fromJson(
      Map<String, dynamic>.from(data['purchase'] as Map),
    );
  }

  Future<InventoryPurchase> postPurchase({
    required int purchaseId,
    required int outletId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/purchases/$purchaseId/post'),
      headers: _headers,
      body: jsonEncode({'outletId': outletId}),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryPurchase.fromJson(
      Map<String, dynamic>.from(data['purchase'] as Map),
    );
  }

  Future<List<InventorySupplier>> getSuppliers() async {
    final uri = Uri.parse(
      '$baseUrl/inventory/suppliers',
    ).replace(queryParameters: {'active': 'true'});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['suppliers'] as List? ?? const [];

    return rows
        .map((e) => InventorySupplier.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InventoryRawMaterial>> getRawMaterials({
    required int outletId,
  }) async {
    final uri = Uri.parse('$baseUrl/inventory/raw-materials').replace(
      queryParameters: {'outletId': outletId.toString(), 'active': 'true'},
    );

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['rawMaterials'] as List? ?? const [];

    return rows
        .map((e) => InventoryRawMaterial.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

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
