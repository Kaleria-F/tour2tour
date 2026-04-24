import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';

class LoginPage extends StatefulWidget {
  final AuthRepo auth;

  const LoginPage({super.key, required this.auth});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty) {
      showAuthError(context, 'Введите email.');
      return;
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      showAuthError(context, 'Введите корректный email.');
      return;
    }
    if (password.length < 8) {
      showAuthError(context, 'Пароль должен быть не короче 8 символов.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await widget.auth.login(email: email, password: password);
      if (!mounted) return;

      if (result.requires2fa && result.challengeId != null) {
        context.go(
          '/totp-verify',
          extra: {
            'challenge_id': result.challengeId!,
            'factors': result.availableFactors,
          },
        );
        return;
      }

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
    return AuthScaffold(
      maxWidth: 560,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 18),
      child: AuthGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrandMark(title: 'Typ2Typ'),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: AuthHeadline(
                    title: 'Вход',
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    titleHeight: 0.92,
                  ),
                ),
                const SizedBox(width: 12),
                Transform.translate(
                  offset: const Offset(0, 6),
                  child: AuthPillButton(
                    label: 'Зарегистрироваться',
                    icon: Icons.person_add_alt_1_rounded,
                    fontSize: 11,
                    iconSize: 14,
                    onPressed: () => context.go('/register'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: _email,
              hintText: 'почта',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _password,
              hintText: 'пароль',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() {}),
              suffix: _password.text.isEmpty
                  ? TextButton(
                      onPressed: () => context.go('/recovery'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD7E37A),
                        backgroundColor: const Color(0xFF2F372E).withOpacity(0.92),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: Color(0x335F6B58)),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      child: const Text('я забыл(а)'),
                    )
                  : Transform.translate(
                      offset: const Offset(8, 0),
                      child: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFFD7E37A),
                          size: 22,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                loading: _loading,
                onTap: _loading ? null : _login,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
