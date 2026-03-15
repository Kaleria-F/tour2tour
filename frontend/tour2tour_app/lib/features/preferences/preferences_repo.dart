import '../../api/api_client.dart';

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
}
