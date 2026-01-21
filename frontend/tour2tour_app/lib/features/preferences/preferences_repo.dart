import '../../api/api_client.dart';

class PreferencesRepo {
  final ApiClient api;
  PreferencesRepo(this.api);

  Future<List<String>> getPreferences() async {
    final res = await api.dio.get('/users/me/preferences');
    // ожидаем что бэк отдаёт список строк или items.
    final data = res.data;

    if (data is List) {
      return data.cast<String>();
    }
    if (data is Map && data['items'] is List) {
      final items = (data['items'] as List).cast<Map>();
      return items.map((e) => (e['value'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> setPreferences(List<String> interests) async {
    final items = interests.map((v) => {'key': 'interest', 'value': v}).toList();
    await api.dio.post('/users/me/preferences', data: {'items': items});
  }
}
