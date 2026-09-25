import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_stock_ledger.dart';

class InventoryStockLedgerService {
  final String baseUrl;
  final String token;

  InventoryStockLedgerService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ============================================================
  // GET STOCK ITEM LEDGER
  //
  // GET /inventory/stock/ledger
  //
  // Required:
  //   outletId
  //   rawMaterialId
  //   fromDate
  //   toDate
  // ============================================================

  Future<InventoryStockLedger> getStockLedger({
    required int outletId,
    required int rawMaterialId,
    required String fromDate,
    required String toDate,
  }) async {
    final uri = Uri.parse('$baseUrl/inventory/stock/ledger').replace(
      queryParameters: {
        'outletId': outletId.toString(),
        'rawMaterialId': rawMaterialId.toString(),
        'fromDate': fromDate.trim(),
        'toDate': toDate.trim(),
      },
    );

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    return InventoryStockLedger.fromJson(Map<String, dynamic>.from(data));
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
