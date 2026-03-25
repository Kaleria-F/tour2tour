import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      showAuthError(context, 'Р’РІРµРґРёС‚Рµ С€РµСЃС‚РёР·РЅР°С‡РЅС‹Р№ TOTP-РєРѕРґ.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.auth.enableTotp(code);
      if (!mounted) return;
      showAuthSuccess(context, 'TOTP СѓСЃРїРµС€РЅРѕ РїРѕРґРєР»СЋС‡РµРЅ.');
      _totpSecret = null;
      _totpUri = null;
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
    final cs = Theme.of(context).colorScheme;
    final isConfigured = _secondFactorRequired || _totpEnabled;

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
                          Expanded(
                            child: Text(
                              isConfigured ? 'РќР°СЃС‚СЂРѕР№РєРё Р±РµР·РѕРїР°СЃРЅРѕСЃС‚Рё' : 'РџРѕРґРєР»СЋС‡РµРЅРёРµ Р·Р°С‰РёС‚С‹',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Text(
                                _statusLoading
                                    ? 'РџСЂРѕРІРµСЂСЏРµРј С‚РµРєСѓС‰РёРµ РЅР°СЃС‚СЂРѕР№РєРё Р±РµР·РѕРїР°СЃРЅРѕСЃС‚Рё...'
                                    : isConfigured
                                        ? 'Р—Р°С‰РёС‚Р° Р°РєРєР°СѓРЅС‚Р° СѓР¶Рµ РЅР°СЃС‚СЂРѕРµРЅР°. Р—РґРµСЃСЊ РјРѕР¶РЅРѕ РїРѕСЃРјРѕС‚СЂРµС‚СЊ Р°РєС‚РёРІРЅС‹Рµ СЃРїРѕСЃРѕР±С‹ РІС…РѕРґР° Рё РґРѕР±Р°РІРёС‚СЊ РЅРµРґРѕСЃС‚Р°СЋС‰РёРµ.'
                                        : 'РџРѕРґРєР»СЋС‡РёС‚Рµ РІС‚РѕСЂРѕР№ С„Р°РєС‚РѕСЂ, С‡С‚РѕР±С‹ СѓСЃРёР»РёС‚СЊ Р·Р°С‰РёС‚Сѓ РІС…РѕРґР° РІ Р°РєРєР°СѓРЅС‚.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _sectionCard(
                              title: 'TOTP',
                              status: _statusLoading
                                  ? 'РџСЂРѕРІРµСЂРєР°...'
                                  : (_totpEnabled ? 'РџРѕРґРєР»СЋС‡РµРЅ' : 'РќРµ РїРѕРґРєР»СЋС‡РµРЅ'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _totpEnabled
                                        ? 'Р’С…РѕРґ РїРѕ РїР°СЂРѕР»СЋ Р±СѓРґРµС‚ РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РїРѕРґС‚РІРµСЂР¶РґР°С‚СЊСЃСЏ РєРѕРґРѕРј РёР· РїСЂРёР»РѕР¶РµРЅРёСЏ-Р°СѓС‚РµРЅС‚РёС„РёРєР°С‚РѕСЂР°.'
                                        : 'Google Authenticator, Microsoft Authenticator РёР»Рё 1Password.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.82),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (!_totpEnabled) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      onPressed: _loading ? null : _startTotp,
                                      child: const Text('РЎРіРµРЅРµСЂРёСЂРѕРІР°С‚СЊ TOTP-СЃРµРєСЂРµС‚'),
                                    ),
                                  ],
                                  if (_totpSecret != null) ...[
                                    const SizedBox(height: 10),
                                    SelectableText(
                                      'Secret: $_totpSecret',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    if (_totpUri != null)
                                      SelectableText(
                                        'URI: $_totpUri',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _totpCode,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'РљРѕРґ РёР· РїСЂРёР»РѕР¶РµРЅРёСЏ',
                                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: _loading ? null : _confirmTotp,
                                      child: const Text('РџРѕРґС‚РІРµСЂРґРёС‚СЊ TOTP'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
                            onPressed: () => context.go('/preferences'),
                            child: const Text(
                              'РџСЂРѕРґРѕР»Р¶РёС‚СЊ',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/profile'),
                        child: Text(
                          'Р’РµСЂРЅСѓС‚СЊСЃСЏ РІ РїСЂРѕС„РёР»СЊ',
                          style: TextStyle(color: Colors.white.withOpacity(0.85)),
                        ),
                      ),
                      const SizedBox(height: 10),
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

  Widget _sectionCard({
    required String title,
    required String status,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
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
      child: Icon(Icons.security_rounded, color: cs.primary),
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

