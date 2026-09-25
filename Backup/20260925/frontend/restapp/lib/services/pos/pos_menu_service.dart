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

  Future<PosMenuDetails> getMenuItem({
    required int menuItemId,
    required int outletId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/menu/items/$menuItemId',
    ).replace(queryParameters: {'outletId': outletId.toString()});

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
}
