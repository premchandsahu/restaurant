import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth/login_response.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService({required this.apiClient});

  Future<LoginResponse> login(String username, String password) async {
    final response = await apiClient.post('/auth/login', {
      'username': username,
      'password': password,
    });

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Login failed');
    }

    final result = LoginResponse.fromJson(response);

    await saveSession(result);

    apiClient.token = result.token;

    return result;
  }

  Future<void> saveSession(LoginResponse result) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('auth_token', result.token);

    await prefs.setString('user_id', result.user.userId.toString());

    await prefs.setString('display_name', result.user.displayName);

    await prefs.setInt('company_id', result.user.companyId);

    /*
     * Select default outlet.
     */
    if (result.outlets.isNotEmpty) {
      final defaultOutlet = result.outlets.firstWhere(
        (o) => o.isDefault,
        orElse: () => result.outlets.first,
      );

      await prefs.setInt('outlet_id', defaultOutlet.outletId);

      await prefs.setString('outlet_name', defaultOutlet.outletName);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('auth_token');
  }

  Future<int?> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt('outlet_id');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    apiClient.token = null;
  }
}
