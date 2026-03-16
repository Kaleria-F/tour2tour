import 'package:dio/dio.dart';
import '../../api/api_client.dart';
import '../../core/token_storage.dart';

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

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
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
      throw Exception('Backend не вернул access_token');
    }

    await tokenStorage.write(token);
    return LoginResult(
      accessToken: token,
      requires2fa: false,
      challengeId: null,
      availableFactors: const [],
    );
  }

  Future<void> verifySecondFactor({
    required String challengeId,
    required String code,
  }) async {
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
      throw Exception('Backend не вернул access_token');
    }
    await tokenStorage.write(token);
  }

  Future<Map<String, dynamic>> securityStatus() async {
    final res = await api.dio.get('/auth/security/status');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setupTotp() async {
    final res = await api.dio.post('/auth/totp/setup');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> enableTotp(String code) async {
    await api.dio.post('/auth/totp/enable', data: {'code': code});
  }

  Future<void> enablePasskey() async {
    await api.dio.post('/auth/passkey/enable');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? totpCode,
    String? emailCode,
  }) async {
    await api.dio.post(
      '/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        if (totpCode != null && totpCode.isNotEmpty) 'totp_code': totpCode,
        if (emailCode != null && emailCode.isNotEmpty) 'email_code': emailCode,
      },
    );
  }

  Future<void> requestChangePasswordCode() async {
    await api.dio.post('/auth/change-password/request-code', data: {});
  }

  Future<void> requestRecoveryCode(String email) async {
    await api.dio.post('/auth/recovery/request', data: {'email': email});
  }

  Future<void> confirmRecovery({
    required String email,
    required String code,
    required String newPassword,
    String? phoneLast4,
  }) async {
    await api.dio.post(
      '/auth/recovery/confirm',
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
        if (phoneLast4 != null && phoneLast4.isNotEmpty) 'phone_last4': phoneLast4,
      },
    );
  }

  Future<void> logout() => tokenStorage.clear();
}
