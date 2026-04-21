import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';

class RecoveryPage extends StatefulWidget {
  final AuthRepo auth;

  const RecoveryPage({super.key, required this.auth});

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeRequested = false;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      showAuthError(context, 'Введите корректный email.');
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.requestRecoveryCode(email);
      if (!mounted) return;
      setState(() => _codeRequested = true);
      showAuthSuccess(context, 'Код восстановления отправлен на email.');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length != 6) {
      showAuthError(context, 'Введите шестизначный код из письма.');
      return;
    }
    if (_password.text.length < 8) {
      showAuthError(context, 'Новый пароль должен быть не короче 8 символов.');
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.confirmRecovery(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      showAuthSuccess(context, 'Пароль изменен. Теперь войдите снова.');
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 560,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 18),
      child: AuthGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrandMark(title: 'Typ2Typ'),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _codeRequested ? 'Новый пароль' : 'Восстановление',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      height: 0.92,
                      color: Colors.black,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AuthPillButton(
                  label: 'Войти',
                  icon: Icons.login_rounded,
                  minimumSize: const Size(92, 38),
                  fontSize: 12,
                  iconSize: 13,
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _email,
              hintText: 'почта',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              enabled: !_codeRequested,
            ),
            if (_codeRequested) ...[
              const SizedBox(height: 14),
              AuthTextField(
                controller: _code,
                hintText: 'код из письма',
                icon: Icons.mark_email_read_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                maxLength: 6,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                hintText: 'новый пароль',
                icon: Icons.lock_reset_rounded,
                obscureText: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF2F241F),
                    size: 22,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                label: _codeRequested ? 'Готово' : null,
                width: _codeRequested ? 162 : 108,
                loading: _loading,
                onTap: _loading ? null : (_codeRequested ? _confirm : _requestCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
