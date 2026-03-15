import 'package:go_router/go_router.dart';

import 'core/token_storage.dart';
import 'api/api_client.dart';

import 'features/auth/auth_repo.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';

import 'features/preferences/preferences_repo.dart';
import 'features/preferences/preferences_page.dart';

import 'features/profile/profile_repo.dart';
import 'features/profile/profile_page.dart';
import 'features/trips/create_trip_page.dart';
import 'features/trips/trip_workspace_page.dart';


GoRouter buildRouter() {
  final tokenStorage = TokenStorage();
  final api = ApiClient(tokenStorage);

  final auth = AuthRepo(api, tokenStorage);
  final prefs = PreferencesRepo(api);
  final profile = ProfileRepo(api);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => LoginPage(auth: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => RegisterPage(auth: auth),
      ),
      GoRoute(
        path: '/preferences',
        builder: (_, __) => PreferencesPage(repo: prefs, auth: auth),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => ProfilePage(repo: profile),
      ),
      GoRoute(
        path: '/create-trip',
        builder: (_, __) => CreateTripPage(),
      ),
      GoRoute(
        path: '/trip-workspace',
        builder: (_, state) {
          final title = state.extra is String && (state.extra as String).trim().isNotEmpty
              ? state.extra as String
              : 'Путешествие';
          return TripWorkspacePage(tripTitle: title);
        },
      ),
    ],
  );
}
