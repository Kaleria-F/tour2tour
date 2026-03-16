import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_repo.dart';

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

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _totp.dispose();
    _emailCode.dispose();
    super.dispose();
  }

  Future<void> _requestEmailCode() async {
    setState(() => _requestingCode = true);
    try {
      await widget.auth.requestChangePasswordCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен на email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _requestingCode = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        totpCode: _totp.text.trim().isEmpty ? null : _totp.text.trim(),
        emailCode: _emailCode.text.trim().isEmpty ? null : _emailCode.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль успешно изменен')),
      );
      context.pop();
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
      appBar: AppBar(title: const Text('Смена пароля')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Текущий пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Новый пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _totp,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'TOTP код (если 2FA включен)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Email-код (альтернатива TOTP)',
                    border: OutlineInputBorder(),
                  ),
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
                    : const Text('Код'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Изменить пароль'),
          ),
        ],
      ),
    );
  }
}
