import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit/mapkit_factory.dart' as ymk_factory;
import 'package:yandex_maps_mapkit/search.dart' as ymk_search;
import 'package:yandex_maps_mapkit/yandex_map.dart';

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
  static const _fallbackCenter = ymk.Point(latitude: 55.755814, longitude: 37.617635);
  static const double _stageCircleSize = 30.0;
  static const double _stageNumberSize = 12.0;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  ymk.MapWindow? _mapWindow;
  ymk.Map? _map;
  ymk_search.SearchManager? _searchManager;
  ymk_search.SearchSession? _activeSearchSession;
  ymk_search.SearchSessionSearchListener? _activeSearchListener;

  final Map<String, ymk.Point> _geocodeCache = <String, ymk.Point>{};
  int _renderRev = 0;

  final List<_StageMarkerRef> _stageMarkers = <_StageMarkerRef>[];
  final List<int> _selectedStageMarkerIndexes = <int>[];
  _MapInputListener? _mapInputListener;
  _ResolvedStagePoint? _selectedStageInfo;

  _SearchMarkerRef? _searchMarker;
  ymk.PolylineMapObject? _routeLine;

  bool _routeBuilderActive = false;
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
      _searchManager ??= ymk_search.SearchFactory.instance
          .createSearchManager(ymk_search.SearchManagerType.Online);
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
              child: _routeBuilderActive
                  ? _buildRoutePanel()
                  : _buildRouteStartButton(),
            ),
            Positioned(
              right: 10,
              bottom: 34,
              child: _buildAddButton(),
            ),
            Positioned(
              right: 10,
              top: 12,
              child: _buildZoomControls(),
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
            children: [
              ..._RouteMode.values.map((mode) {
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
              InkWell(
                onTap: _closeRouteBuilder,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_routeInfo, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildRouteStartButton() {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: _openRouteBuilder,
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
          'Построить маршрут',
          style: TextStyle(
            fontFamily: 'Geologica',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _openRouteBuilder() {
    _removeRouteLine();
    _selectedStageMarkerIndexes.clear();
    _applyStageSelectionStyles();
    setState(() {
      _selectedStageInfo = null;
      _routeBuilderActive = true;
      _routeInfo = 'Выберите 2 точки на карте';
    });
  }

  void _closeRouteBuilder() {
    _removeRouteLine();
    _selectedStageMarkerIndexes.clear();
    _applyStageSelectionStyles();
    setState(() {
      _routeBuilderActive = false;
      _routeInfo = 'Выберите 2 точки на карте';
    });
  }

  Widget _buildAddButton() {
    final visible = (_lastSearchAddress ?? '').trim().isNotEmpty;
    if (!visible) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
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
        icon: const Icon(Icons.add_road_rounded, size: 16),
        label: const Text(
          'Этап',
          style: TextStyle(
            fontFamily: 'Geologica',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    Widget zoomBtn({
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return SizedBox(
        width: 40,
        height: 40,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xEE131829),
            foregroundColor: const Color(0xFFD7E37A),
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.24)),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        zoomBtn(
          icon: Icons.add_rounded,
          onPressed: () => _zoomBy(1),
        ),
        const SizedBox(height: 8),
        zoomBtn(
          icon: Icons.remove_rounded,
          onPressed: () => _zoomBy(-1),
        ),
      ],
    );
  }

  void _zoomBy(int delta) {
    final map = _map;
    if (map == null) return;
    final current = map.cameraPosition;
    final nextZoom = (current.zoom + delta).clamp(2.0, 20.0);
    map.move(
      ymk.CameraPosition(
        current.target,
        zoom: nextZoom,
        azimuth: current.azimuth,
        tilt: current.tilt,
      ),
      animation: const ymk.Animation(
        type: ymk.AnimationType.Smooth,
        duration: 0.18,
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
        stageType: (p['stage_type'] ?? '').trim(),
        subtype: (p['subtype'] ?? '').trim(),
        time: (p['time'] ?? '').trim(),
        startTime: (p['start_time'] ?? '').trim(),
        endTime: (p['end_time'] ?? '').trim(),
        cost: (p['cost'] ?? '').trim(),
        duration: (p['duration'] ?? '').trim(),
        startLocation: (p['start_location'] ?? '').trim(),
        endLocation: (p['end_location'] ?? '').trim(),
        referenceNumber: (p['reference_number'] ?? '').trim(),
        notes: (p['notes'] ?? '').trim(),
        websiteUrl: (p['website_url'] ?? '').trim(),
        rating: (p['rating'] ?? '').trim(),
        documentKey: (p['document_key'] ?? '').trim(),
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
          stageType: parsed[i].stageType,
          subtype: parsed[i].subtype,
          time: parsed[i].time,
          startTime: parsed[i].startTime,
          endTime: parsed[i].endTime,
          cost: parsed[i].cost,
          duration: parsed[i].duration,
          startLocation: parsed[i].startLocation,
          endLocation: parsed[i].endLocation,
          referenceNumber: parsed[i].referenceNumber,
          notes: parsed[i].notes,
          websiteUrl: parsed[i].websiteUrl,
          rating: parsed[i].rating,
          documentKey: parsed[i].documentKey,
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
      // Draw stage marker as a dedicated circle + centered number to match web UI.
      final circle = map.mapObjects.addPlacemarkWithPoint(resolved[i].point);
      circle.setIconStyle(
        const ymk.IconStyle(
          scale: 1.0,
          zIndex: 20,
        ),
      );
      circle.setTextWithStyle(
        const ymk.TextStyle(
          size: _stageCircleSize,
          color: Color(0xFF8FB2F8),
          outlineColor: Color(0xFF162C4A),
          outlineWidth: 3.0,
          placement: ymk.TextStylePlacement.Center,
        ),
        text: '\u25CF',
      );

      final number = map.mapObjects.addPlacemarkWithPoint(resolved[i].point);
      number.setIconStyle(
        const ymk.IconStyle(
          scale: 1.0,
          zIndex: 40,
        ),
      );
      number.setTextWithStyle(
        const ymk.TextStyle(
          size: 13.0,
          color: Color(0xFFFFFFFF),
          outlineColor: Color(0xFF0A0A0A),
          outlineWidth: 2.2,
          placement: ymk.TextStylePlacement.Center,
        ),
        text: resolved[i].order,
      );
      try {
        number.text.text = resolved[i].order;
      } catch (_) {}
      final listener = _StageTapListener(onTap: () async {
        if (!_routeBuilderActive) {
          if (mounted) {
            setState(() {
              _selectedStageInfo = resolved[i];
            });
          }
          return;
        }
        final existing = _selectedStageMarkerIndexes.indexOf(i);
        if (existing >= 0) {
          _selectedStageMarkerIndexes.removeAt(existing);
        } else {
          if (_selectedStageMarkerIndexes.length >= 2) {
            _selectedStageMarkerIndexes.removeAt(0);
          }
          _selectedStageMarkerIndexes.add(i);
        }
        _applyStageSelectionStyles();
        await _buildRouteIfReady();
      });
      circle.addTapListener(listener);
      number.addTapListener(listener);
      _stageMarkers.add(_StageMarkerRef(
        placemark: circle,
        numberPlacemark: number,
        listener: listener,
        point: resolved[i].point,
        stage: resolved[i],
      ));
    }
    _applyStageSelectionStyles();

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
    marker.setIconStyle(
      const ymk.IconStyle(
        scale: 1.0,
        zIndex: 20,
      ),
    );
    marker.setTextWithStyle(
      const ymk.TextStyle(
        size: 38,
        color: Color(0xFF71D96A),
        outlineColor: Color(0xFF1F4F1E),
        outlineWidth: 2.6,
        placement: ymk.TextStylePlacement.Center,
      ),
      text: '\u25CF',
    );
    final listener = _StageTapListener(onTap: () async {
      if (!_routeBuilderActive) return;
      final existing = _selectedStageMarkerIndexes.indexOf(-1);
      if (existing >= 0) {
        _selectedStageMarkerIndexes.removeAt(existing);
      } else {
        if (_selectedStageMarkerIndexes.length >= 2) {
          _selectedStageMarkerIndexes.removeAt(0);
        }
        _selectedStageMarkerIndexes.add(-1);
      }
      _applyStageSelectionStyles();
      await _buildRouteIfReady();
    });
    marker.addTapListener(listener);
    _searchMarker = _SearchMarkerRef(
      placemark: marker,
      point: point,
      listener: listener,
    );
    _lastSearchAddress = clean;

    map.move(
      ymk.CameraPosition(point, zoom: 15, azimuth: 0, tilt: 0),
      animation: const ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.22),
    );
    if (mounted) setState(() {});
  }

  Future<void> _buildRouteIfReady() async {
    if (!_routeBuilderActive) return;
    final map = _map;
    if (map == null) return;
    _removeRouteLine();
    if (_selectedStageMarkerIndexes.length != 2) {
      _applyStageSelectionStyles();
      if (mounted) setState(() => _routeInfo = 'Выберите 2 точки на карте');
      return;
    }
    _applyStageSelectionStyles();

    ymk.Point? pointBySelection(int index) {
      if (index == -1) return _searchMarker?.point;
      if (index < 0 || index >= _stageMarkers.length) return null;
      return _stageMarkers[index].point;
    }

    final first = pointBySelection(_selectedStageMarkerIndexes[0]);
    final second = pointBySelection(_selectedStageMarkerIndexes[1]);
    if (first == null || second == null) {
      if (mounted) setState(() => _routeInfo = 'Выберите 2 точки на карте');
      return;
    }
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

    final manager = _searchManager;
    if (manager == null) return null;
    final completer = Completer<ymk.Point?>();
    _activeSearchListener = ymk_search.SearchSessionSearchListener(
      onSearchResponse: (response) {
        if (completer.isCompleted) return;
        ymk.Point? resolved;
        for (final child in response.collection.children) {
          final geo = child.asGeoObject();
          if (geo == null) continue;
          for (final g in geo.geometry) {
            final p = g.asPoint();
            if (p != null) {
              resolved = ymk.Point(latitude: p.latitude, longitude: p.longitude);
              break;
            }
            final b = g.asBoundingBox();
            if (b != null) {
              resolved = ymk.Point(
                latitude: (b.southWest.latitude + b.northEast.latitude) / 2.0,
                longitude: (b.southWest.longitude + b.northEast.longitude) / 2.0,
              );
              break;
            }
          }
          if (resolved != null) break;
          final bb = geo.boundingBox;
          if (bb != null) {
            resolved = ymk.Point(
              latitude: (bb.southWest.latitude + bb.northEast.latitude) / 2.0,
              longitude: (bb.southWest.longitude + bb.northEast.longitude) / 2.0,
            );
            break;
          }
        }
        completer.complete(resolved);
      },
      onSearchError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    final centerLat = widget.cityCenterLat ?? _fallbackCenter.latitude;
    final centerLon = widget.cityCenterLon ?? _fallbackCenter.longitude;
    const latSpan = 0.8;
    const lonSpan = 1.2;
    final window = ymk.BoundingBox(
      ymk.Point(
        latitude: (centerLat - latSpan).clamp(-90.0, 90.0),
        longitude: (centerLon - lonSpan).clamp(-180.0, 180.0),
      ),
      ymk.Point(
        latitude: (centerLat + latSpan).clamp(-90.0, 90.0),
        longitude: (centerLon + lonSpan).clamp(-180.0, 180.0),
      ),
    );

    try {
      _activeSearchSession?.cancel();
      _activeSearchSession = manager.submit(
        ymk.Geometry.fromBoundingBox(window),
        ymk_search.SearchOptions(
          searchTypes: ymk_search.SearchType.Geo | ymk_search.SearchType.Biz,
          geometry: true,
        ),
        _activeSearchListener!,
        text: query,
      );
      final point = await completer.future.timeout(
        const Duration(seconds: 7),
        onTimeout: () => null,
      );
      if (point != null) {
        _geocodeCache[normalized] = point;
      }
      return point;
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
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
      try {
        marker.numberPlacemark?.removeTapListener(marker.listener);
      } catch (_) {}
      try {
        if (marker.numberPlacemark != null) {
          _map?.mapObjects.remove(marker.numberPlacemark!);
        }
      } catch (_) {}
    }
    _stageMarkers.clear();
    _selectedStageMarkerIndexes.clear();
    try {
      _map?.mapObjects.clear();
    } catch (_) {}
  }

  void _handleMapLongTap(ymk.Point point) {
    // Details are opened by short tap on a stage marker.
    // Keep long tap as a no-op to avoid conflicts with route selection mode.
    return;
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
    if (bestDistanceM > 220) return null;
    return best;
  }

  void _applyStageSelectionStyles() {
    for (var i = 0; i < _stageMarkers.length; i++) {
      final selected = _selectedStageMarkerIndexes.contains(i);
      final circle = _stageMarkers[i].placemark;
      final number = _stageMarkers[i].numberPlacemark;
      try {
        circle.setTextWithStyle(
          ymk.TextStyle(
            size: _stageCircleSize,
            color: const Color(0xFF8FB2F8),
            outlineColor:
                selected ? const Color(0xFFFFFFFF) : const Color(0xFF162C4A),
            outlineWidth: selected ? 4.0 : 3.0,
            placement: ymk.TextStylePlacement.Center,
          ),
          text: '\u25CF',
        );
      } catch (_) {}
      if (number != null) {
        try {
          number.setIconStyle(
            ymk.IconStyle(
              scale: 1.0,
              zIndex: selected ? 60 : 40,
            ),
          );
          number.setTextWithStyle(
            const ymk.TextStyle(
              size: 13.0,
              color: Color(0xFFFFFFFF),
              outlineColor: Color(0xFF0A0A0A),
              outlineWidth: 2.2,
              placement: ymk.TextStylePlacement.Center,
            ),
            text: _stageMarkers[i].stage.order,
          );
          try {
            number.text.text = _stageMarkers[i].stage.order;
          } catch (_) {}
        } catch (_) {}
      }
    }
    final search = _searchMarker;
    if (search != null) {
      final selected = _selectedStageMarkerIndexes.contains(-1);
      try {
        search.placemark.setTextWithStyle(
          ymk.TextStyle(
            size: 38,
            color: const Color(0xFF71D96A),
            outlineColor:
                selected ? const Color(0xFFFFFFFF) : const Color(0xFF1F4F1E),
            outlineWidth: selected ? 4.0 : 2.6,
            placement: ymk.TextStylePlacement.Center,
          ),
          text: '\u25CF',
        );
      } catch (_) {}
    }
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
    if (stage.duration.isNotEmpty) lines.add('Длительность: ${stage.duration}');
    if (stage.cost.isNotEmpty) lines.add('Стоимость: ${stage.cost}');
    final cityNorm = (widget.city ?? '').trim().toLowerCase();
    String displayAddress = stage.address.trim();
    if (displayAddress.isEmpty) {
      displayAddress = stage.endLocation.trim().isNotEmpty
          ? stage.endLocation.trim()
          : stage.startLocation.trim();
    } else if (cityNorm.isNotEmpty && displayAddress.toLowerCase() == cityNorm) {
      displayAddress = stage.endLocation.trim().isNotEmpty
          ? stage.endLocation.trim()
          : (stage.startLocation.trim().isNotEmpty ? stage.startLocation.trim() : displayAddress);
    }
    if (displayAddress.isNotEmpty) lines.add('Адрес: $displayAddress');
    if (stage.startLocation.isNotEmpty) lines.add('Откуда: ${stage.startLocation}');
    if (stage.endLocation.isNotEmpty) lines.add('Куда: ${stage.endLocation}');
    if (stage.referenceNumber.isNotEmpty) lines.add('Номер/референс: ${stage.referenceNumber}');
    if (stage.notes.isNotEmpty) lines.add('Комментарий: ${stage.notes}');
    if (stage.websiteUrl.isNotEmpty) lines.add('Сайт: ${stage.websiteUrl}');
    if (stage.rating.isNotEmpty) lines.add('Рейтинг: ${stage.rating}');
    if (stage.documentKey.isNotEmpty) lines.add('Документ: прикреплен');
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
      marker.placemark.removeTapListener(marker.listener);
    } catch (_) {}
    try {
      _map?.mapObjects.remove(marker.placemark);
    } catch (_) {}
    _selectedStageMarkerIndexes.removeWhere((e) => e == -1);
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
  final String stageType;
  final String subtype;
  final String time;
  final String startTime;
  final String endTime;
  final String cost;
  final String duration;
  final String startLocation;
  final String endLocation;
  final String referenceNumber;
  final String notes;
  final String websiteUrl;
  final String rating;
  final String documentKey;
  _StagePoint({
    required this.title,
    required this.address,
    required this.order,
    required this.stageType,
    required this.subtype,
    required this.time,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.referenceNumber,
    required this.notes,
    required this.websiteUrl,
    required this.rating,
    required this.documentKey,
  });
}

class _ResolvedStagePoint {
  final String title;
  final String address;
  final String order;
  final String stageType;
  final String subtype;
  final String time;
  final String startTime;
  final String endTime;
  final String cost;
  final String duration;
  final String startLocation;
  final String endLocation;
  final String referenceNumber;
  final String notes;
  final String websiteUrl;
  final String rating;
  final String documentKey;
  final ymk.Point point;
  _ResolvedStagePoint({
    required this.title,
    required this.address,
    required this.order,
    required this.stageType,
    required this.subtype,
    required this.time,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.referenceNumber,
    required this.notes,
    required this.websiteUrl,
    required this.rating,
    required this.documentKey,
    required this.point,
  });
}

class _StageMarkerRef {
  final ymk.PlacemarkMapObject placemark;
  final ymk.PlacemarkMapObject? numberPlacemark;
  final _StageTapListener listener;
  final ymk.Point point;
  final _ResolvedStagePoint stage;
  _StageMarkerRef({
    required this.placemark,
    this.numberPlacemark,
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
  final _StageTapListener listener;
  _SearchMarkerRef({
    required this.placemark,
    required this.point,
    required this.listener,
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



