import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';

class TotpVerifyPage extends StatefulWidget {
  final AuthRepo auth;
  final String challengeId;
  final List<String> factors;

  const TotpVerifyPage({
    super.key,
    required this.auth,
    required this.challengeId,
    required this.factors,
  });

  @override
  State<TotpVerifyPage> createState() => _TotpVerifyPageState();
}

class _TotpVerifyPageState extends State<TotpVerifyPage> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _code.text.trim();
    if (value.length != 6) {
      showAuthError(context, 'Введите шестизначный код из Authenticator.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.auth.verifySecondFactor(
        challengeId: widget.challengeId,
        code: value,
      );
      if (!mounted) return;
      context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      showAuthError(context, e.toString());
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
            const AuthBrandMark(
              title: 'Typ2Typ',
              subtitle: 'Защищенный вход в аккаунт',
            ),
            const SizedBox(height: 22),
            AuthHeadline(
              title: 'Подтверждение входа',
              fontSize: 34,
              fontWeight: FontWeight.w300,
              description: 'Введите 6-значный код из приложения-аутентификатора, чтобы завершить вход.',
              trailing: AuthPillButton(
                label: 'Назад',
                icon: Icons.close_rounded,
                minimumSize: const Size(96, 38),
                fontSize: 12,
                iconSize: 13,
                onPressed: () => context.go('/login'),
              ),
            ),
            const SizedBox(height: 18),
            AuthSectionChip(
              label: widget.factors.isEmpty ? 'TOTP' : widget.factors.join(' · ').toUpperCase(),
              icon: Icons.verified_user_rounded,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _code,
              hintText: 'код из Authenticator',
              icon: Icons.shield_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              maxLength: 6,
            ),
            const SizedBox(height: 14),
            const AuthHelperText(
              text: 'Код обновляется каждые 30 секунд. Если код не подходит, дождитесь нового значения в приложении.',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                label: 'Подтвердить',
                width: 190,
                loading: _loading,
                onTap: _loading ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
