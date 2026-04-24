import 'package:flutter/widgets.dart';

class YandexCityMap extends StatelessWidget {
  final String? city;
  final List<Map<String, String>> stagePoints;

  const YandexCityMap({
    super.key,
    required this.city,
    this.stagePoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
