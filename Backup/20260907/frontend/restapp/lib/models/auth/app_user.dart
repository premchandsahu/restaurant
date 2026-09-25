class AppUser {
  final int userId;
  final String userUuid;
  final String username;
  final String displayName;
  final int companyId;
  final int roleId;
  final String roleCode;
  final String roleName;

  AppUser({
    required this.userId,
    required this.userUuid,
    required this.username,
    required this.displayName,
    required this.companyId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['userId'],
      userUuid: json['userUuid'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      companyId: json['companyId'],
      roleId: json['roleId'],
      roleCode: json['roleCode'] ?? '',
      roleName: json['roleName'] ?? '',
    );
  }
}
