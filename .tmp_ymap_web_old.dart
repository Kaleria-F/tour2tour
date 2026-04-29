import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _mapViewCounter = 0;

class YandexCityMap extends StatefulWidget {
  final String? city;
  final List<Map<String, String>> stagePoints;

  const YandexCityMap({
    super.key,
    required this.city,
    this.stagePoints = const [],
  });

  @override
  State<YandexCityMap> createState() => _YandexCityMapState();
}

class _YandexCityMapState extends State<YandexCityMap> {
  late final String _viewType;
  late final html.DivElement _container;
  String? _lastCity;
  String? _lastPointsJson;

  @override
  void initState() {
    super.initState();
    _viewType = 't2t-yandex-city-map-${_mapViewCounter++}';
    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.borderRadius = '12px'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = '#131a2d';
    _container.classes.add('t2t-yandex-city-map');

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _container;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCityAttribute());
  }

  @override
  void didUpdateWidget(covariant YandexCityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCity = (oldWidget.city ?? '').trim();
    final newCity = (widget.city ?? '').trim();
    final oldPoints = jsonEncode(oldWidget.stagePoints);
    final newPoints = jsonEncode(widget.stagePoints);
    if (oldCity != newCity || oldPoints != newPoints) {
      _syncCityAttribute();
    }
  }

  void _syncCityAttribute() {
    final city = (widget.city ?? '').trim();
    if (city.isEmpty) {
      _container.attributes.remove('data-city');
    } else {
      _lastCity = city;
      _container.setAttribute('data-city', city);
    }
    final points = widget.stagePoints
        .map((point) => {
              'title': (point['title'] ?? '').trim(),
              'address': (point['address'] ?? '').trim(),
              'order': (point['order'] ?? '').trim(),
            })
        .where((point) => (point['address'] ?? '').isNotEmpty)
        .toList();
    final pointsJson = jsonEncode(points);
    if (_lastPointsJson != pointsJson) {
      _lastPointsJson = pointsJson;
      _container.setAttribute('data-stage-points', pointsJson);
    }
    _container.dispatchEvent(html.CustomEvent('t2t-city-change'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
