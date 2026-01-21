import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repo.dart';
import 'preferences_repo.dart';

class PreferencesPage extends StatefulWidget {
  final PreferencesRepo repo;
  final AuthRepo auth;

  const PreferencesPage({super.key, required this.repo, required this.auth});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final options = const ['nature', 'culture', 'food', 'museum', 'active', 'kids', 'history'];
  final selected = <String>{};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repo.getPreferences();
      selected.addAll(data);
    } catch (_) {
      // если GET нет/падает — не страшно
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => error = null);
    try {
      await widget.repo.setPreferences(selected.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Предпочтения'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Выбери интересы:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: options.map((o) {
                  final v = selected.contains(o);
                  return CheckboxListTile(
                    value: v,
                    title: Text(o),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) selected.add(o);
                        else selected.remove(o);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
            ),
          ],
        ),
      ),
    );
  }
}
