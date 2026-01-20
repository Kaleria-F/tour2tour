import 'package:dio/dio.dart';
import '../api/api_client.dart';

class AuthRepository {
  final Dio _dio = ApiClient.dio;

  Future<void> register({required String email, required String password, String? phone}) async {
    await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<String> login({required String email, required String password}) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = (res.data as Map<String, dynamic>)['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('No access_token in response');
    }
    await ApiClient.saveToken(token);
    return token;
  }
}
