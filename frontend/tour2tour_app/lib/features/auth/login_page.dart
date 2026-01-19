import 'package:flutter/material.dart';
import 'auth_repo.dart';

class LoginPage extends StatefulWidget {
  final AuthRepo auth;
  final VoidCallback onLoggedIn;
  const LoginPage({super.key, required this.auth, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      await widget.auth.login(email: email.text.trim(), password: password.text);
      widget.onLoggedIn();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль')),
            const SizedBox(height: 12),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : submit,
              child: Text(loading ? '...' : 'Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
