import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/inventory/inventory_menu_item.dart';
import '../../models/inventory/inventory_raw_material.dart';
import '../../models/inventory/inventory_recipe.dart';

class InventoryRecipeService {
  final String baseUrl;
  final String token;

  InventoryRecipeService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

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
  /*
  Future<List<InventoryMenuItem>> getMenuItems({required int outletId}) async {
    final categoriesResponse = await http.get(
      Uri.parse(
        '$baseUrl/menu/categories',
      ).replace(queryParameters: {'outletId': outletId.toString()}),
      headers: _headers,
    );

    final categoriesData = _decode(categoriesResponse);
    _throwIfFailed(categoriesResponse, categoriesData);

    final categoryRows = categoriesData['categories'] as List? ?? const [];
    final itemsById = <int, InventoryMenuItem>{};

    for (final categoryRaw in categoryRows) {
      final category = Map<String, dynamic>.from(categoryRaw);
      final categoryId = _int(
        category['menu_category_id'] ?? category['categoryId'],
      );
      if (categoryId <= 0) continue;

      final uri = Uri.parse(
        '$baseUrl/menu/categories/$categoryId/items',
      ).replace(queryParameters: {'outletId': outletId.toString()});

      final response = await http.get(uri, headers: _headers);
      final data = _decode(response);
      _throwIfFailed(response, data);

      final itemRows = data['items'] as List? ?? const [];
      for (final raw in itemRows) {
        final itemJson = Map<String, dynamic>.from(raw);
        final itemId = _int(itemJson['menu_item_id']);
        if (itemId <= 0) continue;
        itemsById[itemId] = InventoryMenuItem.fromJson(itemJson);
      }
    }

    final items = itemsById.values.toList()
      ..sort(
        (a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
      );

    final result = <InventoryMenuItem>[];
    for (final item in items) {
      final detailResponse = await http.get(
        Uri.parse(
          '$baseUrl/menu/items/${item.menuItemId}',
        ).replace(queryParameters: {'outletId': outletId.toString()}),
        headers: _headers,
      );

      final detailData = _decode(detailResponse);
      _throwIfFailed(detailResponse, detailData);

      final variantRows = detailData['variants'] as List? ?? const [];
      final variants = variantRows
          .map(
            (e) => InventoryMenuVariant.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();

      result.add(
        InventoryMenuItem.fromJson(
          detailData['item'] is Map
              ? Map<String, dynamic>.from(detailData['item'])
              : <String, dynamic>{
                  'menu_item_id': item.menuItemId,
                  'item_code': item.itemCode,
                  'item_name': item.itemName,
                  'item_type': item.itemType,
                  'base_rate': item.baseRate,
                  'is_active': item.isActive,
                  'is_available': item.isAvailable,
                },
          variants: variants,
        ),
      );
    }

    return result;
  }
*/

  Future<List<InventoryMenuItem>> getMenuItems({required int outletId}) async {
    // Backend returns all active menu items together with their
    // active variants in one request.
    final uri = Uri.parse(
      '$baseUrl/menu/items',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);

    _throwIfFailed(response, data);

    final rows = data['items'] as List? ?? const [];

    final result = <InventoryMenuItem>[];

    for (final raw in rows) {
      final itemJson = Map<String, dynamic>.from(raw);

      final itemId = _int(itemJson['menu_item_id']);

      if (itemId <= 0) {
        continue;
      }

      final variantRows = itemJson['variants'] as List? ?? const [];

      final variants = variantRows
          .map(
            (e) => InventoryMenuVariant.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();

      result.add(InventoryMenuItem.fromJson(itemJson, variants: variants));
    }

    result.sort(
      (a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
    );

    return result;
  }

  Future<List<InventoryRecipe>> getRecipes({required int outletId}) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/recipes',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['recipes'] as List? ?? const [];
    return rows
        .map((e) => InventoryRecipe.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InventoryRecipe> getRecipe({
    required int outletId,
    required int recipeId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/inventory/recipes/$recipeId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    _throwIfFailed(response, data);

    return InventoryRecipe.fromJson(
      Map<String, dynamic>.from(data['recipe'] as Map),
    );
  }

  Future<List<InventoryRecipe>> getRecipeHistory({
    required int outletId,
    required int menuItemId,
    int? variantId,
  }) async {
    final queryParameters = <String, String>{
      'outletId': outletId.toString(),
      'menuItemId': menuItemId.toString(),
      'history': 'true',
    };

    if (variantId == null) {
      queryParameters['variantId'] = 'null';
    } else {
      queryParameters['variantId'] = variantId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/inventory/recipes',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: _headers);

    final data = _decode(response);
    _throwIfFailed(response, data);

    final rows = data['recipes'] as List? ?? const [];

    return rows
        .map((e) => InventoryRecipe.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createRecipe({required Map<String, dynamic> payload}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/recipes'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);
  }

  Future<void> updateRecipe({
    required int recipeId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/recipes/$recipeId'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);
  }

  Future<void> updateRecipeStatus({
    required int outletId,
    required int recipeId,
    required bool isActive,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory/recipes/$recipeId/status'),
      headers: _headers,
      body: jsonEncode({'outletId': outletId, 'isActive': isActive}),
    );

    final data = _decode(response);
    _throwIfFailed(response, data);
  }

  Future<(RecipeCoverageSummary, List<RecipeTarget>)> getCoverage({
    required int outletId,
    required String asOfDate,
  }) async {
    final uri = Uri.parse('$baseUrl/inventory/recipes/coverage').replace(
      queryParameters: {'outletId': outletId.toString(), 'asOfDate': asOfDate},
    );

    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    _throwIfFailed(response, data);

    final summary = RecipeCoverageSummary.fromJson(
      Map<String, dynamic>.from(data['summary'] as Map),
    );

    final rows = data['rows'] as List? ?? const [];
    final targets = rows
        .map((e) => RecipeTarget.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return (summary, targets);
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

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
