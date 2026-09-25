import 'app_user.dart';
import 'user_outlet.dart';

class LoginResponse {
  final String token;
  final AppUser user;
  final List<UserOutlet> outlets;

  LoginResponse({
    required this.token,
    required this.user,
    required this.outlets,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],

      user: AppUser.fromJson(json['user']),

      outlets: (json['outlets'] as List? ?? [])
          .map((e) => UserOutlet.fromJson(e))
          .toList(),
    );
  }
}
