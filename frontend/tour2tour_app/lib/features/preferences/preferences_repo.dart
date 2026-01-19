import '../../core/api_client.dart';

class PreferencesRepo {
  final ApiClient api;
  PreferencesRepo(this.api);

  Future<List<String>> getPreferences() async {
    final res = await api.dio.get('/users/me/preferences');
    final list = (res.data['interests'] as List).map((e) => e.toString()).toList();
    return list;
  }

  Future<void> setPreferences(List<String> interests) async {
    await api.dio.post('/users/me/preferences', data: {'interests': interests});
  }
}
