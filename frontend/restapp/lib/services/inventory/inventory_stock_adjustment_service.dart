import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_stock_adjustment.dart';

class InventoryStockAdjustmentService {
  final String baseUrl;
  final String token;

  InventoryStockAdjustmentService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ============================================================
  // GET STOCK ADJUSTMENTS
  //
  // GET /inventory/stock-adjustments
  //
  // Optional:
  //   fromDate
  //   toDate
  //   adjustmentType
  // ============================================================

  Future<List<InventoryStockAdjustment>> getStockAdjustments({
    required int outletId,
    String? fromDate,
    String? toDate,
    String? adjustmentType,
  }) async {
    final queryParameters = <String, String>{'outletId': outletId.toString()};

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      queryParameters['fromDate'] = fromDate.trim();
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      queryParameters['toDate'] = toDate.trim();
    }

    if (adjustmentType != null && adjustmentType.trim().isNotEmpty) {
      queryParameters['adjustmentType'] = adjustmentType.trim().toUpperCase();
    }

    final uri = Uri.parse(
      '$baseUrl/inventory/stock-adjustments',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['adjustments'] as List? ?? const [];

    return rows
        .map(
          (e) =>
              InventoryStockAdjustment.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  // ============================================================
  // GET STOCK ADJUSTMENT DETAIL
  //
  // GET /inventory/stock-adjustments/:adjustmentId
  // ============================================================

  Future<InventoryStockAdjustment> getStockAdjustment({
    required int outletId,
    required int adjustmentId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/stock-adjustments/$adjustmentId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventoryStockAdjustment.fromJson(
      Map<String, dynamic>.from(data['adjustment'] as Map),
    );
  }

  // ============================================================
  // CREATE / POST STOCK ADJUSTMENT
  //
  // POST /inventory/stock-adjustments
  //
  // Payload example:
  //
  // {
  //   "outletId": 1,
  //   "adjustmentNo": "ADJ-000001",
  //   "adjustmentDate": "2026-09-25",
  //   "adjustmentType": "DECREASE",
  //   "reason": "Physical stock shortage",
  //   "items": [
  //     {
  //       "rawMaterialId": 1,
  //       "qty": 3,
  //       "unitId": 2,
  //       "rate": 120
  //     }
  //   ]
  // }
  // ============================================================

  Future<InventoryStockAdjustment> createStockAdjustment({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/stock-adjustments'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventoryStockAdjustment.fromJson(
      Map<String, dynamic>.from(data['adjustment'] as Map),
    );
  }

  // ============================================================
  // JSON DECODER
  // ============================================================

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'message': response.body};
    }
  }

  // ============================================================
  // ERROR HANDLER
  // ============================================================

  void _throwIfFailed(http.Response response, dynamic data) {
    final success = data is Map && data['success'] == true;

    if (response.statusCode < 200 || response.statusCode >= 300 || !success) {
      final message = data is Map ? data['message']?.toString() : null;

      throw Exception(
        message != null && message.isNotEmpty ? message : 'Request failed',
      );
    }
  }
}
