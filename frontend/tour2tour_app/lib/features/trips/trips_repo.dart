import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String? cardColor;
  final String? cardBackground;
  final String? cardIcon;
  final bool isArchived;

  TripSummary({
    required this.id,
    required this.title,
    required this.destinationCity,
    required this.startDate,
    required this.endDate,
    this.plannedDays,
    this.cardColor,
    this.cardBackground,
    this.cardIcon,
    this.isArchived = false,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      destinationCity: json['destination_city']?.toString(),
      startDate: _parseDateOrEpoch(json['start_date']),
      endDate: _parseDateOrEpoch(json['end_date']),
      plannedDays: int.tryParse((json['planned_days'] ?? '').toString()),
      cardColor: json['card_color']?.toString(),
      cardBackground: json['card_background']?.toString(),
      cardIcon: json['card_icon']?.toString(),
      isArchived: json['is_archived'] == true,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'description': description,
        'amount_rub': amountRub,
        'category': category,
        'created_at': createdAt.toIso8601String(),
      };
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'position': position,
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
        'cost_rub': costRub,
        'reference_number': referenceNumber,
        'notes': notes,
        'website_url': websiteUrl,
        'rating': rating,
        'document_key': documentKey,
      };
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

class StageAssistantDraft {
  final String stageType;
  final String subtype;
  final String title;
  final String? startLocation;
  final String? endLocation;
  final String? address;
  final String? startTimeText;
  final String? endTimeText;
  final int? durationMinutes;
  final double? costRub;
  final String? notes;
  final String timeMode;
  final String sourceText;

  StageAssistantDraft({
    required this.stageType,
    required this.subtype,
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.address,
    required this.startTimeText,
    required this.endTimeText,
    required this.durationMinutes,
    required this.costRub,
    required this.notes,
    required this.timeMode,
    required this.sourceText,
  });

  factory StageAssistantDraft.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    return StageAssistantDraft(
      stageType: (json['stage_type'] ?? '').toString(),
      subtype: (json['subtype'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      startLocation: json['start_location']?.toString(),
      endLocation: json['end_location']?.toString(),
      address: json['address']?.toString(),
      startTimeText: json['start_time_text']?.toString(),
      endTimeText: json['end_time_text']?.toString(),
      durationMinutes: parseInt(json['duration_minutes']),
      costRub: parseDouble(json['cost_rub']),
      notes: json['notes']?.toString(),
      timeMode: (json['time_mode'] ?? 'duration').toString(),
      sourceText: (json['source_text'] ?? '').toString(),
    );
  }
}

class StageAssistantTrialStatus {
  final int limit;
  final int used;
  final int remaining;
  final bool isLocked;

  const StageAssistantTrialStatus({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.isLocked,
  });

  factory StageAssistantTrialStatus.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, int fallback) =>
        int.tryParse(raw?.toString() ?? '') ?? fallback;

    return StageAssistantTrialStatus(
      limit: parseInt(json['limit'], 5),
      used: parseInt(json['used'], 0),
      remaining: parseInt(json['remaining'], 5),
      isLocked: json['is_locked'] == true,
    );
  }
}

class TripsRepo {
  final ApiClient api;
  TripsRepo(this.api);

