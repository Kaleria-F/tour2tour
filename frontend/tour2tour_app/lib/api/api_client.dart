import 'package:dio/dio.dart';
import '../config.dart';
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
      ),
    );
  }
}
