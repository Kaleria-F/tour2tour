import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_repo.dart';

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
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.auth.register(
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
      );

      // сразу логинимся после регистрации
      await widget.auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;
      context.go('/preferences');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Телефон (необязательно)'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? '...' : 'Создать аккаунт'),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Уже есть аккаунт? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
