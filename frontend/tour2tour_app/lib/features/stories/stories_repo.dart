import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../api/api_client.dart';

class StoryPlace {
  final String id;
  final String name;
  final String city;
  final String? imageUrl;
  final String? address;
  final String category;
  final String? subcategory;
  final double? rating;
  final String? description;

  StoryPlace({
    required this.id,
    required this.name,
    required this.city,
    required this.imageUrl,
    required this.address,
    required this.category,
    required this.subcategory,
    required this.rating,
    required this.description,
  });

  factory StoryPlace.fromJson(Map<String, dynamic> json) {
    return StoryPlace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      address: json['address']?.toString(),
      category: (json['category'] ?? '').toString(),
      subcategory: json['subcategory']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      description: json['description']?.toString(),
    );
  }
}

class StoryItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? coverImageUrl;
  final String? bodyText;
  final String? placeId;
  final int sortOrder;
  final bool isActive;
  final StoryPlace? place;

  StoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.coverImageUrl,
    required this.bodyText,
    required this.placeId,
    required this.sortOrder,
    required this.isActive,
    required this.place,
  });

  String get circleImageUrl => (coverImageUrl?.isNotEmpty ?? false) ? coverImageUrl! : imageUrl;

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      bodyText: json['body_text']?.toString(),
      placeId: json['place_id']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: (json['is_active'] ?? true) as bool,
      place: json['place'] is Map<String, dynamic>
          ? StoryPlace.fromJson(json['place'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StoriesRepo {
  static const _viewedKey = 'viewed_story_ids';

  final ApiClient api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  StoriesRepo(this.api);

  Future<List<StoryItem>> listStories() async {
    final res = await api.dio.get('/places/stories');
    final raw = (res.data as List? ?? const []);
    return raw
        .whereType<Map>()
        .map((item) => StoryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Set<String>> readViewedIds() async {
    final raw = await _storage.read(key: _viewedKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> markViewed(String storyId) async {
    final current = await readViewedIds();
    current.add(storyId);
    await _storage.write(key: _viewedKey, value: jsonEncode(current.toList()));
  }
}
