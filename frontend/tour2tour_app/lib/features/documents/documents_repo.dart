import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/api_client.dart';

class TripDocument {
  final String objectKey;
  final String fileName;
  final int sizeBytes;
  final DateTime? lastModified;
  final String itemType;
  final bool isShared;
  final int? sharedCount;

  TripDocument({
    required this.objectKey,
    required this.fileName,
    required this.sizeBytes,
    required this.lastModified,
    required this.itemType,
    required this.isShared,
    required this.sharedCount,
  });

  factory TripDocument.fromJson(Map<String, dynamic> json) {
    return TripDocument(
      objectKey: (json['object_key'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      sizeBytes: (json['size_bytes'] ?? 0) as int,
      lastModified: json['last_modified'] == null
          ? null
          : DateTime.tryParse(json['last_modified'].toString()),
      itemType: (json['item_type'] ?? 'file').toString(),
      isShared: (json['is_shared'] ?? false) == true,
      sharedCount: json['shared_count'] == null ? null : (json['shared_count'] as int),
    );
  }
}

class DocumentsRepo {
  final ApiClient api;
  DocumentsRepo(this.api);

  Future<TripDocument> uploadBytesDirect({
    required int tripId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final form = FormData.fromMap({
      'trip_id': tripId.toString(),
      'file_name': fileName,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final res = await api.dio.post(
      '/documents/upload-direct',
      data: form,
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawDocument = Map<String, dynamic>.from(data['document'] as Map);
    return TripDocument.fromJson(rawDocument);
  }

  Future<List<TripDocument>> listTripDocuments(int tripId) async {
    final res = await api.dio.get('/documents/trips/$tripId');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripDocument.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<String> getDownloadUrl(String objectKey) async {
    final res = await api.dio.post(
      '/documents/download-url',
      data: {'object_key': objectKey},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['download_url'] ?? '').toString();
  }

  Future<void> deleteObject(String objectKey) async {
    await api.dio.delete(
      '/documents/object',
      queryParameters: {'object_key': objectKey},
    );
  }

  Future<TripDocument> renameObject({
    required String objectKey,
    required String fileName,
  }) async {
    final res = await api.dio.patch(
      '/documents/object/rename',
      data: {'object_key': objectKey, 'file_name': fileName},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return TripDocument.fromJson(data);
  }

  Future<List<TripDocument>> listSharedDocuments() async {
    final res = await api.dio.get('/documents/shared');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => TripDocument.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<TripDocument> uploadSharedBytesDirect({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final form = FormData.fromMap({
      'file_name': fileName,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final res = await api.dio.post('/documents/shared/upload-direct', data: form);
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawDocument = Map<String, dynamic>.from(data['document'] as Map);
    return TripDocument.fromJson(rawDocument);
  }

  Future<void> deleteSharedObject(String objectKey) async {
    await api.dio.delete(
      '/documents/shared/object',
      queryParameters: {'object_key': objectKey},
    );
  }

  Future<TripDocument> renameSharedObject({
    required String objectKey,
    required String fileName,
  }) async {
    final res = await api.dio.patch(
      '/documents/shared/object/rename',
      data: {'object_key': objectKey, 'file_name': fileName},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return TripDocument.fromJson(data);
  }

  Future<Uint8List> fetchFileBytes(String downloadUrl) async {
    final isAbsolute = downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://');
    final res = isAbsolute
        ? await Dio().get<List<int>>(
            downloadUrl,
            options: Options(responseType: ResponseType.bytes),
          )
        : await api.dio.get<List<int>>(
            downloadUrl,
            options: Options(responseType: ResponseType.bytes),
          );
    final bytes = res.data;
    if (bytes == null) return Uint8List(0);
    return Uint8List.fromList(bytes);
  }
}
