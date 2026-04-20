import '../../api/api_client.dart';

class TripSummary {
  final int id;
  final String title;
  final String? destinationCity;
  final DateTime startDate;
  final DateTime endDate;

  TripSummary({
    required this.id,
    required this.title,
    required this.destinationCity,
    required this.startDate,
    required this.endDate,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      destinationCity: json['destination_city']?.toString(),
      startDate: DateTime.parse((json['start_date'] ?? '').toString()),
      endDate: DateTime.parse((json['end_date'] ?? '').toString()),
    );
  }
}

class CitySuggestion {
  final String city;
  final String? region;
  final String? district;
  final String country;
  final String displayName;
  final double? latitude;
  final double? longitude;
  final int? population;
  final String? type;
  final String source;

  const CitySuggestion({
    required this.city,
    required this.region,
    required this.district,
    required this.country,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.type,
    required this.source,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    }

    return CitySuggestion(
      city: (json['city'] ?? '').toString(),
      region: json['region']?.toString(),
      district: json['district']?.toString(),
      country: (json['country'] ?? 'Россия').toString(),
      displayName: (json['display_name'] ?? json['city'] ?? '').toString(),
      latitude: parseDouble(json['lat']),
      longitude: parseDouble(json['lon']),
      population: parseInt(json['population']),
      type: json['type']?.toString(),
      source: (json['source'] ?? '').toString(),
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

class TripStage {
  final int id;
  final int tripId;
  final int position;
  final String stageType;
  final String subtype;
  final String title;
  final String? startLocation;
  final String? endLocation;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final double? costRub;
  final String? referenceNumber;
  final String? notes;
  final String? websiteUrl;
  final double? rating;
  final String? documentKey;

  TripStage({
    required this.id,
    required this.tripId,
    required this.position,
    required this.stageType,
    required this.subtype,
    required this.title,
    this.startLocation,
    this.endLocation,
    this.address,
    this.latitude,
    this.longitude,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.costRub,
    this.referenceNumber,
    this.notes,
    this.websiteUrl,
    this.rating,
    this.documentKey,
  });

  factory TripStage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      final value = raw?.toString();
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    }

    return TripStage(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      position: json['position'] as int,
      stageType: (json['stage_type'] ?? '').toString(),
      subtype: (json['subtype'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      startLocation: json['start_location']?.toString(),
      endLocation: json['end_location']?.toString(),
      address: json['address']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      startTime: parseDate(json['start_time']),
      endTime: parseDate(json['end_time']),
      durationMinutes: parseInt(json['duration_minutes']),
      costRub: parseDouble(json['cost_rub']),
      referenceNumber: json['reference_number']?.toString(),
      notes: json['notes']?.toString(),
      websiteUrl: json['website_url']?.toString(),
      rating: parseDouble(json['rating']),
      documentKey: json['document_key']?.toString(),
    );
  }
}

class StageSuggestion {
  final String title;
  final String stageType;
  final String subtype;
  final String reason;
  final String? startLocation;
  final String? endLocation;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? estimatedCostRub;

  StageSuggestion({
    required this.title,
    required this.stageType,
    required this.subtype,
    required this.reason,
    this.startLocation,
    this.endLocation,
    this.address,
    this.latitude,
    this.longitude,
    this.estimatedCostRub,
  });

  factory StageSuggestion.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    return StageSuggestion(
      title: (json['title'] ?? '').toString(),
      stageType: (json['stage_type'] ?? '').toString(),
      subtype: (json['subtype'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      startLocation: json['start_location']?.toString(),
      endLocation: json['end_location']?.toString(),
      address: json['address']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      estimatedCostRub: parseDouble(json['estimated_cost_rub']),
    );
  }
}

class TripsRepo {
  final ApiClient api;
  TripsRepo(this.api);

  Future<TripSummary?> createTrip({
    required String title,
    String? description,
    String? destinationCity,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await api.dio.post(
      '/trips/',
      data: {
        'title': title,
        'description': description,
        'destination_city': destinationCity,
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

  Future<List<CitySuggestion>> suggestCities(String query, {int limit = 8}) async {
    final normalized = query.trim();
    if (normalized.length < 2) return [];
    final res = await api.dio.get(
      '/places/cities/suggest',
      queryParameters: {
        'q': normalized,
        'limit': limit,
      },
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => CitySuggestion.fromJson(Map<String, dynamic>.from(raw)))
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

  Future<TripExpense?> updateExpense({
    required int tripId,
    required int expenseId,
    String? description,
    double? amountRub,
    String? category,
  }) async {
    final patch = <String, dynamic>{};
    if (description != null) patch['description'] = description;
    if (amountRub != null) patch['amount_rub'] = amountRub.toStringAsFixed(2);
    if (category != null) patch['category'] = category;

    final res = await api.dio.patch(
      '/trips/$tripId/expenses/$expenseId',
      data: patch,
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripExpense.fromJson(data);
  }

  Future<void> deleteExpense({
    required int tripId,
    required int expenseId,
  }) async {
    await api.dio.delete('/trips/$tripId/expenses/$expenseId');
  }

  Future<List<TripStage>> listStages(int tripId) async {
    final res = await api.dio.get('/trips/$tripId/stages');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripStage.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<TripStage?> createStage({
    required int tripId,
    required String stageType,
    required String subtype,
    required String title,
    String? startLocation,
    String? endLocation,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    double? costRub,
    String? referenceNumber,
    String? notes,
    String? websiteUrl,
    double? rating,
    String? documentKey,
  }) async {
    final res = await api.dio.post(
      '/trips/$tripId/stages',
      data: {
        'stage_type': stageType,
        'subtype': subtype,
        'title': title,
        'start_location': startLocation,
        'end_location': endLocation,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'cost_rub': costRub?.toStringAsFixed(2),
        'reference_number': referenceNumber,
        'notes': notes,
        'website_url': websiteUrl,
        'rating': rating,
        'document_key': documentKey,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripStage.fromJson(data);
  }

  Future<TripStage?> updateStage({
    required int tripId,
    required int stageId,
    required Map<String, dynamic> patch,
  }) async {
    final res = await api.dio.patch(
      '/trips/$tripId/stages/$stageId',
      data: patch,
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripStage.fromJson(data);
  }

  Future<void> deleteStage({required int tripId, required int stageId}) async {
    await api.dio.delete('/trips/$tripId/stages/$stageId');
  }

  Future<TripStage?> copyStage({
    required int tripId,
    required int stageId,
  }) async {
    final res = await api.dio.post('/trips/$tripId/stages/$stageId/copy');
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripStage.fromJson(data);
  }

  Future<List<TripStage>> reorderStages({
    required int tripId,
    required List<int> orderedIds,
  }) async {
    final res = await api.dio.post(
      '/trips/$tripId/stages/reorder',
      data: {'stage_ids': orderedIds},
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripStage.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<List<StageSuggestion>> listStageSuggestions({
    required int tripId,
    required int stageId,
  }) async {
    final res = await api.dio.get('/trips/$tripId/stages/$stageId/suggestions');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => StageSuggestion.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<TripStage?> createStageFromSuggestion({
    required int tripId,
    required StageSuggestion suggestion,
  }) async {
    final res = await api.dio.post(
      '/trips/$tripId/stages',
      data: {
        'stage_type': suggestion.stageType,
        'subtype': suggestion.subtype,
        'title': suggestion.title,
        'start_location': suggestion.startLocation,
        'end_location': suggestion.endLocation,
        'address': suggestion.address,
        'latitude': suggestion.latitude,
        'longitude': suggestion.longitude,
        'cost_rub': suggestion.estimatedCostRub?.toStringAsFixed(2),
        'notes': suggestion.reason,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripStage.fromJson(data);
  }
}
