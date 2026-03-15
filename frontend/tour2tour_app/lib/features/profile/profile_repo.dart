import '../../api/api_client.dart';


class UserMe {
  final int id;
  final String? email;
  final String? phone;
  final String role;
  final bool is2faEnabled;

  UserMe({
    required this.id,
    required this.email,
    required this.phone,
    required this.role,
    required this.is2faEnabled,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id'] as int,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: (json['role'] ?? '').toString(),
      is2faEnabled: (json['is_2fa_enabled'] ?? false) as bool,
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
}
