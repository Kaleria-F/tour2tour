import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'features/auth/auth_repo.dart';
import 'features/auth/login_page.dart';
import 'features/preferences/preferences_repo.dart';
import 'features/preferences/preferences_page.dart';

void main() {
  runApp(const Tour2TourApp());
}

class Tour2TourApp extends StatefulWidget {
  const Tour2TourApp({super.key});

  @override
  State<Tour2TourApp> createState() => _Tour2TourAppState();
}

class _Tour2TourAppState extends State<Tour2TourApp> {
  final tokenStorage = TokenStorage();
  late final api = ApiClient(tokenStorage);
  late final auth = AuthRepo(api);
  late final prefs = PreferencesRepo(api);

  String? token;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final t = await tokenStorage.read();
    setState(() {
      token = t;
      loading = false;
    });
  }

  Future<void> onLoggedIn() async {
    final t = await tokenStorage.read();
    setState(() => token = t);
  }

  Future<void> onLogout() async {
    await tokenStorage.clear();
    setState(() => token = null);
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      home: (token == null)
          ? LoginPage(auth: auth, onLoggedIn: onLoggedIn)
          : PreferencesPage(repo: prefs, onLogout: onLogout),
    );
  }
}
