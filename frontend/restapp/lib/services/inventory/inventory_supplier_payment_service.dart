import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_supplier_payment.dart';
import '../../models/inventory/inventory_supplier.dart';

class InventorySupplierPaymentService {
  final String baseUrl;
  final String token;

  InventorySupplierPaymentService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<InventorySupplierPayment>> getSupplierPayments({
    required int supplierId,
    String? fromDate,
    String? toDate,
  }) async {
    final queryParameters = <String, String>{};

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      queryParameters['fromDate'] = fromDate.trim();
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      queryParameters['toDate'] = toDate.trim();
    }

    final uri = Uri.parse('$baseUrl/inventory/suppliers/$supplierId/payments')
        .replace(
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        );

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['payments'] as List? ?? const [];

    return rows
        .map(
          (e) =>
              InventorySupplierPayment.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<InventorySupplierPayment> getSupplierPayment({
    required int supplierId,
    required int paymentId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/suppliers/$supplierId/payments/$paymentId',
    );

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventorySupplierPayment.fromJson(
      Map<String, dynamic>.from(data['payment'] as Map),
    );
  }

  Future<InventorySupplierPayment> createSupplierPayment({
    required int supplierId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/suppliers/$supplierId/payments'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventorySupplierPayment.fromJson(
      Map<String, dynamic>.from(data['payment'] as Map),
    );
  }

  Future<InventorySupplierPayment> voidSupplierPayment({
    required int supplierId,
    required int paymentId,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/inventory/suppliers/$supplierId/payments/$paymentId/void',
      ),
      headers: _headers,
      body: jsonEncode({
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      }),
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventorySupplierPayment.fromJson(
      Map<String, dynamic>.from(data['payment'] as Map),
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

  /// Returns all suppliers, including inactive records, for Supplier Master.
  /// The existing getSuppliers() remains active-only for payment selection.
  Future<List<InventorySupplier>> getSuppliersForMaster() async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/suppliers'),
      headers: _headers,
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['suppliers'] as List? ?? const [];
    return rows
        .map((e) => InventorySupplier.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InventorySupplier> createSupplier({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/suppliers'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventorySupplier.fromJson(
      Map<String, dynamic>.from(data['supplier'] as Map),
    );
  }

  Future<void> updateSupplier({
    required int supplierId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/suppliers/$supplierId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);
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
