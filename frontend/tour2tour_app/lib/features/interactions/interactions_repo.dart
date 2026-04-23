import '../../api/api_client.dart';

class FavoritePlace {
  final String placeId;
  final String title;
  final String city;
  final String? address;
  final String? imageUrl;
  final String? category;
  final String? subcategory;
  final double? rating;
  final String? description;
  final int? tripId;
  final String? tripTitle;

  FavoritePlace({
    required this.placeId,
    required this.title,
    required this.city,
    this.address,
    this.imageUrl,
    this.category,
    this.subcategory,
    this.rating,
    this.description,
    this.tripId,
    this.tripTitle,
  });

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      placeId: (json['place_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      address: json['address']?.toString(),
      imageUrl: json['image_url']?.toString(),
      category: json['category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      rating: double.tryParse((json['rating'] ?? '').toString()),
      description: json['description']?.toString(),
      tripId: int.tryParse((json['trip_id'] ?? '').toString()),
      tripTitle: json['trip_title']?.toString(),
    );
  }
}

class FavoriteCityGroup {
  final String city;
  final List<FavoritePlace> items;

  FavoriteCityGroup({
    required this.city,
    required this.items,
  });

  factory FavoriteCityGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return FavoriteCityGroup(
      city: (json['city'] ?? '').toString(),
      items: rawItems
          .whereType<Map>()
          .map((item) => FavoritePlace.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class InteractionsRepo {
  final ApiClient api;

  InteractionsRepo(this.api);

  Future<void> trackEvent({
    required String userId,
    required String placeId,
    required String action,
    String context = 'recommendation',
    String? sessionId,
    String? recommendationId,
    double weight = 1.0,
    Map<String, dynamic>? metadata,
  }) async {
    await api.dio.post(
      '/interactions/events',
      data: {
        'user_id': userId,
        'place_id': placeId,
        'action': action,
        'context': context,
        'session_id': sessionId,
        'recommendation_id': recommendationId,
        'weight': weight,
        'metadata_json': metadata,
      },
    );
  }

  Future<void> trackImpression({
    required String userId,
    required String placeId,
    required String recommendationId,
    required int position,
    String context = 'recommendation',
  }) async {
    await api.dio.post(
      '/interactions/impressions',
      data: {
        'user_id': userId,
        'place_id': placeId,
        'recommendation_id': recommendationId,
        'position': position,
        'context': context,
      },
    );
  }

  Future<List<FavoriteCityGroup>> getFavorites({
    required String userId,
    int? tripId,
    String? city,
  }) async {
    final res = await api.dio.get(
      '/interactions/users/$userId/favorites',
      queryParameters: {
        if (tripId != null) 'trip_id': tripId,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) => FavoriteCityGroup.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }
}
