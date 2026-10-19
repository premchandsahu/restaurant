import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:restapp_customer/models/customer/customer_cart.dart';
import 'package:restapp_customer/models/customer/customer_menu.dart';
import 'package:restapp_customer/models/customer/customer_order_status.dart';

class CustomerOrderService {
  final String baseUrl;
  final String token;

  CustomerOrderService({required this.baseUrl, required this.token});
  /*
  Future<String> startTableSession({required String tableUuid}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customer-order/start-table-session'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'table_uuid': tableUuid}),
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from start table session API');
    }

    final data = Map<String, dynamic>.from(responseData);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      final session = Map<String, dynamic>.from(data['session']);

      final token = session['session_token']?.toString() ?? '';

      if (token.isEmpty) {
        throw Exception('Table session token was not returned');
      }

      return token;
    }

    throw Exception(data['message'] ?? 'Unable to start table session');
  }
*/
  // ----------------------------------------------------------
  // Get table information from QR/table token
  // ----------------------------------------------------------

  Future<Map<String, dynamic>> getTableByToken({
    required String tableToken,
  }) async {
    if (tableToken.trim().isEmpty) {
      throw Exception('Table token is required');
    }

    final url = Uri.parse('$baseUrl/customer-order/table/${tableToken.trim()}');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from table API');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        responseData is Map<String, dynamic> &&
        responseData['success'] == true) {
      return responseData;
    }

    if (responseData is Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ?? 'Unable to load table information',
      );
    }

    throw Exception(
      'Unable to load table information (${response.statusCode})',
    );
  }

  // ----------------------------------------------------------
  // Create customer session
  // ----------------------------------------------------------

  Future<Map<String, dynamic>> createCustomerSession({
    required String tableSessionToken,
    String? customerName,
    String? customerPhone,
  }) async {
    if (tableSessionToken.trim().isEmpty) {
      throw Exception('Table session token is required');
    }

    final url = Uri.parse('$baseUrl/customer-order/customer-session');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'table_session_token': tableSessionToken,
        'customer_name': customerName == null || customerName.trim().isEmpty
            ? null
            : customerName.trim(),
        'customer_phone': customerPhone == null || customerPhone.trim().isEmpty
            ? null
            : customerPhone.trim(),
      }),
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from customer session API');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        responseData is Map<String, dynamic> &&
        responseData['success'] == true) {
      return responseData;
    }

    if (responseData is Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ?? 'Unable to create customer session',
      );
    }

    throw Exception(
      'Unable to create customer session (${response.statusCode})',
    );
  }

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

  Future<Map<String, dynamic>> getCustomerBill({
    required String customerSessionToken,
    required int orderId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/customer-order/bill/'
      '$customerSessionToken/$orderId',
    );

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from customer bill API');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(responseData);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? 'Unable to get customer bill');
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
      'customerSessionToken': customerSessionToken,

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

  Future<Map<String, dynamic>> addItemsToCustomerOrder({
    required String customerSessionToken,
    required int orderId,
    required CustomerCart cart,
  }) async {
    if (customerSessionToken.trim().isEmpty) {
      throw Exception('Customer session token is required');
    }

    if (orderId <= 0) {
      throw Exception('Valid orderId is required');
    }

    if (cart.isEmpty) {
      throw Exception('Cart is empty');
    }

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

    final body = {
      'customerSessionToken': customerSessionToken,
      'orderId': orderId,
      'items': items,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/customer-order/add-items'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from customer order API');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseData is Map<String, dynamic>) {
        if (responseData['success'] == true) {
          return responseData;
        }

        throw Exception(
          responseData['message'] ?? 'Unable to add items to order',
        );
      }

      throw Exception('Invalid success response from customer order API');
    }

    if (responseData is Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ??
            'Unable to add items to order (${response.statusCode})',
      );
    }

    throw Exception('Unable to add items to order (${response.statusCode})');
  }

  Future<String> startTableSession({required String tableUuid}) async {
    if (tableUuid.trim().isEmpty) {
      throw Exception('Table UUID is required');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/customer-order/start-table-session'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'table_uuid': tableUuid.trim()}),
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from start table session API');
    }

    if (responseData is! Map) {
      throw Exception('Invalid response from start table session API');
    }

    final data = Map<String, dynamic>.from(responseData);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      final sessionRaw = data['session'];

      if (sessionRaw is! Map) {
        throw Exception('Table session was not returned');
      }

      final session = Map<String, dynamic>.from(sessionRaw);

      final sessionToken = session['session_token']?.toString() ?? '';

      if (sessionToken.isEmpty) {
        throw Exception('Table session token was not returned');
      }

      return sessionToken;
    }

    throw Exception(data['message'] ?? 'Unable to start table session');
  }
}