  static const _stagesCachePrefix = 'offline_stages_trip_';
  static const _expensesCachePrefix = 'offline_expenses_trip_';
  static const _pendingOpsKey = 'offline_pending_ops_v1';
  int _offlineIdSeed = -1;
  bool get _offlineEnabled => !kIsWeb;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _saveStagesCache(int tripId, List<TripStage> items) async {
    if (!_offlineEnabled) return;
    final prefs = await _prefs();
    final key = '$_stagesCachePrefix$tripId';
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, payload);
  }

  Future<List<TripStage>> _loadStagesCache(int tripId) async {
    if (!_offlineEnabled) return const [];
    final prefs = await _prefs();
    final raw = prefs.getString('$_stagesCachePrefix$tripId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((m) => TripStage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveExpensesCache(int tripId, List<TripExpense> items) async {
    if (!_offlineEnabled) return;
    final prefs = await _prefs();
    final key = '$_expensesCachePrefix$tripId';
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, payload);
  }

  Future<List<TripExpense>> _loadExpensesCache(int tripId) async {
    if (!_offlineEnabled) return const [];
    final prefs = await _prefs();
    final raw = prefs.getString('$_expensesCachePrefix$tripId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((m) => TripExpense.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingOps() async {
    if (!_offlineEnabled) return <Map<String, dynamic>>[];
    final prefs = await _prefs();
    final raw = prefs.getString(_pendingOpsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return <Map<String, dynamic>>[];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _savePendingOps(List<Map<String, dynamic>> ops) async {
    if (!_offlineEnabled) return;
    final prefs = await _prefs();
    await prefs.setString(_pendingOpsKey, jsonEncode(ops));
  }

  int _nextOfflineId() {
    _offlineIdSeed -= 1;
    return _offlineIdSeed;
  }

  Future<void> _enqueueOp(Map<String, dynamic> op) async {
    final ops = await _loadPendingOps();
    ops.add(op);
    await _savePendingOps(ops);
  }

  bool _isOfflineNetworkError(Object e) {
    return e is DioException &&
        (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout);
  }

  Future<void> _trySyncPendingOps() async {
    if (!_offlineEnabled) return;
    final ops = await _loadPendingOps();
    if (ops.isEmpty) return;
    final remained = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        final kind = (op['kind'] ?? '').toString();
        if (kind == 'stage_create') {
          final tripId = op['trip_id'] as int;
          final data = Map<String, dynamic>.from(op['data'] as Map);
          await api.dio.post('/trips/$tripId/stages', data: data);
        } else if (kind == 'stage_update') {
          final tripId = op['trip_id'] as int;
          final stageId = op['stage_id'] as int;
          final data = Map<String, dynamic>.from(op['data'] as Map);
          await api.dio.patch('/trips/$tripId/stages/$stageId', data: data);
        } else if (kind == 'stage_delete') {
          final tripId = op['trip_id'] as int;
          final stageId = op['stage_id'] as int;
          if (stageId > 0) {
            await api.dio.delete('/trips/$tripId/stages/$stageId');
          }
        } else if (kind == 'expense_create') {
          final tripId = op['trip_id'] as int;
          final data = Map<String, dynamic>.from(op['data'] as Map);
          await api.dio.post('/trips/$tripId/expenses', data: data);
        } else if (kind == 'expense_update') {
          final tripId = op['trip_id'] as int;
          final expenseId = op['expense_id'] as int;
          final data = Map<String, dynamic>.from(op['data'] as Map);
          await api.dio.patch('/trips/$tripId/expenses/$expenseId', data: data);
        } else if (kind == 'expense_delete') {
          final tripId = op['trip_id'] as int;
          final expenseId = op['expense_id'] as int;
          if (expenseId > 0) {
            await api.dio.delete('/trips/$tripId/expenses/$expenseId');
          }
        }
      } catch (_) {
        remained.add(op);
      }
    }
    await _savePendingOps(remained);
  }

  Future<TripSummary?> createTrip({
    required String title,
    String? description,
    String? destinationCity,
    required DateTime startDate,
    required DateTime endDate,
    int? plannedDays,
    String? cardColor,
    String? cardBackground,
    String? cardIcon,
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
        'card_color': cardColor,
        'card_background': cardBackground,
        'card_icon': cardIcon,
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
    String? cardColor,
    String? cardBackground,
    String? cardIcon,
    bool? isArchived,
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
    if (cardColor != null) payload['card_color'] = cardColor;
    if (cardBackground != null) payload['card_background'] = cardBackground;
    if (cardIcon != null) payload['card_icon'] = cardIcon;
    if (isArchived != null) payload['is_archived'] = isArchived;
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

  Future<void> deleteTrip(int tripId) async {
    await api.dio.delete('/trips/$tripId');
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
    try {
      await _trySyncPendingOps();
      final res = await api.dio.get('/trips/$tripId/expenses');
      final data = res.data;
      if (data is! List) return [];
      final items = data
          .whereType<Map>()
          .map((raw) => TripExpense.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
      await _saveExpensesCache(tripId, items);
      return items;
    } catch (e) {
      if (_isOfflineNetworkError(e)) {
        return _loadExpensesCache(tripId);
      }
      rethrow;
    }
  }

  Future<TripExpense?> createExpense({
    required int tripId,
    required String description,
    required double amountRub,
    required String category,
  }) async {
    final payload = {
      'description': description,
      'amount_rub': amountRub.toStringAsFixed(2),
      'category': category,
    };
    try {
      final res = await api.dio.post('/trips/$tripId/expenses', data: payload);
      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final created = TripExpense.fromJson(data);
      final cached = await _loadExpensesCache(tripId);
      await _saveExpensesCache(tripId, [created, ...cached.where((e) => e.id != created.id)]);
      return created;
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      final local = TripExpense(
        id: _nextOfflineId(),
        tripId: tripId,
        description: description,
        amountRub: amountRub,
        category: category,
        createdAt: DateTime.now(),
      );
      final cached = await _loadExpensesCache(tripId);
      await _saveExpensesCache(tripId, [local, ...cached]);
      await _enqueueOp({'kind': 'expense_create', 'trip_id': tripId, 'data': payload});
      return local;
    }
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

    try {
      final res = await api.dio.patch('/trips/$tripId/expenses/$expenseId', data: patch);
      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final updated = TripExpense.fromJson(data);
      final cached = await _loadExpensesCache(tripId);
      final next = cached.map((e) => e.id == updated.id ? updated : e).toList();
      await _saveExpensesCache(tripId, next);
      return updated;
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      final cached = await _loadExpensesCache(tripId);
      final idx = cached.indexWhere((e) => e.id == expenseId);
      if (idx < 0) return null;
      final prev = cached[idx];
      final local = TripExpense(
        id: prev.id,
        tripId: prev.tripId,
        description: description ?? prev.description,
        amountRub: amountRub ?? prev.amountRub,
        category: category ?? prev.category,
        createdAt: prev.createdAt,
      );
      cached[idx] = local;
      await _saveExpensesCache(tripId, cached);
      if (expenseId > 0) {
        await _enqueueOp({
          'kind': 'expense_update',
          'trip_id': tripId,
          'expense_id': expenseId,
          'data': patch,
        });
      }
      return local;
    }
  }

  Future<void> deleteExpense({
    required int tripId,
    required int expenseId,
  }) async {
    try {
      await api.dio.delete('/trips/$tripId/expenses/$expenseId');
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      if (expenseId > 0) {
        await _enqueueOp({
          'kind': 'expense_delete',
          'trip_id': tripId,
          'expense_id': expenseId,
        });
      }
    } finally {
      final cached = await _loadExpensesCache(tripId);
      await _saveExpensesCache(
        tripId,
        cached.where((e) => e.id != expenseId).toList(),
      );
    }
  }

  Future<List<TripStage>> listStages(int tripId) async {
    try {
      await _trySyncPendingOps();
      final res = await api.dio.get('/trips/$tripId/stages');
      final data = res.data;
      if (data is! List) return [];
      final items = data
          .whereType<Map>()
          .map((raw) => TripStage.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
      await _saveStagesCache(tripId, items);
      return items;
    } catch (e) {
      if (_isOfflineNetworkError(e)) {
        return _loadStagesCache(tripId);
      }
      rethrow;
    }
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
    final payload = {
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
    };
    try {
      final res = await api.dio.post('/trips/$tripId/stages', data: payload);
      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final created = TripStage.fromJson(data);
      final cached = await _loadStagesCache(tripId);
      await _saveStagesCache(
        tripId,
        [...cached.where((s) => s.id != created.id), created]
          ..sort((a, b) => a.position.compareTo(b.position)),
      );
      return created;
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      final cached = await _loadStagesCache(tripId);
      final local = TripStage(
        id: _nextOfflineId(),
        tripId: tripId,
        position: cached.length,
        stageType: stageType,
        subtype: subtype,
        title: title,
        startLocation: startLocation,
        endLocation: endLocation,
        address: address,
        latitude: latitude,
        longitude: longitude,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: durationMinutes,
        costRub: costRub,
        referenceNumber: referenceNumber,
        notes: notes,
        websiteUrl: websiteUrl,
        rating: rating,
        documentKey: documentKey,
      );
      await _saveStagesCache(tripId, [...cached, local]);
      await _enqueueOp({'kind': 'stage_create', 'trip_id': tripId, 'data': payload});
      return local;
    }
  }

  Future<TripStage?> updateStage({
    required int tripId,
    required int stageId,
    required Map<String, dynamic> patch,
  }) async {
    try {
      final res = await api.dio.patch('/trips/$tripId/stages/$stageId', data: patch);
      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final updated = TripStage.fromJson(data);
      final cached = await _loadStagesCache(tripId);
      final next = cached.map((s) => s.id == stageId ? updated : s).toList();
      await _saveStagesCache(tripId, next);
      return updated;
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      final cached = await _loadStagesCache(tripId);
      final idx = cached.indexWhere((s) => s.id == stageId);
      if (idx < 0) return null;
      final s = cached[idx];
      final local = TripStage(
        id: s.id,
        tripId: s.tripId,
        position: patch['position'] is int ? patch['position'] as int : s.position,
        stageType: (patch['stage_type'] ?? s.stageType).toString(),
        subtype: (patch['subtype'] ?? s.subtype).toString(),
        title: (patch['title'] ?? s.title).toString(),
        startLocation: patch['start_location']?.toString() ?? s.startLocation,
        endLocation: patch['end_location']?.toString() ?? s.endLocation,
        address: patch['address']?.toString() ?? s.address,
        latitude: patch['latitude'] is num ? (patch['latitude'] as num).toDouble() : s.latitude,
        longitude: patch['longitude'] is num ? (patch['longitude'] as num).toDouble() : s.longitude,
        startTime: patch['start_time'] != null
            ? DateTime.tryParse(patch['start_time'].toString())
            : s.startTime,
        endTime: patch['end_time'] != null
            ? DateTime.tryParse(patch['end_time'].toString())
            : s.endTime,
        durationMinutes: patch['duration_minutes'] is int
            ? patch['duration_minutes'] as int
            : s.durationMinutes,
        costRub: patch['cost_rub'] != null
            ? double.tryParse(patch['cost_rub'].toString())
            : s.costRub,
        referenceNumber: patch['reference_number']?.toString() ?? s.referenceNumber,
        notes: patch['notes']?.toString() ?? s.notes,
        websiteUrl: patch['website_url']?.toString() ?? s.websiteUrl,
        rating: patch['rating'] is num ? (patch['rating'] as num).toDouble() : s.rating,
        documentKey: patch['document_key']?.toString() ?? s.documentKey,
      );
      cached[idx] = local;
      await _saveStagesCache(tripId, cached);
      if (stageId > 0) {
        await _enqueueOp({
          'kind': 'stage_update',
          'trip_id': tripId,
          'stage_id': stageId,
          'data': patch,
        });
      }
      return local;
    }
  }

  Future<void> deleteStage({required int tripId, required int stageId}) async {
    try {
      await api.dio.delete('/trips/$tripId/stages/$stageId');
    } catch (e) {
      if (!_isOfflineNetworkError(e)) rethrow;
      if (stageId > 0) {
        await _enqueueOp({
          'kind': 'stage_delete',
          'trip_id': tripId,
          'stage_id': stageId,
        });
      }
    } finally {
      final cached = await _loadStagesCache(tripId);
      final next = cached.where((s) => s.id != stageId).toList();
      for (var i = 0; i < next.length; i++) {
        next[i] = TripStage(
          id: next[i].id,
          tripId: next[i].tripId,
          position: i,
          stageType: next[i].stageType,
          subtype: next[i].subtype,
          title: next[i].title,
          startLocation: next[i].startLocation,
          endLocation: next[i].endLocation,
          address: next[i].address,
          latitude: next[i].latitude,
          longitude: next[i].longitude,
          startTime: next[i].startTime,
          endTime: next[i].endTime,
          durationMinutes: next[i].durationMinutes,
          costRub: next[i].costRub,
          referenceNumber: next[i].referenceNumber,
          notes: next[i].notes,
          websiteUrl: next[i].websiteUrl,
          rating: next[i].rating,
          documentKey: next[i].documentKey,
        );
      }
      await _saveStagesCache(tripId, next);
    }
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

  Future<String?> transcribeStageAudio({
    required Uint8List audioBytes,
    String filename = 'stage-voice.raw',
    String? mimeType,
  }) async {
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: filename,
        contentType: mimeType == null ? null : MediaType.parse(mimeType),
      ),
    });
    final res = await api.dio.post(
      '/trips/stage-assistant/transcribe',
      data: formData,
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    final text = data['text']?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<StageAssistantDraft?> createStageDraftFromText({
    String? stageType,
    required String text,
    DateTime? routeDay,
  }) async {
    final res = await api.dio.post(
      '/trips/stage-assistant/draft',
      data: {
        'stage_type': stageType,
        'text': text,
        'route_day': routeDay?.toIso8601String().split('T').first,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    return StageAssistantDraft.fromJson(data);
  }

  Future<StageAssistantTrialStatus> getStageAssistantTrialStatus() async {
    final res = await api.dio.get('/users/me/stage-assistant-trial');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      return const StageAssistantTrialStatus(
        limit: 5,
        used: 0,
        remaining: 5,
        isLocked: false,
      );
    }
    return StageAssistantTrialStatus.fromJson(data);
  }

  Future<StageAssistantTrialStatus> consumeStageAssistantTrial() async {
    final res = await api.dio.post('/users/me/stage-assistant-trial/consume');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      return const StageAssistantTrialStatus(
        limit: 5,
        used: 0,
        remaining: 5,
        isLocked: false,
      );
    }
    return StageAssistantTrialStatus.fromJson(data);
  }
}
