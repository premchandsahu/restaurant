import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_supplier_ledger.dart';

class InventorySupplierLedgerService {
  final String baseUrl;
  final String token;

  InventorySupplierLedgerService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<InventorySupplierLedger> getSupplierLedger({
    required int supplierId,
    required String fromDate,
    required String toDate,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/suppliers/$supplierId/ledger',
    ).replace(queryParameters: {'fromDate': fromDate, 'toDate': toDate});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventorySupplierLedger.fromJson(Map<String, dynamic>.from(data));
  }

  Future<InventorySupplierOutstanding> getSupplierOutstanding({
    required int supplierId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/suppliers/$supplierId/outstanding'),
      headers: _headers,
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventorySupplierOutstanding.fromJson(
      Map<String, dynamic>.from(data),
    );
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
