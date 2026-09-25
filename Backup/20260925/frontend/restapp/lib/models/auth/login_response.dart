import 'app_user.dart';
import 'user_outlet.dart';

class LoginResponse {
  final String token;
  final AppUser user;
  final List<String> permissions;
  final List<UserOutlet> outlets;

  LoginResponse({
    required this.token,
    required this.user,
    required this.permissions,
    required this.outlets,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] ?? '',

      user: AppUser.fromJson(json['user'] ?? {}),

      permissions: (json['permissions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),

      outlets: (json['outlets'] as List? ?? [])
          .map((e) => UserOutlet.fromJson(e))
          .toList(),
    );
  }

  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }
}
