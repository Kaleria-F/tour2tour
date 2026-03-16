import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_repo.dart';

class SecuritySetupPage extends StatefulWidget {
  final AuthRepo auth;

  const SecuritySetupPage({super.key, required this.auth});

  @override
  State<SecuritySetupPage> createState() => _SecuritySetupPageState();
}

class _SecuritySetupPageState extends State<SecuritySetupPage> {
  bool _loading = false;
  String? _totpSecret;
  String? _totpUri;
  final _totpCode = TextEditingController();

  @override
  void dispose() {
    _totpCode.dispose();
    super.dispose();
  }

  Future<void> _enablePasskeyStub() async {
    setState(() => _loading = true);
    try {
      await widget.auth.enablePasskey();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passkey помечен как активный (stub flow).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmTotp() async {
    final code = _totpCode.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.auth.enableTotp(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TOTP подключен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Защита аккаунта')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'После регистрации подключите Passkey или TOTP. Это будет использоваться как второй фактор после входа по паролю.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1) Passkey', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Рекомендуется как основной метод.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loading ? null : _enablePasskeyStub,
                    child: const Text('Создать passkey (временный stub)'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2) TOTP', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Google Authenticator / Microsoft Authenticator / 1Password'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _loading ? null : _startTotp,
                    child: const Text('Сгенерировать секрет TOTP'),
                  ),
                  if (_totpSecret != null) ...[
                    const SizedBox(height: 10),
                    SelectableText('Secret: $_totpSecret'),
                    if (_totpUri != null) SelectableText('URI: $_totpUri'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _totpCode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Код из приложения',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _loading ? null : _confirmTotp,
                      child: const Text('Подтвердить TOTP'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/preferences'),
            child: const Text('Продолжить в анкету интересов'),
          ),
          TextButton(
            onPressed: () => context.go('/profile'),
            child: const Text('Пропустить сейчас'),
          ),
        ],
      ),
    );
  }
}
