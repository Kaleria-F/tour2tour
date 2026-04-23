import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _mapViewCounter = 0;

class YandexCityMap extends StatefulWidget {
  final String? city;

  const YandexCityMap({super.key, required this.city});

  @override
  State<YandexCityMap> createState() => _YandexCityMapState();
}

class _YandexCityMapState extends State<YandexCityMap> {
  late final String _viewType;
  late final html.DivElement _container;
  String? _lastCity;

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
    if ((oldWidget.city ?? '').trim() != (widget.city ?? '').trim()) {
      _syncCityAttribute();
    }
  }

  void _syncCityAttribute() {
    final city = (widget.city ?? '').trim();
    if (city.isEmpty) {
      _container.attributes.remove('data-city');
      return;
    }
    if (city == _lastCity) return;
    _lastCity = city;
    _container.setAttribute('data-city', city);
    _container.dispatchEvent(html.CustomEvent('t2t-city-change'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
