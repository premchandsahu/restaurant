import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/pos/pos_category.dart';
import '../../models/pos/pos_menu_item.dart';
import '../../models/pos/pos_variant.dart';
import '../../models/pos/pos_modifier_group.dart';

class PosMenuDetails {
  final PosMenuItem item;
  final List<PosVariant> variants;
  final List<PosModifierGroup> modifierGroups;

  PosMenuDetails({
    required this.item,
    required this.variants,
    required this.modifierGroups,
  });
}

class PosMenuService {
  final String baseUrl;
  final String token;

  PosMenuService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<void> createMenuItemVariant({
    required int menuItemId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu/items/$menuItemId/variants'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to create variant',
    );
  }

  Future<void> updateMenuItemVariant({
    required int menuItemId,
    required int variantId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/items/$menuItemId/variants/$variantId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to update variant',
    );
  }

  Future<void> createMenuItem({required Map<String, dynamic> payload}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu/items'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to create menu item',
    );
  }

  Future<void> updateMenuItem({
    required int menuItemId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/items/$menuItemId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to update menu item',
    );
  }

  Future<void> _checkMutationResponse(
    http.Response response, {
    required String fallbackMessage,
  }) async {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from menu API');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map &&
        data['success'] == true) {
      return;
    }

    if (data is Map) {
      throw Exception(
        data['message']?.toString() ??
            '$fallbackMessage (${response.statusCode})',
      );
    }

    throw Exception('$fallbackMessage (${response.statusCode})');
  }

  Future<List<PosMenuItem>> getAllMenuItems({required int outletId}) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/menu/items',
      ).replace(queryParameters: {'outletId': outletId.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from menu API');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        responseData is Map &&
        responseData['success'] == true) {
      final rows = responseData['items'] as List? ?? const [];

      return rows
          .map((e) => PosMenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (responseData is Map) {
      throw Exception(
        responseData['message'] ??
            'Unable to load all menu items (${response.statusCode})',
      );
    }

    throw Exception('Unable to load all menu items (${response.statusCode})');
  }

  Future<PosMenuDetails> getMenuItem({
    required int menuItemId,
    required int outletId,
    bool includeInactiveVariants = false,
  }) async {
    final queryParameters = <String, String>{
      'outletId': outletId.toString(),
      if (includeInactiveVariants) 'includeInactive': '1',
    };

    final uri = Uri.parse(
      '$baseUrl/menu/items/$menuItemId',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to load menu item');
    }

    final item = PosMenuItem.fromJson(Map<String, dynamic>.from(data['item']));

    final variants =
        (data['variants'] as List?)
            ?.map((e) => PosVariant.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final modifierGroups =
        (data['modifierGroups'] as List?)
            ?.map(
              (e) => PosModifierGroup.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList() ??
        [];

    return PosMenuDetails(
      item: item,
      variants: variants,
      modifierGroups: modifierGroups,
    );
  }

  Future<List<PosCategory>> getCategories({required int outletId}) async {
    final uri = Uri.parse(
      '$baseUrl/menu/categories',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to load categories');
    }

    final categories = data['categories'] as List? ?? [];

    return categories
        .map((e) => PosCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PosMenuItem>> getMenuItems({
    required int outletId,
    required int categoryId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/menu/categories/'
      '$categoryId/items',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to load menu items');
    }

    final items = data['items'] as List? ?? [];

    return items
        .map((e) => PosMenuItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // --------------------------------------------------
  // MODIFIER GROUPS
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> getModifierGroups({
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/menu/modifier-groups',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from modifier group API');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['success'] != true) {
      throw Exception(
        data is Map
            ? data['message'] ?? 'Unable to load modifier groups'
            : 'Unable to load modifier groups',
      );
    }

    final groups = data['groups'] as List? ?? [];

    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createModifierGroup({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu/modifier-groups'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to create modifier group',
    );
  }

  Future<void> updateModifierGroup({
    required int groupId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/modifier-groups/$groupId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to update modifier group',
    );
  }

  // --------------------------------------------------
  // MODIFIER OPTIONS
  // --------------------------------------------------

  Future<void> createModifierOption({
    required int groupId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu/modifier-groups/$groupId/options'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to create modifier option',
    );
  }

  Future<void> updateModifierOption({
    required int groupId,
    required int optionId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/modifier-groups/$groupId/options/$optionId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to update modifier option',
    );
  }

  // --------------------------------------------------
  // ASSIGN GROUPS TO A MENU ITEM
  // --------------------------------------------------

  Future<void> setMenuItemModifierGroups({
    required int menuItemId,
    required int outletId,
    required List<int> modifierGroupIds,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu/items/$menuItemId/modifier-groups'),
      headers: _headers,
      body: jsonEncode({
        'outletId': outletId,
        'modifierGroupIds': modifierGroupIds,
      }),
    );

    await _checkMutationResponse(
      response,
      fallbackMessage: 'Unable to assign modifier groups',
    );
  }

  Future<List<int>> getAssignedModifierGroupIds({
    required int menuItemId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/menu/items/$menuItemId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response while loading assigned groups');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['success'] != true) {
      throw Exception(
        data is Map
            ? data['message'] ?? 'Unable to load assigned modifier groups'
            : 'Unable to load assigned modifier groups',
      );
    }

    final rows = data['modifierGroups'] as List? ?? [];

    return rows
        .map<int>((row) {
          final group = Map<String, dynamic>.from(row as Map);
          final id = group['modifier_group_id'] ?? group['modifierGroupId'];

          return int.tryParse(id.toString()) ?? 0;
        })
        .where((id) => id > 0)
        .toList();
  }
}
