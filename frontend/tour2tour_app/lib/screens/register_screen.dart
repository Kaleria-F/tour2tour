import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _repo = AuthRepository();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.register(
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
      );
      // можно сразу логиниться:
      await _repo.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      context.go('/preferences');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? '...' : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
