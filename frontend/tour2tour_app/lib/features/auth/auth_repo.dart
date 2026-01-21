import 'package:dio/dio.dart';
import '../../api/api_client.dart';
import '../../core/token_storage.dart';

class AuthRepo {
  final ApiClient api;
  final TokenStorage tokenStorage;

  AuthRepo(this.api, this.tokenStorage);

  Future<void> register({
    required String email,
    required String password,
    String? phone,
  }) async {
    await api.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final Response res = await api.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = res.data as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Backend не вернул access_token');
    }

    await tokenStorage.write(token);
    return token;
  }

  Future<void> logout() => tokenStorage.clear();
}
