import '../../api/api_client.dart';
import 'package:dio/dio.dart';

class AdminPlace {
  final String id;
  final String source;
  final String status;
  final String name;
  final String? description;
  final String? country;
  final String city;
  final String? address;
  final double? lat;
  final double? lon;
  final String category;
  final String? subcategory;
  final String? priceLevel;
  final int? avgVisitDurationMin;
  final double? rating;
  final int reviewsCount;
  final Map<String, int> tags;

  AdminPlace({
    required this.id,
    required this.source,
    required this.status,
    required this.name,
    required this.description,
    required this.country,
    required this.city,
    required this.address,
    required this.lat,
    required this.lon,
    required this.category,
    required this.subcategory,
    required this.priceLevel,
    required this.avgVisitDurationMin,
    required this.rating,
    required this.reviewsCount,
    required this.tags,
  });

  factory AdminPlace.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());
    int? asInt(dynamic value) =>
        value == null ? null : int.tryParse(value.toString());

    return AdminPlace(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString(),
      lat: asDouble(json['lat']),
      lon: asDouble(json['lon']),
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString(),
      priceLevel: json['price_level']?.toString(),
      avgVisitDurationMin: asInt(json['avg_visit_duration_min']),
      rating: asDouble(json['rating']),
      reviewsCount: asInt(json['reviews_count']) ?? 0,
      tags: ((json['tags'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0)),
    );
  }
}

class AdminPlaceCandidate {
  final String id;
  final String source;
  final String? sourceRecordId;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? normalized;
  final double? validationScore;
  final String? notes;

  AdminPlaceCandidate({
    required this.id,
    required this.source,
    required this.sourceRecordId,
    required this.status,
    required this.payload,
    required this.normalized,
    required this.validationScore,
    required this.notes,
  });

  factory AdminPlaceCandidate.fromJson(Map<String, dynamic> json) {
    return AdminPlaceCandidate(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sourceRecordId: json['source_record_id']?.toString(),
      status: json['status']?.toString() ?? '',
      payload: Map<String, dynamic>.from((json['payload_json'] as Map?) ?? const {}),
      normalized: json['normalized_json'] is Map
          ? Map<String, dynamic>.from(json['normalized_json'] as Map)
          : null,
      validationScore: double.tryParse((json['validation_score'] ?? '').toString()),
      notes: json['notes']?.toString(),
    );
  }
}

class AdminImportJob {
  final String id;
  final String source;
  final String kind;
  final String status;
  final String? fileName;
  final String? createdBy;
  final Map<String, dynamic> stats;

  AdminImportJob({
    required this.id,
    required this.source,
    required this.kind,
    required this.status,
    required this.fileName,
    required this.createdBy,
    required this.stats,
  });

  factory AdminImportJob.fromJson(Map<String, dynamic> json) {
    return AdminImportJob(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      createdBy: json['created_by']?.toString(),
      stats: Map<String, dynamic>.from((json['stats_json'] as Map?) ?? const {}),
    );
  }
}

class AdminRepo {
  final ApiClient api;

  AdminRepo(this.api);

  Future<List<AdminPlace>> listPlaces() async {
    final res = await api.dio.get('/places');
    final items = ((res.data as Map<String, dynamic>)['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((item) => AdminPlace.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AdminPlace> createPlace(Map<String, dynamic> payload) async {
    final res = await api.dio.post('/places', data: payload);
    return AdminPlace.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AdminPlace> updatePlace(String id, Map<String, dynamic> payload) async {
    final res = await api.dio.patch('/places/$id', data: payload);
    return AdminPlace.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePlace(String id) async {
    await api.dio.delete('/places/$id');
  }

  Future<List<AdminPlaceCandidate>> listCandidates() async {
    final res = await api.dio.get('/places/candidates/list');
    final items = (res.data as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((item) => AdminPlaceCandidate.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AdminPlaceCandidate> decideCandidate({
    required String id,
    required String status,
    String? notes,
  }) async {
    final res = await api.dio.post(
      '/places/candidates/$id/decision',
      data: {'status': status, 'notes': notes},
    );
    return AdminPlaceCandidate.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<AdminImportJob>> listImportJobs() async {
    final res = await api.dio.get('/places/imports/list');
    final items = (res.data as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((item) => AdminImportJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AdminImportJob> createImportJob({
    required String source,
    required String kind,
    String? fileName,
    String? createdBy,
  }) async {
    final res = await api.dio.post(
      '/places/imports',
      data: {
        'source': source,
        'kind': kind,
        'file_name': fileName,
        'created_by': createdBy,
      },
    );
    return AdminImportJob.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AdminImportJob> uploadCsvImport({
    required String source,
    required String kind,
    required String fileName,
    required List<int> bytes,
    String? createdBy,
  }) async {
    final form = FormData.fromMap({
      'source': source,
      'kind': kind,
      'created_by': createdBy,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await api.dio.post('/places/imports/upload', data: form);
    return AdminImportJob.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
