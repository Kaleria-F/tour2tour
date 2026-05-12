import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart' as ymk_factory;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../../../config.dart';
import '../../../core/mapkit/mapkit_initializer.dart';

class YandexCityMap extends StatefulWidget {
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
  State<YandexCityMap> createState() => _YandexCityMapState();
}

class _YandexCityMapState extends State<YandexCityMap> with WidgetsBindingObserver {
  static const _geocoderApiKey = 'acf6e354-8f9c-4163-9d37-54bf33ee956b';
  static const _fallbackCenter = ymk.Point(latitude: 55.755814, longitude: 37.617635);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  ymk.MapWindow? _mapWindow;
  ymk.Map? _map;

  final Map<String, ymk.Point> _geocodeCache = <String, ymk.Point>{};
  int _renderRev = 0;

  final List<_StageMarkerRef> _stageMarkers = <_StageMarkerRef>[];
  final List<int> _selectedStageMarkerIndexes = <int>[];
  _MapInputListener? _mapInputListener;
  _ResolvedStagePoint? _selectedStageInfo;

  _SearchMarkerRef? _searchMarker;
  ymk.PolylineMapObject? _routeLine;

  _RouteMode _routeMode = _RouteMode.drivingCar;
  String _routeInfo = 'Выберите 2 точки на карте';
  String? _lastSearchAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMapkitIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startMapkitIfNeeded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopMapkitIfNeeded();
        break;
    }
  }

  @override
  void didUpdateWidget(covariant YandexCityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map == null) return;

    final oldCity = (oldWidget.city ?? '').trim();
    final newCity = (widget.city ?? '').trim();
    final oldQuery = (oldWidget.searchQuery ?? '').trim();
    final newQuery = (widget.searchQuery ?? '').trim();
    final oldSearchLat = oldWidget.searchPointLat;
    final newSearchLat = widget.searchPointLat;
    final oldSearchLon = oldWidget.searchPointLon;
    final newSearchLon = widget.searchPointLon;
    final oldPoints = jsonEncode(oldWidget.stagePoints);
    final newPoints = jsonEncode(widget.stagePoints);
    final oldCenterLat = oldWidget.cityCenterLat;
    final newCenterLat = widget.cityCenterLat;
    final oldCenterLon = oldWidget.cityCenterLon;
    final newCenterLon = widget.cityCenterLon;

    if (oldCity != newCity ||
        oldPoints != newPoints ||
        oldCenterLat != newCenterLat ||
        oldCenterLon != newCenterLon) {
      _rebuildMarkersAndSearch();
      return;
    }
    if (oldQuery != newQuery) {
      _applySearchMarker(newQuery);
      return;
    }
    if (oldSearchLat != newSearchLat || oldSearchLon != newSearchLon) {
      _applySearchMarker(newQuery);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopMapkitIfNeeded();
    _clearAllMapObjects();
    _dio.close(force: true);
    super.dispose();
  }

  void _startMapkitIfNeeded() {
    if (!_isMobileTarget || !isMapkitReady) return;
    try {
      ymk_factory.mapkit.onStart();
    } catch (_) {}
  }

  void _stopMapkitIfNeeded() {
    if (!_isMobileTarget || !isMapkitReady) return;
    try {
      ymk_factory.mapkit.onStop();
    } catch (_) {}
  }

  bool get _isMobileTarget =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  List<String> _cityQueryCandidates(String rawCity) {
    final city = rawCity.trim();
    if (city.isEmpty) return const <String>[];
    final core = city.split(',').first.trim();
    final out = <String>[];
    void add(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (!out.any((e) => e.toLowerCase() == v.toLowerCase())) out.add(v);
    }

    add(city);
    add(core);
    add('$city, Россия');
    add('$core, Россия');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobileTarget) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          color: const Color(0xFF131A2D),
        ),
        alignment: Alignment.center,
        child: Text(
          'Карта поддерживается на Android/iOS',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }
    if (!isMapkitReady) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          color: const Color(0xFF131A2D),
        ),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'Карта временно недоступна на этом устройстве.\nПроверьте Android-конфигурацию MapKit.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.88), height: 1.35),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: YandexMap(
                onMapCreated: (window) {
                  _mapWindow = window;
                  _map = window.map
                    ..move(
                      const ymk.CameraPosition(
                        _fallbackCenter,
                        zoom: 11,
                        azimuth: 0,
                        tilt: 0,
                      ),
                    );
                  _mapInputListener = _MapInputListener(onLongTap: _handleMapLongTap);
                  _map?.addInputListener(_mapInputListener!);
                  _rebuildMarkersAndSearch();
                },
              ),
            ),
            Positioned(
              left: 10,
              bottom: 34,
              child: _buildRoutePanel(),
            ),
            Positioned(
              right: 10,
              bottom: 34,
              child: _buildAddButton(),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: 10,
              right: 10,
              bottom: _selectedStageInfo == null ? -180 : 8,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _selectedStageInfo == null ? 0 : 1,
                child: _selectedStageInfo == null
                    ? const SizedBox.shrink()
                    : _buildStageInfoCard(_selectedStageInfo!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePanel() {
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.92),
      fontFamily: 'Geologica',
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xEE131829),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _RouteMode.values.map((mode) {
              final selected = _routeMode == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () async {
                    setState(() => _routeMode = mode);
                    await _buildRouteIfReady();
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 46,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0x2ED7E37A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? const Color(0xFFD7E37A) : Colors.white24,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(mode.icon, color: const Color(0xFFD7E37A), size: 18),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(_routeInfo, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    final visible = (_lastSearchAddress ?? '').trim().isNotEmpty;
    if (!visible) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          final address = (_lastSearchAddress ?? '').trim();
          if (address.isEmpty) return;
          widget.onAddRouteFromSearch?.call(address);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xEE131829),
          foregroundColor: const Color(0xFFD7E37A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: Colors.white.withOpacity(0.24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text(
          'Добавить в маршрут',
          style: TextStyle(
            fontFamily: 'Geologica',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _rebuildMarkersAndSearch() async {
    final map = _map;
    if (map == null) return;
    final revision = ++_renderRev;
    _clearAllMapObjects();

    final parsed = <_StagePoint>[];
    for (final p in widget.stagePoints) {
      final address = (p['address'] ?? '').trim();
      if (address.isEmpty) continue;
      final title = (p['title'] ?? '').trim();
      parsed.add(_StagePoint(
        title: title.isEmpty ? address : title,
        address: address,
        order: (p['order'] ?? '').trim(),
        time: (p['time'] ?? '').trim(),
        cost: (p['cost'] ?? '').trim(),
        notes: (p['notes'] ?? '').trim(),
      ));
    }

    final resolved = <_ResolvedStagePoint>[];
    for (var i = 0; i < parsed.length; i++) {
      final coords = await _geocode(parsed[i].address);
      if (!mounted || revision != _renderRev) return;
      if (coords == null) continue;
      resolved.add(
        _ResolvedStagePoint(
          title: parsed[i].title,
          address: parsed[i].address,
          order: parsed[i].order.isEmpty ? '${resolved.length + 1}' : parsed[i].order,
          time: parsed[i].time,
          cost: parsed[i].cost,
          notes: parsed[i].notes,
          point: coords,
        ),
      );
    }

    final cityQuery = (widget.city ?? '').trim();
    ymk.Point? focus;
    final centerLat = widget.cityCenterLat;
    final centerLon = widget.cityCenterLon;
    if (centerLat != null && centerLon != null) {
      focus = ymk.Point(latitude: centerLat, longitude: centerLon);
    }
    if (focus == null && cityQuery.isNotEmpty) {
      for (final candidate in _cityQueryCandidates(cityQuery)) {
        focus = await _geocode(candidate);
        if (!mounted || revision != _renderRev) return;
        if (focus != null) break;
      }
    }
    focus ??= _averagePoint(resolved.map((e) => e.point).toList()) ?? _fallbackCenter;

    for (var i = 0; i < resolved.length; i++) {
      final place = map.mapObjects.addPlacemarkWithPoint(resolved[i].point);
      place.setTextWithStyle(
        const ymk.TextStyle(
          size: 13,
          color: Color(0xFF111827),
          outlineColor: Color(0xFFFFFFFF),
          outlineWidth: 2,
          placement: ymk.TextStylePlacement.Center,
        ),
        text: resolved[i].order,
      );
      final listener = _StageTapListener(onTap: () async {
        final existing = _selectedStageMarkerIndexes.indexOf(i);
        if (existing >= 0) {
          _selectedStageMarkerIndexes.removeAt(existing);
        } else {
          if (_selectedStageMarkerIndexes.length >= 2) {
            _selectedStageMarkerIndexes.removeAt(0);
          }
          _selectedStageMarkerIndexes.add(i);
        }
        await _buildRouteIfReady();
      });
      place.addTapListener(listener);
      _stageMarkers.add(_StageMarkerRef(
        placemark: place,
        listener: listener,
        point: resolved[i].point,
        stage: resolved[i],
      ));
    }

    map.move(
      ymk.CameraPosition(
        focus,
        zoom: resolved.length > 1 ? 10 : 12,
        azimuth: 0,
        tilt: 0,
      ),
      animation: const ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.22),
    );

    await _applySearchMarker((widget.searchQuery ?? '').trim());
    await _buildRouteIfReady();
    if (mounted) setState(() {});
  }

  Future<void> _applySearchMarker(String query) async {
    final map = _map;
    if (map == null) return;
    _removeSearchMarker();

    final clean = query.trim();
    if (clean.isEmpty) {
      _lastSearchAddress = null;
      if (mounted) setState(() {});
      return;
    }
    final city = (widget.city ?? '').trim();
    final cityCore = city.split(',').first.trim();
    final lowerClean = clean.toLowerCase();
    final hasCityInQuery = city.isNotEmpty &&
        (lowerClean.contains(city.toLowerCase()) ||
            (cityCore.isNotEmpty && lowerClean.contains(cityCore.toLowerCase())));
    final fullQuery = !hasCityInQuery && cityCore.isNotEmpty ? '$clean, $cityCore' : clean;
    ymk.Point? point;
    final bySuggestLat = widget.searchPointLat;
    final bySuggestLon = widget.searchPointLon;
    if (bySuggestLat != null && bySuggestLon != null) {
      point = ymk.Point(latitude: bySuggestLat, longitude: bySuggestLon);
    } else {
      point = await _geocode(fullQuery);
    }
    if (!mounted || _map == null) return;
    if (point == null) {
      _lastSearchAddress = null;
      if (mounted) setState(() {});
      return;
    }

    final marker = map.mapObjects.addPlacemarkWithPoint(point);
    marker.setTextWithStyle(
      const ymk.TextStyle(
        size: 16,
        color: Color(0xFF63BE56),
        outlineColor: Color(0xFF173117),
        outlineWidth: 2,
        placement: ymk.TextStylePlacement.Center,
      ),
      text: '●',
    );
    _searchMarker = _SearchMarkerRef(placemark: marker, point: point);
    _lastSearchAddress = clean;

    map.move(
      ymk.CameraPosition(point, zoom: 15, azimuth: 0, tilt: 0),
      animation: const ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.22),
    );
    if (mounted) setState(() {});
  }

  Future<void> _buildRouteIfReady() async {
    final map = _map;
    if (map == null) return;
    _removeRouteLine();
    if (_selectedStageMarkerIndexes.length != 2) {
      if (mounted) setState(() => _routeInfo = 'Выберите 2 точки на карте');
      return;
    }

    final first = _stageMarkers[_selectedStageMarkerIndexes[0]].point;
    final second = _stageMarkers[_selectedStageMarkerIndexes[1]].point;
    if (mounted) setState(() => _routeInfo = 'Строим маршрут...');

    try {
      final response = await _dio.post(
        '${Config.apiBaseUrl}/trips/routing/ors/route',
        data: {
          'mode': _routeMode.apiMode,
          'points': [
            {'lon': first.longitude, 'lat': first.latitude},
            {'lon': second.longitude, 'lat': second.latitude},
          ],
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        if (mounted) setState(() => _routeInfo = 'Маршрут недоступен');
        return;
      }
      final geometry = data['geometry'];
      final coordsRaw = geometry is Map ? geometry['coordinates'] : null;
      if (coordsRaw is! List) {
        if (mounted) setState(() => _routeInfo = 'Маршрут не найден');
        return;
      }
      final points = <ymk.Point>[];
      for (final c in coordsRaw) {
        if (c is! List || c.length < 2) continue;
        final lon = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lon == null || lat == null) continue;
        points.add(ymk.Point(latitude: lat, longitude: lon));
      }
      if (points.length < 2) {
        if (mounted) setState(() => _routeInfo = 'Маршрут не найден');
        return;
      }
      final line = map.mapObjects.addPolylineWithGeometry(ymk.Polyline(points));
      line.setStrokeColor(const Color(0xFF72ACFF));
      line.style = const ymk.LineStyle(strokeWidth: 5, outlineWidth: 1.5, outlineColor: Color(0xB3151B2A));
      _routeLine = line;

      final distance = (data['distance_m'] as num?)?.toDouble();
      final duration = (data['duration_s'] as num?)?.toDouble();
      if (distance != null && duration != null) {
        if (mounted) {
          setState(
            () => _routeInfo =
                'Маршрут: ${_formatDuration(duration)} · ${_formatDistance(distance)}',
          );
        }
      } else {
        if (mounted) setState(() => _routeInfo = 'Маршрут построен');
      }
    } catch (_) {
      if (mounted) setState(() => _routeInfo = 'Маршрут недоступен');
    }
  }

  Future<ymk.Point?> _geocode(String query) async {
    final normalized = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    final cached = _geocodeCache[normalized];
    if (cached != null) return cached;
    try {
      final resp = await _dio.get(
        'https://geocode-maps.yandex.ru/v1/',
        queryParameters: <String, dynamic>{
          'apikey': _geocoderApiKey,
          'format': 'json',
          'results': 1,
          'lang': 'ru_RU',
          'geocode': query,
        },
      );
      final data = resp.data;
      final member = data is Map
          ? (((data['response'] as Map?)?['GeoObjectCollection'] as Map?)?['featureMember'] as List?)
          : null;
      if (member == null || member.isEmpty) return null;
      final pos = (((member.first as Map?)?['GeoObject'] as Map?)?['Point'] as Map?)?['pos'];
      final raw = '$pos'.trim();
      final parts = raw.split(' ');
      if (parts.length != 2) return null;
      final lon = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lon == null || lat == null) return null;
      final point = ymk.Point(latitude: lat, longitude: lon);
      _geocodeCache[normalized] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  ymk.Point? _averagePoint(List<ymk.Point> points) {
    if (points.isEmpty) return null;
    var lat = 0.0;
    var lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return ymk.Point(latitude: lat / points.length, longitude: lon / points.length);
  }

  void _clearAllMapObjects() {
    if (_mapInputListener != null) {
      try {
        _map?.removeInputListener(_mapInputListener!);
      } catch (_) {}
      _mapInputListener = null;
    }
    _removeRouteLine();
    _removeSearchMarker();
    for (final marker in _stageMarkers) {
      try {
        marker.placemark.removeTapListener(marker.listener);
      } catch (_) {}
    }
    _stageMarkers.clear();
    _selectedStageMarkerIndexes.clear();
    try {
      _map?.mapObjects.clear();
    } catch (_) {}
  }

  void _handleMapLongTap(ymk.Point point) {
    if (_stageMarkers.isEmpty) return;
    final nearest = _findNearestStage(point);
    if (nearest == null) return;
    setState(() {
      _selectedStageInfo = nearest;
    });
  }

  _ResolvedStagePoint? _findNearestStage(ymk.Point tapPoint) {
    _ResolvedStagePoint? best;
    double bestDistanceM = double.infinity;
    for (final marker in _stageMarkers) {
      final distance = _distanceMeters(
        tapPoint.latitude,
        tapPoint.longitude,
        marker.point.latitude,
        marker.point.longitude,
      );
      if (distance < bestDistanceM) {
        bestDistanceM = distance;
        best = marker.stage;
      }
    }
    if (bestDistanceM > 150) return null;
    return best;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthR = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthR * c;
  }

  double _degToRad(double deg) => deg * 0.017453292519943295;

  Widget _buildStageInfoCard(_ResolvedStagePoint stage) {
    final lines = <String>[];
    if (stage.time.isNotEmpty) lines.add('Время: ${stage.time}');
    if (stage.cost.isNotEmpty) lines.add('Стоимость: ${stage.cost}');
    if (stage.address.isNotEmpty) lines.add('Адрес: ${stage.address}');
    if (stage.notes.isNotEmpty) lines.add('Комментарий: ${stage.notes}');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xF0131829),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Geologica',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedStageInfo = null),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                splashRadius: 18,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (lines.isEmpty)
            Text(
              'Нет дополнительных данных',
              style: TextStyle(
                color: Colors.white.withOpacity(0.84),
                fontFamily: 'Geologica',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontFamily: 'Geologica',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _removeSearchMarker() {
    final marker = _searchMarker;
    if (marker == null) return;
    try {
      _map?.mapObjects.remove(marker.placemark);
    } catch (_) {}
    _searchMarker = null;
  }

  void _removeRouteLine() {
    final line = _routeLine;
    if (line == null) return;
    try {
      _map?.mapObjects.remove(line);
    } catch (_) {}
    _routeLine = null;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} км';
    }
    return '${meters.round()} м';
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins мин';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }
}

class _StageTapListener implements ymk.MapObjectTapListener {
  final VoidCallback onTap;
  _StageTapListener({required this.onTap});

  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) {
    onTap();
    return true;
  }
}

class _StagePoint {
  final String title;
  final String address;
  final String order;
  final String time;
  final String cost;
  final String notes;
  _StagePoint({
    required this.title,
    required this.address,
    required this.order,
    required this.time,
    required this.cost,
    required this.notes,
  });
}

class _ResolvedStagePoint {
  final String title;
  final String address;
  final String order;
  final String time;
  final String cost;
  final String notes;
  final ymk.Point point;
  _ResolvedStagePoint({
    required this.title,
    required this.address,
    required this.order,
    required this.time,
    required this.cost,
    required this.notes,
    required this.point,
  });
}

class _StageMarkerRef {
  final ymk.PlacemarkMapObject placemark;
  final _StageTapListener listener;
  final ymk.Point point;
  final _ResolvedStagePoint stage;
  _StageMarkerRef({
    required this.placemark,
    required this.listener,
    required this.point,
    required this.stage,
  });
}

class _MapInputListener implements ymk.MapInputListener {
  final ValueChanged<ymk.Point> onLongTap;
  _MapInputListener({required this.onLongTap});

  @override
  void onMapLongTap(ymk.Map map, ymk.Point point) {
    onLongTap(point);
  }

  @override
  void onMapTap(ymk.Map map, ymk.Point point) {}
}

class _SearchMarkerRef {
  final ymk.PlacemarkMapObject placemark;
  final ymk.Point point;
  _SearchMarkerRef({
    required this.placemark,
    required this.point,
  });
}

enum _RouteMode {
  drivingCar('driving-car', Icons.directions_car_filled_rounded),
  footWalking('foot-walking', Icons.directions_walk_rounded),
  cyclingRegular('cycling-regular', Icons.pedal_bike_rounded);

  final String apiMode;
  final IconData icon;
  const _RouteMode(this.apiMode, this.icon);
}
