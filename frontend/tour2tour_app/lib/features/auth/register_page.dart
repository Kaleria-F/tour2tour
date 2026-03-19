import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _codeSent = false;

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await widget.auth.requestRegisterCode(
        email: _email.text.trim(),
        password: _password.text,
        phone: normalizePhoneForApi(_phone.text),
      );
      if (!mounted) return;
      setState(() => _codeSent = true);
      showAuthSuccess(context, 'Код подтверждения отправлен на email.');
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
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const _NightBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 14),
                      _Logo(cs: cs),
                      const SizedBox(height: 18),
                      Text(
                        _codeSent ? 'Подтверждение email' : 'Регистрация',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Уже есть аккаунт? ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Войти',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Form(
                        key: _formKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              _FieldRow(
                                icon: Icons.mail_outline_rounded,
                                child: TextFormField(
                                  controller: _email,
                                  enabled: !_codeSent,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    hintText: 'Email',
                                    border: InputBorder.none,
                                  ),
                                  validator: (value) {
                                    final email = (value ?? '').trim();
                                    if (email.isEmpty) return 'Введите email';
                                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
                                      return 'Некорректный email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Divider(height: 1, thickness: 1, color: Colors.black.withOpacity(0.08)),
                              _FieldRow(
                                icon: Icons.phone_outlined,
                                child: TextFormField(
                                  controller: _phone,
                                  enabled: !_codeSent,
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [AutofillHints.telephoneNumber],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s()+-]')),
                                    RussianPhoneInputFormatter(),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Телефон (необязательно)',
                                    border: InputBorder.none,
                                  ),
                                  validator: (value) {
                                    final phone = (value ?? '').trim();
                                    if (phone.isEmpty) return null;
                                    if (!RegExp(r'^\+7\d{10}$').hasMatch(normalizePhoneForApi(phone))) {
                                      return 'Некорректный номер телефона';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Divider(height: 1, thickness: 1, color: Colors.black.withOpacity(0.08)),
                              _FieldRow(
                                icon: Icons.lock_outline_rounded,
                                trailing: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.black.withOpacity(0.45),
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                child: TextFormField(
                                  controller: _password,
                                  enabled: !_codeSent,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.newPassword],
                                  decoration: const InputDecoration(
                                    hintText: 'Пароль',
                                    border: InputBorder.none,
                                  ),
                                  validator: (value) {
                                    final password = value ?? '';
                                    if (password.isEmpty) return 'Введите пароль';
                                    if (password.length < 8) return 'Минимум 8 символов';
                                    if (!RegExp(r'[A-Z]').hasMatch(password)) {
                                      return 'Добавьте хотя бы одну заглавную букву';
                                    }
                                    if (!RegExp(r'[a-z]').hasMatch(password)) {
                                      return 'Добавьте хотя бы одну строчную букву';
                                    }
                                    if (!RegExp(r'\d').hasMatch(password)) {
                                      return 'Добавьте хотя бы одну цифру';
                                    }
                                    if (!RegExp(r"""[~!?@#$%^&*_\-\+()\[\]{}><\/\\|"'.:,]""").hasMatch(password)) {
                                      return 'Добавьте хотя бы один спецсимвол';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_codeSent) ...[
                                Divider(height: 1, thickness: 1, color: Colors.black.withOpacity(0.08)),
                                _FieldRow(
                                  icon: Icons.mark_email_read_outlined,
                                  child: TextField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Код из email',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.primary.withOpacity(0.75)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _loading ? null : (_codeSent ? _confirmRegistration : _requestCode),
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _codeSent ? 'Подтвердить email' : 'Получить код',
                                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ),
                      if (_codeSent) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _requestCode,
                          child: Text(
                            'Отправить код еще раз',
                            style: TextStyle(color: Colors.white.withOpacity(0.85)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final ColorScheme cs;

  const _Logo({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withOpacity(0.28)),
      ),
      child: Icon(Icons.shield_rounded, color: cs.primary, size: 28),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _FieldRow({
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(icon, size: 20, color: Colors.black.withOpacity(0.45)),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15.5),
              child: child,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _NightBackground extends StatelessWidget {
  const _NightBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NightPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _NightPainter extends CustomPainter {
  final _rng = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0B1023),
        Color(0xFF090D1A),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final vignette = RadialGradient(
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.55),
      ],
      stops: const [0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = vignette.createShader(rect));

    final starPaint = Paint()..color = Colors.white.withOpacity(0.55);
    final starPaintDim = Paint()..color = Colors.white.withOpacity(0.22);

    final count = (size.width * size.height / 6500).clamp(70, 170).toInt();
    for (var i = 0; i < count; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height * 0.6;
      final r = _rng.nextDouble() * 1.35 + 0.2;
      canvas.drawCircle(Offset(x, y), r, (i % 3 == 0) ? starPaint : starPaintDim);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
