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

  // ==================================================
  // TAX MASTER API METHODS
  // These use a separate endpoint so normal POS calls
  // continue to receive only active tax groups/rates.
  // ==================================================

  Uri _taxMasterUri(String path) {
    final root = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$root/tax$path');
  }

  dynamic _decodeMasterResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from tax master API');
    }
  }

  void _checkMasterResponse(
    http.Response response,
    dynamic data,
    String fallback,
  ) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['success'] != true) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : '$fallback (${response.statusCode})',
      );
    }
  }

  Future<List<TaxGroupMasterRecord>> getTaxGroupsForMaster() async {
    final response = await http.get(
      _taxMasterUri('/groups/master'),
      headers: _headers,
    );
    final data = _decodeMasterResponse(response);
    _checkMasterResponse(response, data, 'Unable to load tax groups');

    final rows = data['taxGroups'] as List? ?? const [];
    return rows
        .map((row) => TaxGroupMasterRecord.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<int?> createTaxGroup({
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      _taxMasterUri('/groups'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decodeMasterResponse(response);
    _checkMasterResponse(response, data, 'Unable to create tax group');

    if (data is Map) {
      return int.tryParse(data['taxGroupId']?.toString() ?? '');
    }
    return null;
  }

  Future<void> updateTaxGroup({
    required int taxGroupId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      _taxMasterUri('/groups/$taxGroupId'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decodeMasterResponse(response);
    _checkMasterResponse(response, data, 'Unable to update tax group');
  }

  Future<void> createTaxRate({
    required int taxGroupId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      _taxMasterUri('/groups/$taxGroupId/rates'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decodeMasterResponse(response);
    _checkMasterResponse(response, data, 'Unable to create tax rate');
  }

  Future<void> updateTaxRate({
    required int taxRateId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.put(
      _taxMasterUri('/rates/$taxRateId'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decodeMasterResponse(response);
    _checkMasterResponse(response, data, 'Unable to update tax rate');
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


// ==================================================
// Tax master records (include inactive rows).
// Kept here so the app can reuse PosTaxService rather
// than maintaining a second service class.
// ==================================================

class TaxRateMasterRecord {
  final int taxRateId;
  final int taxGroupId;
  final String taxName;
  final String taxType;
  final double rate;
  final bool isInclusive;
  final bool isActive;

  const TaxRateMasterRecord({
    required this.taxRateId,
    required this.taxGroupId,
    required this.taxName,
    required this.taxType,
    required this.rate,
    required this.isInclusive,
    required this.isActive,
  });

  factory TaxRateMasterRecord.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        int.tryParse(value?.toString() ?? '') ?? 0;

    double parseDouble(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase();
      return text == '1' || text == 'true' || text == 'yes';
    }

    return TaxRateMasterRecord(
      taxRateId: parseInt(json['tax_rate_id'] ?? json['taxRateId']),
      taxGroupId: parseInt(json['tax_group_id'] ?? json['taxGroupId']),
      taxName: (json['tax_name'] ?? json['taxName'] ?? '').toString(),
      taxType: (json['tax_type'] ?? json['taxType'] ?? 'OTHER').toString(),
      rate: parseDouble(json['rate']),
      isInclusive: parseBool(json['is_inclusive'] ?? json['isInclusive']),
      isActive: parseBool(json['is_active'] ?? json['isActive']),
    );
  }
}

class TaxGroupMasterRecord {
  final int taxGroupId;
  final String taxGroupCode;
  final String taxGroupName;
  final bool isActive;
  final List<TaxRateMasterRecord> rates;

  const TaxGroupMasterRecord({
    required this.taxGroupId,
    required this.taxGroupCode,
    required this.taxGroupName,
    required this.isActive,
    required this.rates,
  });

  factory TaxGroupMasterRecord.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        int.tryParse(value?.toString() ?? '') ?? 0;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase();
      return text == '1' || text == 'true' || text == 'yes';
    }

    final groupId = parseInt(json['tax_group_id'] ?? json['taxGroupId']);
    final rawRates = json['rates'] as List? ?? const [];
    final rates = rawRates
        .map((row) => TaxRateMasterRecord.fromJson({
              ...Map<String, dynamic>.from(row as Map),
              'tax_group_id': groupId,
            }))
        .toList();

    return TaxGroupMasterRecord(
      taxGroupId: groupId,
      taxGroupCode:
          (json['tax_group_code'] ?? json['taxGroupCode'] ?? '').toString(),
      taxGroupName:
          (json['tax_group_name'] ?? json['taxGroupName'] ?? '').toString(),
      isActive: parseBool(json['is_active'] ?? json['isActive']),
      rates: rates,
    );
  }
}
