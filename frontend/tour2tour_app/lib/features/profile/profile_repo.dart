import '../../api/api_client.dart';


class UserMe {
  final int id;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? avatarUrl;
  final bool isPremium;
  final String role;
  final bool is2faEnabled;
  final bool totpEnabled;
  final bool passkeyEnabled;

  UserMe({
    required this.id,
    required this.email,
    required this.phone,
    required this.displayName,
    required this.avatarUrl,
    required this.isPremium,
    required this.role,
    required this.is2faEnabled,
    required this.totpEnabled,
    required this.passkeyEnabled,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id'] as int,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isPremium: (json['is_premium'] ?? false) as bool,
      role: (json['role'] ?? '').toString(),
      is2faEnabled: (json['is_2fa_enabled'] ?? false) as bool,
      totpEnabled: (json['totp_enabled'] ?? false) as bool,
      passkeyEnabled: (json['passkey_enabled'] ?? false) as bool,
    );
  }
}


class ProfileRepo {
  final ApiClient api;
  ProfileRepo(this.api);

  Future<UserMe> getMe() async {
    final res = await api.dio.get('/users/me');
    return UserMe.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserMe> updateMe({
    required String displayName,
    required String? phone,
    required String? avatarUrl,
  }) async {
    final res = await api.dio.patch(
      '/users/me',
      data: {
        'display_name': displayName,
        'phone': phone,
        'avatar_url': avatarUrl,
      },
    );
    return UserMe.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> requestEmailChange(String newEmail) async {
    await api.dio.post(
      '/users/me/request-email-change',
      data: {'new_email': newEmail},
    );
  }

  Future<UserMe> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async {
    final res = await api.dio.post(
      '/users/me/confirm-email-change',
      data: {
        'new_email': newEmail,
        'code': code,
      },
    );
    return UserMe.fromJson(res.data as Map<String, dynamic>);
  }
}
