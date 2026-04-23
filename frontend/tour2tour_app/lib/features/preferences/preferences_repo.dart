import '../../api/api_client.dart';

class SurveyProfile {
  final List<String> interests;
  final List<String> tripFormats;
  final String? budget;
  final String? travelMode;
  final String? pace;
  final Map<String, int> interestWeights;
  final bool skipped;
  final bool hasCompleted;

  SurveyProfile({
    required this.interests,
    required this.tripFormats,
    required this.budget,
    required this.travelMode,
    required this.pace,
    required this.interestWeights,
    required this.skipped,
    required this.hasCompleted,
  });

  factory SurveyProfile.empty() {
    return SurveyProfile(
      interests: const [],
      tripFormats: const [],
      budget: null,
      travelMode: null,
      pace: null,
      interestWeights: const {},
      skipped: true,
      hasCompleted: false,
    );
  }

  factory SurveyProfile.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['interest_weights'];
    final weights = <String, int>{};
    if (rawWeights is Map) {
      for (final entry in rawWeights.entries) {
        final weight = int.tryParse(entry.value.toString());
        if (weight == null) continue;
        weights[entry.key.toString()] = weight;
      }
    }
    return SurveyProfile(
      interests: (json['interests'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      tripFormats: (json['trip_formats'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      budget: json['budget']?.toString(),
      travelMode: json['travel_mode']?.toString(),
      pace: json['pace']?.toString(),
      interestWeights: weights,
      skipped: json['skipped'] == true,
      hasCompleted: json['has_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interests': interests,
      'trip_formats': tripFormats,
      'budget': budget,
      'travel_mode': travelMode,
      'pace': pace,
      'interest_weights': interestWeights,
      'skipped': skipped,
    };
  }
}

class PreferencesRepo {
  final ApiClient api;
  PreferencesRepo(this.api);

  Future<List<String>> getPreferences() async {
    final res = await api.dio.get('/users/me/preferences');
    final data = res.data;

    if (data is Map && data['interests'] is List) {
      return (data['interests'] as List)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> setPreferences(List<String> interests) async {
    await api.dio.post('/users/me/preferences', data: {'interests': interests});
  }

  Future<SurveyProfile> getSurveyProfile() async {
    final res = await api.dio.get('/users/me/survey-profile');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      return SurveyProfile.empty();
    }
    return SurveyProfile.fromJson(data);
  }

  Future<SurveyProfile> setSurveyProfile(SurveyProfile profile) async {
    final res = await api.dio.post(
      '/users/me/survey-profile',
      data: profile.toJson(),
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return profile;
    return SurveyProfile.fromJson(data);
  }
}
