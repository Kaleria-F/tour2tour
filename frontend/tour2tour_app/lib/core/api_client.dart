import 'package:dio/dio.dart';
import '../config.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient(this.tokenStorage)
      : dio = Dio(BaseOptions(baseUrl: Config.apiBaseUrl)) {
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
