import 'dart:convert';
import 'package:restapp/models/pos/bill.dart';
import 'package:restapp/models/pos/pending_bill.dart';

import '../../../models/pos/kitchen_station.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:restapp/models/pos/pos_kot.dart';

import '../../../models/pos/pos_order.dart';

class PosOrderService {
  final String baseUrl;

  final String token;

  PosOrderService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> mergeOrders({
    required int sourceOrderId,
    required int targetOrderId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$sourceOrderId/merge'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'targetOrderId': targetOrderId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to merge orders');
    }

    return data;
  }

  Future<Map<String, dynamic>> transferOrderTable({
    required int orderId,
    required int newTableId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/transfer-table'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newTableId': newTableId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to transfer order');
    }

    return data;
  }

  Future<List<PendingBill>> getPendingBills({required int outletId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bills/pending?outletId=$outletId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Unable to load pending bills');
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Unable to load pending bills');
    }

    final List<dynamic> rows = body['bills'] ?? [];

    return rows
        .map((row) => PendingBill.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Bill> createBill({required int orderId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bills'),
      headers: _headers,
      body: jsonEncode({'orderId': orderId}),
    );

    debugPrint('CREATE BILL RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to create bill');
    }

    return Bill.fromJson(Map<String, dynamic>.from(data['bill']));
  }

  Future<Bill> getBill(int billId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bills/$billId'),
      headers: _headers,
    );

    debugPrint('GET BILL RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to load bill');
    }

    return Bill.fromJson(Map<String, dynamic>.from(data['bill']));
  }

  Future<Map<String, dynamic>> addBillPayment({
    required int billId,
    required String paymentMode,
    required double amount,
    String? referenceNo,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bills/$billId/payments'),
      headers: _headers,
      body: jsonEncode({
        'paymentMode': paymentMode,
        'amount': amount,
        'referenceNo': referenceNo,
        'remarks': remarks,
      }),
    );

    debugPrint('PAYMENT RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to process payment');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<List<KitchenStation>> getKitchenStations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/kot/stations'),
      headers: _headers,
    );

    debugPrint('GET KITCHEN STATIONS RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get kitchen stations');
    }

    final List<dynamic> stationList = data['stations'] ?? [];

    return stationList
        .map((json) => KitchenStation.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // --------------------------------------------------
  // Create new order
  // --------------------------------------------------

  Future<PosOrder> createOrder({
    required int outletId,
    int? terminalId,
    required String orderType,
    int? tableId,
    int? customerId,
    int? guestCount,
    int? waiterId,
    int? captainId,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),

      headers: _headers,

      body: jsonEncode({
        'outletId': outletId,
        'terminalId': terminalId,
        'orderType': orderType,
        'tableId': tableId,
        'customerId': customerId,
        'guestCount': guestCount ?? 1,
        'waiterId': waiterId,
        'captainId': captainId,
        'remarks': remarks,
      }),
    );

    debugPrint('CREATE ORDER RESPONSE: ${response.body}');
    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to create order');
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  // --------------------------------------------------
  // Update order header
  // --------------------------------------------------

  Future<PosOrder> updateOrder({
    required int orderId,
    String? orderType,
    int? tableId,
    int? customerId,
    int? waiterId,
    int? captainId,
    int? guestCount,
    String? remarks,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/orders/$orderId'),

      headers: _headers,

      body: jsonEncode({
        'orderType': orderType,
        'tableId': tableId,
        'customerId': customerId,
        'waiterId': waiterId,
        'captainId': captainId,
        'guestCount': guestCount ?? 1,
        'remarks': remarks,
      }),
    );

    debugPrint('UPDATE ORDER RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to update order');
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  Future<List<PosKot>> getOrderKOTs(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/kot/orders/$orderId/kot'),
      headers: _headers,
    );

    debugPrint('GET KOT RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get KOTs');
    }

    final List<dynamic> kotList = data['kots'] ?? [];

    return kotList
        .map((json) => PosKot.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<PosKot>> getStationKOTs(int stationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/kot/station/$stationId'),
      headers: _headers,
    );

    debugPrint('GET STATION KOT RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get station KOTs');
    }

    final List<dynamic> kotList = data['kots'] ?? [];

    return kotList
        .map((json) => PosKot.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // --------------------------------------------------
  // Get order
  // --------------------------------------------------

  Future<PosOrder> getOrder(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId'),

      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get order');
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  Future<Map<String, dynamic>> updateKOTStatus({
    required int kotId,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/kot/kot/$kotId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );

    debugPrint('UPDATE KOT STATUS RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to update KOT status');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<List<PosOrder>> getTableOrders({
    required int tableId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/orders/table/$tableId/orders'
      '?outletId=$outletId',
    );

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get table orders');
    }

    final orders = data['orders'] as List? ?? [];

    return orders
        .map((e) => PosOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // --------------------------------------------------
  // Get current table order
  // --------------------------------------------------

  Future<PosOrder?> getTableOrder({
    required int tableId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/orders/table/$tableId'
      '?outletId=$outletId',
    );

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to get table order');
    }

    if (data['order'] == null) {
      return null;
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  // --------------------------------------------------
  // Add item
  // --------------------------------------------------

  Future<PosOrder> addItem({
    required int orderId,
    required int menuItemId,
    int? variantId,
    required double qty,
    String? specialInstruction,
    List<Map<String, dynamic>> modifiers = const [],
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/orders/'
        '$orderId/items',
      ),

      headers: _headers,

      body: jsonEncode({
        'menuItemId': menuItemId,
        'variantId': variantId,
        'qty': qty,
        'specialInstruction': specialInstruction,
        'modifiers': modifiers,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to add item');
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  // --------------------------------------------------
  // Save order items without sending KOT
  // --------------------------------------------------

  Future<PosOrder> saveOrderItems({
    required int orderId,
    required List<Map<String, dynamic>> items,
  }) async {
    PosOrder order = await getOrder(orderId);

    for (final item in items) {
      final qty = (item['qty'] as num?)?.toDouble() ?? 0;

      if (qty <= 0) {
        continue;
      }

      order = await addItem(
        orderId: orderId,
        menuItemId: item['menuItemId'] as int,
        variantId: item['variantId'] as int?,
        qty: qty,
        specialInstruction: item['specialInstruction'] as String?,
        modifiers: List<Map<String, dynamic>>.from(item['modifiers'] ?? []),
      );
    }

    return order;
  }

  // --------------------------------------------------
  // Apply discount
  // --------------------------------------------------

  Future<PosOrder> applyDiscount({
    required int orderId,
    int? discountId,
    required String discountType,
    required double discountValue,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/orders/'
        '$orderId/discount',
      ),

      headers: _headers,

      body: jsonEncode({
        'discountId': discountId,
        'discountType': discountType,
        'discountValue': discountValue,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to apply discount');
    }

    return PosOrder.fromJson(Map<String, dynamic>.from(data['order']));
  }

  // --------------------------------------------------
  // Send KOT
  // --------------------------------------------------
  Future<Map<String, dynamic>> sendKOT(int orderId) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/kot/orders/'
        '$orderId/kot',
      ),
      headers: _headers,
    );

    debugPrint('KOT RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to create KOT');
    }

    return Map<String, dynamic>.from(data);
  }
}
