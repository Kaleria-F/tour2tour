import '../../api/api_client.dart';

DateTime _parseDateOrEpoch(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

double _parseDoubleOrZero(dynamic raw) {
  if (raw == null) return 0;
  return double.tryParse(raw.toString()) ?? 0;
}

class TripSummary {
  final int id;
  final String title;
  final String? destinationCity;
  final DateTime startDate;
  final DateTime endDate;
  final int? plannedDays;

  TripSummary({
    required this.id,
    required this.title,
    required this.destinationCity,
    required this.startDate,
    required this.endDate,
    this.plannedDays,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      destinationCity: json['destination_city']?.toString(),
      startDate: _parseDateOrEpoch(json['start_date']),
      endDate: _parseDateOrEpoch(json['end_date']),
      plannedDays: int.tryParse((json['planned_days'] ?? '').toString()),
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

  static String? _extractText(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      if (value.startsWith('{') || value.startsWith('[')) return null;
      return value;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map);
      const keys = [
        'display_name',
        'displayName',
        'fullname',
        'full_name',
        'name',
        'title',
        'value',
        'city',
        'label',
      ];
      for (final key in keys) {
        final value = _extractText(map[key]);
        if (value != null) return value;
      }
      return null;
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    if (value.startsWith('{') || value.startsWith('[')) return null;
    return value;
  }

  static String? _extractFromDictLikeString(
    String? raw,
    List<String> keys,
  ) {
    if (raw == null) return null;
    final source = raw.trim();
    if (source.isEmpty) return null;
    for (final key in keys) {
      final pattern = RegExp("['\\\"]$key['\\\"]\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]");
      final match = pattern.firstMatch(source);
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    }

    final city = _extractText(json['city']) ?? _extractText(json['name']) ?? '';
    final regionRaw = json['region'];
    final region = _extractText(regionRaw) ??
        _extractText(json['region_name']) ??
        _extractFromDictLikeString(
          regionRaw?.toString(),
          const ['fullname', 'name', 'label', 'title'],
        );

    final districtRaw = json['district'];
    final district = _extractText(districtRaw) ??
        _extractFromDictLikeString(
          districtRaw?.toString(),
          const ['name', 'fullname', 'label', 'title'],
        );
    final country = _extractText(json['country']) ?? 'Россия';
    final rawDisplayName = _extractText(json['display_name']);
    final displayName = rawDisplayName ??
        [
          city,
          if (region != null && region != city) region,
          country,
        ].where((item) => item.trim().isNotEmpty).join(', ');

    return CitySuggestion(
      city: city,
      region: region,
      district: district,
      country: country,
      displayName: displayName,
      latitude: parseDouble(json['lat']),
      longitude: parseDouble(json['lon']),
      population: parseInt(json['population']),
      type: _extractText(json['type']),
      source: _extractText(json['source']) ?? '',
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
      amountRub: _parseDoubleOrZero(json['amount_rub']),
      category: (json['category'] ?? '').toString(),
      createdAt: _parseDateOrEpoch(json['created_at']),
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
    int? plannedDays,
  }) async {
    final res = await api.dio.post(
      '/trips/',
      data: {
        'title': title,
        'description': description,
        'destination_city': destinationCity,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'planned_days': plannedDays,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return TripSummary.fromJson(data);
  }

  Future<TripSummary?> updateTrip({
    required int tripId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? plannedDays,
    bool includePlannedDays = false,
    bool confirmTrim = false,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (startDate != null) {
      payload['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      payload['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    if (includePlannedDays) payload['planned_days'] = plannedDays;
    if (confirmTrim) payload['confirm_trim'] = true;
    final res = await api.dio.patch('/trips/$tripId', data: payload);
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
