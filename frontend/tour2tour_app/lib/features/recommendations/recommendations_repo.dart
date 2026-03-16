import '../../api/api_client.dart';
import '../preferences/preferences_repo.dart';

class RecommendationItem {
  final String id;
  final String title;
  final String description;
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
  }) async {
    final res = await api.dio.post(
      '/recommendations/personalized',
      data: {
        'profile': profile.toJson(),
        'city': city,
        'near_route': nearRoute,
      },
    );
    final data = res.data;
    if (data is! Map || data['items'] is! List) return [];
    return (data['items'] as List)
        .whereType<Map>()
        .map((raw) => RecommendationItem.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }
}
