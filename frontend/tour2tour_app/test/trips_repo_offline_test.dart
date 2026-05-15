import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tour2tour_app/api/api_client.dart';
import 'package:tour2tour_app/core/token_storage.dart';
import 'package:tour2tour_app/features/trips/trips_repo.dart';

class _FakeTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

typedef _RequestHandler = Future<void> Function(
  RequestOptions options,
  RequestInterceptorHandler handler,
);

ApiClient _buildApiClient(_RequestHandler onRequest) {
  final api = ApiClient(_FakeTokenStorage());
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: onRequest,
    ),
  );
  return api;
}

DioException _offlineError(RequestOptions options) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: Exception('offline'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripsRepo offline/network resilience', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('createExpense stores local expense and pending operation when offline', () async {
      final api = _buildApiClient((options, handler) async {
        if (options.method == 'POST' && options.path == '/trips/1/expenses') {
          handler.reject(_offlineError(options));
          return;
        }
        handler.next(options);
      });
      final repo = TripsRepo(api);

      final created = await repo.createExpense(
        tripId: 1,
        description: 'Taxi',
        amountRub: 350.0,
        category: 'transport',
      );

      expect(created, isNotNull);
      expect(created!.id, lessThan(0));
      expect(created.description, 'Taxi');

      final prefs = await SharedPreferences.getInstance();
      final rawOps = prefs.getString('offline_pending_ops_v1');
      expect(rawOps, isNotNull);
      final ops = jsonDecode(rawOps!) as List<dynamic>;
      expect(ops, hasLength(1));
      expect((ops.first as Map<String, dynamic>)['kind'], 'expense_create');
    });

    test('listExpenses falls back to cache on offline errors', () async {
      final cachedPayload = jsonEncode([
        {
          'id': 11,
          'trip_id': 1,
          'description': 'Hotel',
          'amount_rub': 5200.0,
          'category': 'housing',
          'created_at': '2026-05-15T08:00:00Z',
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'offline_expenses_trip_1': cachedPayload,
      });

      final api = _buildApiClient((options, handler) async {
        if (options.method == 'GET' && options.path == '/trips/1/expenses') {
          handler.reject(_offlineError(options));
          return;
        }
        handler.next(options);
      });
      final repo = TripsRepo(api);

      final expenses = await repo.listExpenses(1);
      expect(expenses, hasLength(1));
      expect(expenses.first.description, 'Hotel');
      expect(expenses.first.amountRub, 5200.0);
    });

    test('listExpenses syncs pending ops when network is restored', () async {
      SharedPreferences.setMockInitialValues({
        'offline_pending_ops_v1': jsonEncode([
          {
            'kind': 'expense_create',
            'trip_id': 1,
            'data': {
              'description': 'Museum',
              'amount_rub': '700.00',
              'category': 'entertainment',
            },
          },
        ]),
      });

      final api = _buildApiClient((options, handler) async {
        if (options.method == 'POST' && options.path == '/trips/1/expenses') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 77,
                'trip_id': 1,
                'description': 'Museum',
                'amount_rub': 700.0,
                'category': 'entertainment',
                'created_at': '2026-05-15T09:00:00Z',
              },
            ),
          );
          return;
        }
        if (options.method == 'GET' && options.path == '/trips/1/expenses') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: [
                {
                  'id': 77,
                  'trip_id': 1,
                  'description': 'Museum',
                  'amount_rub': 700.0,
                  'category': 'entertainment',
                  'created_at': '2026-05-15T09:00:00Z',
                },
              ],
            ),
          );
          return;
        }
        handler.next(options);
      });
      final repo = TripsRepo(api);

      final expenses = await repo.listExpenses(1);
      expect(expenses, hasLength(1));
      expect(expenses.first.id, 77);

      final prefs = await SharedPreferences.getInstance();
      final rawOps = prefs.getString('offline_pending_ops_v1');
      final ops = rawOps == null || rawOps.isEmpty
          ? <dynamic>[]
          : (jsonDecode(rawOps) as List<dynamic>);
      expect(ops, isEmpty);
    });
  });
}
