import 'package:go_router/go_router.dart';

import 'core/token_storage.dart';
import 'api/api_client.dart';

import 'features/auth/auth_repo.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/security_setup_page.dart';
import 'features/auth/totp_verify_page.dart';
import 'features/auth/change_password_page.dart';
import 'features/auth/recovery_page.dart';

import 'features/preferences/preferences_repo.dart';
import 'features/preferences/preferences_page.dart';
import 'features/recommendations/recommendations_repo.dart';
import 'features/interactions/interactions_repo.dart';

import 'features/documents/documents_repo.dart';
import 'features/favorites/favorites_page.dart';
import 'features/profile/profile_repo.dart';
import 'features/profile/profile_page.dart';
import 'features/trips/create_trip_page.dart';
import 'features/trips/trip_workspace_page.dart';
import 'features/trips/trips_repo.dart';


GoRouter buildRouter() {
  final tokenStorage = TokenStorage();
  final api = ApiClient(tokenStorage);

  final auth = AuthRepo(api, tokenStorage);
  final prefs = PreferencesRepo(api);
  final recommendations = RecommendationsRepo(api);
  final interactions = InteractionsRepo(api);
  final profile = ProfileRepo(api);
  final trips = TripsRepo(api);
  final documents = DocumentsRepo(api);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => LoginPage(auth: auth),
      ),
      GoRoute(
        path: '/recovery',
        builder: (_, __) => RecoveryPage(auth: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => RegisterPage(auth: auth),
      ),
      GoRoute(
        path: '/security-setup',
        builder: (_, __) => SecuritySetupPage(auth: auth),
      ),
      GoRoute(
        path: '/totp-verify',
        builder: (_, state) {
          final payload = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          return TotpVerifyPage(
            auth: auth,
            challengeId: (payload['challenge_id'] ?? '').toString(),
            factors: (payload['factors'] as List? ?? const [])
                .map((e) => e.toString())
                .toList(),
          );
        },
      ),
      GoRoute(
        path: '/preferences',
        builder: (_, state) => PreferencesPage(
          repo: prefs,
          auth: auth,
          fromRecommendations:
              state.uri.queryParameters['from'] == 'recommendations',
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => ProfilePage(
          repo: profile,
          tripsRepo: trips,
          preferencesRepo: prefs,
          recommendationsRepo: recommendations,
        ),
      ),
      GoRoute(
        path: '/favorites',
        builder: (_, state) => FavoritesPage(
          interactionsRepo: interactions,
          profileRepo: profile,
          tripId: int.tryParse(state.uri.queryParameters['tripId'] ?? ''),
          city: state.uri.queryParameters['city'],
          titleOverride: state.uri.queryParameters['title'],
          subtitleOverride: state.uri.queryParameters['subtitle'],
        ),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => ChangePasswordPage(auth: auth),
      ),
      GoRoute(
        path: '/create-trip',
        builder: (_, __) => CreateTripPage(tripsRepo: trips),
      ),
      GoRoute(
        path: '/trip-workspace',
        builder: (_, state) {
          final payload = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final title = (payload['title'] ?? 'Путешествие').toString();
          final tripId = payload['id'] is int ? payload['id'] as int : null;
          final destinationCity = payload['destination_city']?.toString();
          final startDate = payload['start_date'] is DateTime ? payload['start_date'] as DateTime : null;
          final endDate = payload['end_date'] is DateTime ? payload['end_date'] as DateTime : null;
          return TripWorkspacePage(
            tripTitle: title,
            tripId: tripId,
            destinationCity: destinationCity,
            startDate: startDate,
            endDate: endDate,
            tripsRepo: trips,
            documentsRepo: documents,
            preferencesRepo: prefs,
            recommendationsRepo: recommendations,
            interactionsRepo: interactions,
            profileRepo: profile,
          );
        },
      ),
    ],
  );
}
