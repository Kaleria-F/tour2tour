import '../../api/api_client.dart';

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
}
