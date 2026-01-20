import 'package:flutter/material.dart';
import 'preferences_repo.dart';

class PreferencesPage extends StatefulWidget {
  final PreferencesRepo repo;
   final Future<void> Function()? onLogout;

  const PreferencesPage({
    super.key,
    required this.repo,
    this.onLogout,
  });

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
      // если ещё нет preferences — не страшно
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => error = null);
    try {
      await widget.repo.setPreferences(selected.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено')),
      );
    } catch (e) {
      setState(() => error = e.toString());
    }
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
            onPressed: widget.onLogout == null
                ? null
                : () async {
                    await widget.onLogout!();
                  },
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
            ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
