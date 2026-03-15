import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/api_client.dart';

class UploadInitResult {
  final String objectKey;
  final String uploadUrl;

  UploadInitResult({
    required this.objectKey,
    required this.uploadUrl,
  });
}

class TripDocument {
  final String objectKey;
  final String fileName;
  final int sizeBytes;
  final DateTime? lastModified;

  TripDocument({
    required this.objectKey,
    required this.fileName,
    required this.sizeBytes,
    required this.lastModified,
  });

  factory TripDocument.fromJson(Map<String, dynamic> json) {
    return TripDocument(
      objectKey: (json['object_key'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      sizeBytes: (json['size_bytes'] ?? 0) as int,
      lastModified: json['last_modified'] == null
          ? null
          : DateTime.tryParse(json['last_modified'].toString()),
    );
  }
}

class DocumentsRepo {
  final ApiClient api;
  DocumentsRepo(this.api);

  Future<void> ensureBucket() async {
    await api.dio.post('/documents/storage/ensure-bucket');
  }

  Future<UploadInitResult> uploadInit({
    required int tripId,
    required String fileName,
    required String contentType,
  }) async {
    final res = await api.dio.post(
      '/documents/upload-init',
      data: {
        'trip_id': tripId,
        'file_name': fileName,
        'content_type': contentType,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return UploadInitResult(
      objectKey: (data['object_key'] ?? '').toString(),
      uploadUrl: (data['upload_url'] ?? '').toString(),
    );
  }

  Future<void> uploadBytesToPresigned({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final dio = Dio();
    await dio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
        },
      ),
    );
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

  Future<Uint8List> fetchFileBytes(String downloadUrl) async {
    final dio = Dio();
    final res = await dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data;
    if (bytes == null) return Uint8List(0);
    return Uint8List.fromList(bytes);
  }
}
