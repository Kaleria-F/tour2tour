import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';

class ChangePasswordPage extends StatefulWidget {
  final AuthRepo auth;

  const ChangePasswordPage({super.key, required this.auth});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _totp = TextEditingController();
  final _emailCode = TextEditingController();

  bool _loading = false;
  bool _requestingCode = false;
  bool _statusLoading = true;
  bool _totpEnabled = false;
  bool _secondFactorRequired = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _totp.dispose();
    _emailCode.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.auth.securityStatus();
      if (!mounted) return;
      setState(() {
        _totpEnabled = status['totp_enabled'] == true;
        _secondFactorRequired = status['second_factor_required'] == true;
      });
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _requestEmailCode() async {
    if (_current.text.isEmpty) {
      showAuthError(context, 'Сначала введите текущий пароль.');
      return;
    }
    if (_next.text.length < 8) {
      showAuthError(context, 'Новый пароль должен быть не короче 8 символов.');
      return;
    }

    setState(() => _requestingCode = true);
    try {
      await widget.auth.requestChangePasswordCode();
      if (!mounted) return;
      showAuthSuccess(context, 'Код подтверждения отправлен на email.');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _requestingCode = false);
    }
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      showAuthError(context, 'Введите текущий пароль.');
      return;
    }
    if (_next.text.length < 8) {
      showAuthError(context, 'Новый пароль должен быть не короче 8 символов.');
      return;
    }
    if (_emailCode.text.trim().length != 6) {
      showAuthError(context, 'Введите код подтверждения из email.');
      return;
    }
    if (_secondFactorRequired && _totpEnabled && _totp.text.trim().length != 6) {
      showAuthError(context, 'Введите TOTP-код из приложения-аутентификатора.');
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        totpCode: _totp.text.trim().isEmpty ? null : _totp.text.trim(),
        emailCode: _emailCode.text.trim(),
      );
      if (!mounted) return;
      showAuthSuccess(context, 'Пароль успешно изменён.');
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiresTotp = _secondFactorRequired && _totpEnabled;

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
                  icon: Icons.close_rounded,
                  minimumSize: const Size(104, 38),
                  fontSize: 12,
                  iconSize: 13,
                  onPressed: () => context.go('/account'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AuthHeadline(
              title: 'Смена пароля',
              fontSize: 34,
              fontWeight: FontWeight.w300,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _current,
              hintText: 'текущий пароль',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _next,
              hintText: 'новый пароль',
              icon: Icons.lock_reset_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _emailCode,
                    hintText: 'код из email',
                    icon: Icons.mark_email_read_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                AuthPillButton(
                  label: _requestingCode ? 'Отправка...' : 'Отправить код',
                  icon: Icons.mail_outline_rounded,
                  onPressed: _requestingCode ? null : _requestEmailCode,
                ),
              ],
            ),
            if (requiresTotp) ...[
              const SizedBox(height: 14),
              AuthTextField(
                controller: _totp,
                hintText: 'TOTP-код',
                icon: Icons.shield_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 14),
            AuthHelperText(
              text: _statusLoading
                  ? 'Проверяем настройки безопасности.'
                  : requiresTotp
                      ? 'Для подтверждения понадобятся текущий пароль, код из email и TOTP-код.'
                      : 'Для подтверждения понадобятся текущий пароль и код из email.',
            ),
            const SizedBox(height: 14),
            const AuthHelperText(
              text: 'После подтверждения новый пароль начнет работать сразу. Старый пароль станет недействительным.',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                label: 'Изменить пароль',
                width: 230,
                loading: _loading,
                onTap: (_loading || _statusLoading) ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
