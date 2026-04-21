import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth_chrome.dart';
import 'auth_repo.dart';
import 'auth_ui.dart';
import 'phone_input_formatter.dart';

class RegisterPage extends StatefulWidget {
  final AuthRepo auth;

  const RegisterPage({super.key, required this.auth});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    final password = _password.text;

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
      await widget.auth.requestRegisterCode(
        email: email,
        password: password,
        phone: normalizePhoneForApi(_phone.text),
      );
      if (!mounted) return;
      setState(() => _codeSent = true);
      showAuthSuccess(context, 'Код отправлен на почту.');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRegistration() async {
    if (_code.text.trim().length != 6) {
      showAuthError(context, 'Введите шестизначный код из письма.');
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.register(
        email: _email.text.trim(),
        code: _code.text.trim(),
      );
      await widget.auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      context.go('/security-setup');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _codeSent ? 'Код' : 'Регистрация';

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
            if (_codeSent)
              AuthHeadline(
                title: title,
                fontSize: 34,
                fontWeight: FontWeight.w300,
                titleHeight: 0.92,
                trailing: AuthPillButton(
                  label: 'Войти',
                  icon: Icons.login_rounded,
                  minimumSize: const Size(104, 38),
                  fontSize: 12,
                  iconSize: 13,
                  onPressed: () => context.go('/login'),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        height: 0.92,
                        color: Colors.black,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Transform.translate(
                    offset: const Offset(0, 6),
                    child: AuthPillButton(
                      label: 'Войти',
                      icon: Icons.login_rounded,
                      minimumSize: const Size(92, 38),
                      fontSize: 12,
                      iconSize: 13,
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _email,
              hintText: 'почта',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_codeSent,
            ),
            const SizedBox(height: 14),
            if (_codeSent)
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
              )
            else ...[
              AuthTextField(
                controller: _phone,
                hintText: 'телефон',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [RussianPhoneInputFormatter()],
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                hintText: 'пароль',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                suffix: Transform.translate(
                  offset: const Offset(10, 0),
                  child: IconButton(
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
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                label: _codeSent ? 'Готово' : null,
                width: _codeSent ? 162 : 108,
                loading: _loading,
                onTap: _loading
                    ? null
                    : (_codeSent ? _confirmRegistration : _requestCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
