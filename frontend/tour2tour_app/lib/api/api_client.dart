import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiClient {
  ApiClient._();

  static final _storage = FlutterSecureStorage();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

  static Future<void> saveToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  static Future<void> clearToken() => _storage.delete(key: 'access_token');

  static Future<String?> getToken() => _storage.read(key: 'access_token');
}
