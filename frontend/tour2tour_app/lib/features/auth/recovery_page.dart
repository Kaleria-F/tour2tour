import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_repo.dart';

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
  final _phoneLast4 = TextEditingController();
  bool _codeRequested = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _phoneLast4.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() => _loading = true);
    try {
      await widget.auth.requestRecoveryCode(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен на email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.auth.confirmRecovery(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
        phoneLast4: _phoneLast4.text.trim().isEmpty ? null : _phoneLast4.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль восстановлен. Войдите снова.')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
                              'Восстановление пароля',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                              children: [
                                TextField(
                                  controller: _email,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (!_codeRequested)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _requestCode,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Отправить код'),
                                    ),
                                  )
                                else ...[
                                  TextField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Код из email',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _password,
                                    obscureText: true,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Новый пароль',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _phoneLast4,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Последние 4 цифры телефона (если есть)',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _confirm,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Подтвердить восстановление'),
                                    ),
                                  ),
                                ],
                              ],
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
      child: Icon(Icons.lock_reset_rounded, color: cs.primary),
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
