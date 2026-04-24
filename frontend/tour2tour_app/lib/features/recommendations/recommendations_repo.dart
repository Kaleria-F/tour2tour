import '../../api/api_client.dart';
import '../preferences/preferences_repo.dart';

class RecommendationItem {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String subcategory;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final double finalScore;
  final double interestScore;
  final double budgetBonus;
  final double distanceBonus;
  final double tripTypeBonus;
  final double popularityBonus;

  RecommendationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.subcategory,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.finalScore,
    required this.interestScore,
    required this.budgetBonus,
    required this.distanceBonus,
    required this.tripTypeBonus,
    required this.popularityBonus,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;

    return RecommendationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      rating: asDouble(json['rating']),
      finalScore: asDouble(json['final_score']),
      interestScore: asDouble(json['interest_score']),
      budgetBonus: asDouble(json['budget_bonus']),
      distanceBonus: asDouble(json['distance_bonus']),
      tripTypeBonus: asDouble(json['trip_type_bonus']),
      popularityBonus: asDouble(json['popularity_bonus']),
    );
  }
}

class RecommendationsRepo {
  final ApiClient api;

  RecommendationsRepo(this.api);

  Future<List<RecommendationItem>> getPersonalized({
    required SurveyProfile profile,
    String? city,
    bool nearRoute = false,
    double? routeLatitude,
    double? routeLongitude,
    String? userId,
  }) async {
    try {
      final res = await api.dio.post(
        '/recommendations/personalized',
        data: {
          'profile': profile.toJson(),
          'city': city,
          'near_route': nearRoute,
          'route_latitude': routeLatitude,
          'route_longitude': routeLongitude,
          'user_id': userId,
        },
      );
      final data = res.data;
      if (data is! Map || data['items'] is! List) {
        return _syntheticRecommendations(city: city);
      }
      final items = (data['items'] as List)
          .whereType<Map>()
          .map((raw) => RecommendationItem.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
      return items.isEmpty ? _syntheticRecommendations(city: city) : items;
    } catch (_) {
      return _syntheticRecommendations(city: city);
    }
  }

  List<RecommendationItem> _syntheticRecommendations({String? city}) {
    final resolvedCity = (city == null || city.isEmpty) ? 'Москва' : city;
    return [
      RecommendationItem(
        id: 'synthetic-tretyakov',
        title: 'Третьяковская галерея',
        description: 'Крупнейшая коллекция русского искусства в центре города.',
        imageUrl: '',
        category: 'place',
        subcategory: 'museum',
        city: resolvedCity,
        address: 'Лаврушинский переулок, 10',
        latitude: 55.7414,
        longitude: 37.6208,
        rating: 4.8,
        finalScore: 91,
        interestScore: 56,
        budgetBonus: 8,
        distanceBonus: 10,
        tripTypeBonus: 12,
        popularityBonus: 5,
      ),
      RecommendationItem(
        id: 'synthetic-gorky',
        title: 'Парк Горького',
        description: 'Большой зеленый парк для прогулок, кофе и спокойного отдыха.',
        imageUrl: '',
        category: 'place',
        subcategory: 'park',
        city: resolvedCity,
        address: 'Крымский Вал, 9',
        latitude: 55.7308,
        longitude: 37.6013,
        rating: 4.7,
        finalScore: 88,
        interestScore: 48,
        budgetBonus: 8,
        distanceBonus: 12,
        tripTypeBonus: 16,
        popularityBonus: 4,
      ),
      RecommendationItem(
        id: 'synthetic-patriarshie',
        title: 'Патриаршие пруды',
        description: 'Атмосферный район для прогулки, ужина и вечерних фотографий.',
        imageUrl: '',
        category: 'place',
        subcategory: 'walk',
        city: resolvedCity,
        address: 'Патриаршие пруды',
        latitude: 55.7636,
        longitude: 37.5922,
        rating: 4.6,
        finalScore: 84,
        interestScore: 44,
        budgetBonus: 6,
        distanceBonus: 11,
        tripTypeBonus: 18,
        popularityBonus: 5,
      ),
    ];
  }
}
