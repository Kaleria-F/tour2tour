import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_repo.dart';

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
    if (value.isEmpty) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPasskey = widget.factors.contains('passkey');
    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение входа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPasskey)
              const Text(
                'Passkey будет поддержан отдельным потоком WebAuthn. Сейчас доступно подтверждение через TOTP.',
              ),
            const SizedBox(height: 16),
            const Text('Введите 6-значный код из Authenticator'),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'TOTP код',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Подтвердить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
