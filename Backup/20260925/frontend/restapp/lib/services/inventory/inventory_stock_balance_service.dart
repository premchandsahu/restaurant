import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_stock_balance.dart';

class InventoryStockBalanceService {
  final String baseUrl;
  final String token;

  InventoryStockBalanceService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ============================================================
  // GET STOCK BALANCE / STOCK REGISTER
  //
  // GET /inventory/stock/register
  //
  // Required:
  //   outletId
  //   fromDate
  //   toDate
  //
  // Optional:
  //   rawMaterialId
  // ============================================================

  Future<List<InventoryStockBalance>> getStockBalances({
    required int outletId,
    required String fromDate,
    required String toDate,
    int? rawMaterialId,
  }) async {
    final queryParameters = <String, String>{
      'outletId': outletId.toString(),
      'fromDate': fromDate.trim(),
      'toDate': toDate.trim(),
    };

    if (rawMaterialId != null && rawMaterialId > 0) {
      queryParameters['rawMaterialId'] = rawMaterialId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/inventory/stock/register',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['rows'] as List? ?? const [];

    return rows
        .map(
          (e) => InventoryStockBalance.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  // ============================================================
  // GET STOCK BALANCE FOR ONE MATERIAL
  // ============================================================

  Future<InventoryStockBalance?> getStockBalance({
    required int outletId,
    required String fromDate,
    required String toDate,
    required int rawMaterialId,
  }) async {
    final rows = await getStockBalances(
      outletId: outletId,
      fromDate: fromDate,
      toDate: toDate,
      rawMaterialId: rawMaterialId,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  // ============================================================
  // RESPONSE HELPERS
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

      throw Exception(
        message != null && message.isNotEmpty ? message : 'Request failed',
      );
    }
  }
}
