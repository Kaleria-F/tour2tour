import 'package:flutter/widgets.dart';

class YandexCityMap extends StatelessWidget {
  final String? city;
  final double? cityCenterLat;
  final double? cityCenterLon;
  final String? searchQuery;
  final double? searchPointLat;
  final double? searchPointLon;
  final ValueChanged<String>? onAddRouteFromSearch;
  final List<Map<String, String>> stagePoints;

  const YandexCityMap({
    super.key,
    required this.city,
    this.cityCenterLat,
    this.cityCenterLon,
    this.searchQuery,
    this.searchPointLat,
    this.searchPointLon,
    this.onAddRouteFromSearch,
    this.stagePoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
