import '../../api/api_client.dart';

class TripSummary {
  final int id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;

  TripSummary({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      startDate: DateTime.parse((json['start_date'] ?? '').toString()),
      endDate: DateTime.parse((json['end_date'] ?? '').toString()),
    );
  }
}

class TripExpense {
  final int id;
  final int tripId;
  final String description;
  final double amountRub;
  final String category;
  final DateTime createdAt;

  TripExpense({
    required this.id,
    required this.tripId,
    required this.description,
    required this.amountRub,
    required this.category,
    required this.createdAt,
  });

  factory TripExpense.fromJson(Map<String, dynamic> json) {
    return TripExpense(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      description: (json['description'] ?? '').toString(),
      amountRub: double.parse((json['amount_rub'] ?? '0').toString()),
      category: (json['category'] ?? '').toString(),
      createdAt: DateTime.parse((json['created_at'] ?? '').toString()),
    );
  }
}

class TripsRepo {
  final ApiClient api;
  TripsRepo(this.api);

  Future<TripSummary?> createTrip({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await api.dio.post(
      '/trips/',
      data: {
        'title': title,
        'description': description,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripSummary.fromJson(data);
  }

  Future<List<TripSummary>> listTrips() async {
    final res = await api.dio.get('/trips/');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripSummary.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<List<TripExpense>> listExpenses(int tripId) async {
    final res = await api.dio.get('/trips/$tripId/expenses');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripExpense.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<TripExpense?> createExpense({
    required int tripId,
    required String description,
    required double amountRub,
    required String category,
  }) async {
    final res = await api.dio.post(
      '/trips/$tripId/expenses',
      data: {
        'description': description,
        'amount_rub': amountRub.toStringAsFixed(2),
        'category': category,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripExpense.fromJson(data);
  }
}
