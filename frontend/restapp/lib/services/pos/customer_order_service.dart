import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:restapp/models/pos/customer_cart.dart';
import 'package:restapp/models/pos/customer_menu.dart';

import '../../models/pos/customer_order_status.dart';

class CustomerOrderService {
  final String baseUrl;
  final String token;

  CustomerOrderService({required this.baseUrl, required this.token});

  Future<void> requestBill({
    required String customerSessionToken,
    required int orderId,
  }) async {
    final url = Uri.parse('$baseUrl/customer-order/request-bill');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerSessionToken': customerSessionToken,
        'orderId': orderId,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Unable to request bill');
  }

  Future<CustomerOrderStatus> getCustomerOrderStatus({
    required String customerSessionToken,
  }) async {
    final url = Uri.parse(
      '$baseUrl/customer-order/order-status/'
      '$customerSessionToken',
    );

    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return CustomerOrderStatus.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Unable to get customer order status');
  }

  Future<void> cancelOrderItem({
    required String customerSessionToken,
    required int orderId,
    required int orderItemId,
    String? reason,
  }) async {
    final url = Uri.parse('$baseUrl/customer-order/cancel-item');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerSessionToken': customerSessionToken,
        'orderId': orderId,
        'orderItemId': orderItemId,
        'reason': reason ?? 'Cancelled by customer',
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Unable to cancel item');
  }

  Future<CustomerMenu> getCustomerMenu({
    required String customerSessionToken,
  }) async {
    final url = Uri.parse('$baseUrl/customer-order/menu/$customerSessionToken');

    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return CustomerMenu.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Unable to load menu');
  }

  Future<Map<String, dynamic>> placeCustomerOrder({
    required String customerSessionToken,
    required CustomerCart cart,
    int? customerId,
    int guestCount = 1,
    String? remarks,
  }) async {
    if (customerSessionToken.trim().isEmpty) {
      throw Exception('Customer session token is required');
    }

    if (cart.isEmpty) {
      throw Exception('Cart is empty');
    }

    // ----------------------------------------------------------
    // Build item payload
    // ----------------------------------------------------------

    final items = cart.items.map((cartItem) {
      return {
        'menuItemId': cartItem.menuItem.menuItemId,

        'variantId': cartItem.variant?.variantId,

        'qty': cartItem.quantity,

        'specialInstruction': cartItem.specialInstruction.trim().isEmpty
            ? null
            : cartItem.specialInstruction.trim(),

        'modifiers': cartItem.modifiers.map((modifier) {
          return {
            'modifierGroupId': modifier.modifierGroupId,

            'modifierOptionId': modifier.modifierOptionId,

            'qty': 1,
          };
        }).toList(),
      };
    }).toList();

    // ----------------------------------------------------------
    // Build request body
    // ----------------------------------------------------------

    final body = {
      'sessionToken': customerSessionToken,

      'customerId': customerId,

      'guestCount': guestCount > 0 ? guestCount : 1,

      'remarks': remarks == null || remarks.trim().isEmpty
          ? null
          : remarks.trim(),

      'items': items,
    };

    // ----------------------------------------------------------
    // API request
    // ----------------------------------------------------------

    final response = await http.post(
      Uri.parse('$baseUrl/customer-order'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    // ----------------------------------------------------------
    // Decode response
    // ----------------------------------------------------------

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from customer order API');
    }

    // ----------------------------------------------------------
    // Success
    // ----------------------------------------------------------

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseData is Map<String, dynamic>) {
        if (responseData['success'] == true) {
          return responseData;
        }

        throw Exception(responseData['message'] ?? 'Unable to place order');
      }

      throw Exception('Invalid success response from customer order API');
    }

    // ----------------------------------------------------------
    // Error
    // ----------------------------------------------------------

    if (responseData is Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ??
            'Unable to place customer order '
                '(${response.statusCode})',
      );
    }

    throw Exception(
      'Unable to place customer order '
      '(${response.statusCode})',
    );
  }
}
