import '../models/auth/app_menu.dart';
import 'api_client.dart';

class AppMenuService {
  final ApiClient apiClient;

  AppMenuService({required this.apiClient});

  Future<List<AppMenu>> getMyMenus() async {
    final response = await apiClient.get('/app-menu');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to load application menu');
    }

    final List<dynamic> data = response['menus'] as List? ?? [];

    return data
        .map((e) => AppMenu.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
