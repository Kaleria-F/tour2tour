import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _totp.dispose();
    _emailCode.dispose();
    super.dispose();
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
      showAuthSuccess(context, 'Пароль успешно изменен.');
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
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Logo(cs: cs),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Смена пароля',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/profile'),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLoading
                                      ? 'Проверяем настройки безопасности...'
                                      : _secondFactorRequired
                                          ? 'Для смены пароля нужен текущий пароль, код из email и TOTP-код.'
                                          : 'Для смены пароля нужен текущий пароль и код из email.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.82),
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _field(
                                  controller: _current,
                                  label: 'Текущий пароль',
                                  obscure: true,
                                ),
                                const SizedBox(height: 10),
                                _field(
                                  controller: _next,
                                  label: 'Новый пароль',
                                  obscure: true,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        controller: _emailCode,
                                        label: 'Код из email',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: _requestingCode ? null : _requestEmailCode,
                                      child: _requestingCode
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Отправить'),
                                    ),
                                  ],
                                ),
                                if (_secondFactorRequired && _totpEnabled) ...[
                                  const SizedBox(height: 10),
                                  _field(
                                    controller: _totp,
                                    label: 'TOTP-код',
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: (_loading || _statusLoading) ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Изменить пароль',
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
        border: const OutlineInputBorder(),
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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Icon(Icons.password_rounded, color: cs.primary),
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
      colors: [Color(0xFF0B1023), Color(0xFF090D1A)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final vignette = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
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
