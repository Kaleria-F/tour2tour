import '../../core/api_client.dart';

class AuthRepo {
  final ApiClient api;
  AuthRepo(this.api);

  Future<void> register({required String email, required String password}) async {
    await api.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
  }

  Future<void> login({required String email, required String password}) async {
    final res = await api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final token = res.data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('No token');
    await api.tokenStorage.save(token);
  }

  Future<void> logout() => api.tokenStorage.clear();
}
