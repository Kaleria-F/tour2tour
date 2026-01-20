import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'features/preferences/preferences_page.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'features/preferences/preferences_repo.dart';

final tokenStorage = TokenStorage();
final api = ApiClient(tokenStorage);
final prefsRepo = PreferencesRepo(api);

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/preferences',
      builder: (_, __) {
        final repo = PreferencesRepo(ApiClient(TokenStorage()));
        return PreferencesPage(repo: repo);
      },
    ),
  ],
);
