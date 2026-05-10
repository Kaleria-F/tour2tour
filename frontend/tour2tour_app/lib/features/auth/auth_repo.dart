import 'package:dio/dio.dart';

import '../../api/api_client.dart';
import '../../core/session_coordinator.dart';
import '../../core/token_storage.dart';

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

class LoginResult {
  final String? accessToken;
  final bool requires2fa;
  final String? challengeId;
  final List<String> availableFactors;

  const LoginResult({
    required this.accessToken,
    required this.requires2fa,
    required this.challengeId,
    required this.availableFactors,
  });
}

class AuthRepo {
  final ApiClient api;
  final TokenStorage tokenStorage;

  AuthRepo(this.api, this.tokenStorage);

  String _translateDetail(String detail) {
    const translations = <String, String>{
      'User already exists.': 'Пользователь с такими данными уже существует.',
      'Verification code is invalid or expired.': 'Код подтверждения неверный или истек.',
      'Invalid credentials.': 'Неверный email или пароль.',
      'Invalid code.': 'Неверный код подтверждения.',
      '2FA challenge expired.': 'Сессия подтверждения истекла. Войдите снова.',
      'User not found.': 'Пользователь не найден.',
      'TOTP is not configured for this account.': 'Для аккаунта не настроен TOTP.',
      'TOTP secret is missing.': 'Не удалось проверить TOTP-код.',
      'Run /auth/totp/setup first.': 'Сначала настройте TOTP.',
      'No second factor is configured.': 'Второй фактор не настроен.',
      'Step-up challenge is invalid.': 'Сессия подтверждения недействительна.',
      'TOTP is unavailable for verification.': 'TOTP недоступен для подтверждения.',
      'Current password is invalid.': 'Текущий пароль введен неверно.',
      'New password must differ from the current one.': 'Новый пароль должен отличаться от текущего.',
      'A valid second-factor code is required.': 'Введите корректный код второго фактора.',
      'Email confirmation code is required.': 'Введите код подтверждения из email.',
      'Email confirmation code is invalid or expired.': 'Код подтверждения из email неверный или истек.',
      'TOTP code is required.': 'Введите TOTP-код из приложения-аутентификатора.',
      'Invalid TOTP code.': 'Неверный TOTP-код.',
      'Email is not set for this account.': 'Для аккаунта не указан email.',
      'Recovery code is invalid or expired.': 'Код восстановления неверный или истек.',
      'Additional phone verification failed.': 'Не пройдена дополнительная проверка.',
      'Email or phone is required.': 'Укажите email или телефон.',
      'Temporary auth storage is unavailable.': 'Сервис временно недоступен. Попробуйте позже.',
      'Too many requests. Please try again later.': 'Слишком много попыток. Попробуйте позже.',
    };
    return translations[detail] ?? detail;
  }

  String _extractMessage(Object error) {
    if (error is AuthFailure) return error.message;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return _translateDetail(detail);
        }
        if (detail is List && detail.isNotEmpty) {
          final messages = detail
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item['msg']?.toString() ?? '';
                }
                return item.toString();
              })
              .where((item) => item.trim().isNotEmpty)
              .join('\n');
          if (messages.isNotEmpty) return messages;
        }
      }
      switch (error.response?.statusCode) {
        case 400:
          return 'Проверьте корректность введенных данных.';
        case 401:
          return 'Неверные учетные данные или код подтверждения.';
        case 409:
          return 'Пользователь с такими данными уже существует.';
        case 429:
          return 'Слишком много попыток. Попробуйте позже.';
        case 503:
          return 'Сервис временно недоступен. Попробуйте позже.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Сервер отвечает слишком долго. Попробуйте еще раз.';
        case DioExceptionType.connectionError:
          return 'Не удалось подключиться к серверу.';
        default:
          break;
      }
    }
    return 'Произошла ошибка. Попробуйте еще раз.';
  }

  Never _throwFriendly(Object error) {
    throw AuthFailure(_extractMessage(error));
  }

  Future<void> requestRegisterCode({
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      await api.dio.post(
        '/auth/register/request-code',
        data: {
          'email': email,
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> register({
    required String email,
    required String code,
  }) async {
    try {
      await api.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'code': code,
        },
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final Response res = await api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = res.data as Map<String, dynamic>;
      final requires2fa = data['requires_2fa'] == true;
      final challengeId = data['challenge_id']?.toString();
      final availableFactors =
          (data['available_factors'] as List? ?? const [])
              .map((e) => e.toString())
              .toList();

      final token = data['access_token'] as String?;
      if (requires2fa) {
        return LoginResult(
          accessToken: null,
          requires2fa: true,
          challengeId: challengeId,
          availableFactors: availableFactors,
        );
      }

      if (token == null || token.isEmpty) {
        throw const AuthFailure('Сервер не вернул токен доступа.');
      }

      await tokenStorage.write(token);
      SessionCoordinator.instance.resetWebSessionExpiryState();
      return LoginResult(
        accessToken: token,
        requires2fa: false,
        challengeId: null,
        availableFactors: const [],
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> verifySecondFactor({
    required String challengeId,
    required String code,
  }) async {
    try {
      final Response res = await api.dio.post(
        '/auth/2fa/verify',
        data: {
          'challenge_id': challengeId,
          'code': code,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthFailure('Сервер не вернул токен доступа.');
      }
      await tokenStorage.write(token);
      SessionCoordinator.instance.resetWebSessionExpiryState();
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<Map<String, dynamic>> securityStatus() async {
    try {
      final res = await api.dio.get('/auth/security/status');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<Map<String, dynamic>> setupTotp() async {
    try {
      final res = await api.dio.post('/auth/totp/setup');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> enableTotp(String code) async {
    try {
      await api.dio.post('/auth/totp/enable', data: {'code': code});
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> enablePasskey() async {
    try {
      await api.dio.post('/auth/passkey/enable');
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? totpCode,
    String? emailCode,
  }) async {
    try {
      await api.dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          if (totpCode != null && totpCode.isNotEmpty) 'totp_code': totpCode,
          if (emailCode != null && emailCode.isNotEmpty) 'email_code': emailCode,
        },
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> requestChangePasswordCode() async {
    try {
      await api.dio.post('/auth/change-password/request-code', data: {});
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> requestRecoveryCode(String email) async {
    try {
      await api.dio.post('/auth/recovery/request', data: {'email': email});
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> confirmRecovery({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await api.dio.post(
        '/auth/recovery/confirm',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> logout() async {
    await tokenStorage.clear();
    SessionCoordinator.instance.resetWebSessionExpiryState();
  }
}
