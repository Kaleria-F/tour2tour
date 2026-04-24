import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';

class SecuritySetupPage extends StatefulWidget {
  final AuthRepo auth;

  const SecuritySetupPage({super.key, required this.auth});

  @override
  State<SecuritySetupPage> createState() => _SecuritySetupPageState();
}

class _SecuritySetupPageState extends State<SecuritySetupPage> {
  bool _loading = false;
  bool _statusLoading = true;
  bool _totpEnabled = false;
  bool _secondFactorRequired = false;
  String? _totpSecret;
  String? _totpUri;
  final _totpCode = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _totpCode.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _statusLoading = true);
    try {
      final data = await widget.auth.securityStatus();
      if (!mounted) return;
      setState(() {
        _totpEnabled = data['totp_enabled'] == true;
        _secondFactorRequired = data['second_factor_required'] == true;
      });
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _startTotp() async {
    setState(() => _loading = true);
    try {
      final data = await widget.auth.setupTotp();
      if (!mounted) return;
      setState(() {
        _totpSecret = data['secret']?.toString();
        _totpUri = data['otpauth_uri']?.toString();
      });
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmTotp() async {
    final code = _totpCode.text.trim();
    if (code.length != 6) {
      showAuthError(context, 'Введите шестизначный TOTP-код.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.auth.enableTotp(code);
      if (!mounted) return;
      showAuthSuccess(context, 'TOTP успешно подключен.');
      setState(() {
        _totpSecret = null;
        _totpUri = null;
      });
      _totpCode.clear();
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = _secondFactorRequired || _totpEnabled;

    return AuthScaffold(
      maxWidth: 640,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 18),
      child: AuthGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: AuthBrandMark(title: 'Typ2Typ')),
                AuthPillButton(
                  label: 'Профиль',
                  icon: Icons.arrow_forward_rounded,
                  minimumSize: const Size(110, 38),
                  fontSize: 12,
                  iconSize: 13,
                  onPressed: () => context.go('/account'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AuthHeadline(
              title: isConfigured ? 'Настройки безопасности' : 'Подключение защиты',
              fontSize: 34,
              fontWeight: FontWeight.w300,
              description: _statusLoading
                  ? 'Проверяем текущие настройки безопасности.'
                  : isConfigured
                      ? 'Второй фактор уже подключен. Здесь можно посмотреть активный способ входа и при необходимости обновить настройки.'
                      : 'Подключите второй фактор, чтобы вход в аккаунт требовал не только пароль, но и код из приложения-аутентификатора.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                AuthSectionChip(
                  label: _statusLoading
                      ? 'Проверка...'
                      : (_totpEnabled ? 'TOTP подключен' : 'TOTP не подключен'),
                  icon: Icons.security_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AuthHelperText(
              text: 'Поддерживаются Google Authenticator, Microsoft Authenticator, 1Password и другие приложения с TOTP.',
            ),
            const SizedBox(height: 16),
            if (!_totpEnabled)
              AuthPillButton(
                label: 'Сгенерировать TOTP-секрет',
                icon: Icons.qr_code_2_rounded,
                onPressed: _loading ? null : _startTotp,
              ),
            if (_totpSecret != null) ...[
              const SizedBox(height: 18),
              const AuthSectionChip(
                label: 'Секрет для привязки',
                icon: Icons.key_rounded,
              ),
              const SizedBox(height: 12),
              SelectableText(
                'Secret: $_totpSecret',
                style: const TextStyle(
                  color: Color(0xFFF3F6EE),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_totpUri != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _totpUri!,
                  style: const TextStyle(
                    color: Color(0xFFAEB7A4),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AuthTextField(
                controller: _totpCode,
                hintText: 'код из приложения',
                icon: Icons.password_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: AuthOrganicButton(
                  label: 'Подтвердить TOTP',
                  width: 220,
                  loading: _loading,
                  onTap: _loading ? null : _confirmTotp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
