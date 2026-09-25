import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/pos/pos_tax.dart';

class PosTaxService {
  final String baseUrl;
  final String token;

  PosTaxService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<PosTaxGroup>> getTaxGroups() async {
    final uri = Uri.parse('$baseUrl/tax/groups');

    final response = await http.get(uri, headers: _headers);

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Unable to load tax groups');
    }

    final groups = data['taxGroups'] as List? ?? [];

    return groups
        .map((e) => _parseTaxGroup(Map<String, dynamic>.from(e)))
        .toList();
  }

  PosTaxGroup _parseTaxGroup(Map<String, dynamic> json) {
    final rates = json['rates'] as List? ?? [];

    return PosTaxGroup(
      taxGroupId: _int(json['tax_group_id']),

      taxGroupCode: json['tax_group_code']?.toString() ?? '',

      taxGroupName: json['tax_group_name']?.toString() ?? '',

      rates: rates
          .map((e) => PosTaxRate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
