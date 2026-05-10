import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../core/session_coordinator.dart';
import '../core/token_storage.dart';

class ApiClient {
  final TokenStorage tokenStorage;
  late final Dio dio;

  ApiClient(this.tokenStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: Config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode ?? 0;
          final hadBearerToken =
              (error.requestOptions.headers['Authorization']?.toString() ?? '')
                  .startsWith('Bearer ');
          final isAuthRequest = error.requestOptions.path.startsWith('/auth/');

          if (kIsWeb &&
              (statusCode == 401 || statusCode == 403) &&
              hadBearerToken &&
              !isAuthRequest) {
            await tokenStorage.clear();
            SessionCoordinator.instance.handleWebSessionExpired();
          }

          handler.next(error);
        },
      ),
    );
  }

  //Метод для создания путешествий
  Future<Response?> createTrip(Map<String, dynamic> data) async {
    try {
      return await dio.post('/trips/', data: data);
    } catch (e) {
      print('Ошибка при создании путешествия: $e');
      return null;
    }
  }
}
