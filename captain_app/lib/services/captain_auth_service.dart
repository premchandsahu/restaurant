import 'dart:convert';

import 'package:http/http.dart' as http;

class CaptainAuthResult {
  final String token;
  final int userId;
  final String username;
  final String displayName;
  final int companyId;
  final int roleId;
  final String roleCode;
  final String roleName;
  final List<CaptainOutlet> outlets;

  CaptainAuthResult({
    required this.token,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.companyId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.outlets,
  });
}

class CaptainOutlet {
  final int outletId;
  final String outletCode;
  final String outletName;
  final bool isDefault;

  CaptainOutlet({
    required this.outletId,
    required this.outletCode,
    required this.outletName,
    required this.isDefault,
  });

  factory CaptainOutlet.fromJson(Map<String, dynamic> json) {
    return CaptainOutlet(
      outletId: _toInt(json['outlet_id']) ?? 0,
      outletCode: json['outlet_code']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? '',
      isDefault: _toBool(json['is_default']),
    );
  }
}

class CaptainAuthService {
  final String baseUrl;

  CaptainAuthService({required this.baseUrl});

  Future<CaptainAuthResult> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'username': username, 'password': password}),
    );

    dynamic responseData;

    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from login API');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseData is! Map ||
        responseData['success'] != true) {
      if (responseData is Map) {
        throw Exception(responseData['message'] ?? 'Unable to login');
      }

      throw Exception('Unable to login (${response.statusCode})');
    }

    final user = Map<String, dynamic>.from(responseData['user'] ?? {});

    final outlets = (responseData['outlets'] as List? ?? [])
        .map((e) => CaptainOutlet.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final roleCode = user['roleCode']?.toString() ?? '';

    // Captain application must only allow CAPTAIN users.
    if (roleCode.toUpperCase() != 'CAPTAIN') {
      throw Exception('This application is only for Captain users');
    }

    return CaptainAuthResult(
      token: responseData['token']?.toString() ?? '',
      userId: _toInt(user['userId']) ?? 0,
      username: user['username']?.toString() ?? '',
      displayName: user['displayName']?.toString() ?? '',
      companyId: _toInt(user['companyId']) ?? 0,
      roleId: _toInt(user['roleId']) ?? 0,
      roleCode: roleCode,
      roleName: user['roleName']?.toString() ?? '',
      outlets: outlets,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

bool _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final text = value?.toString().toLowerCase();

  return text == 'true' || text == '1';
}
