import 'package:flutter/foundation.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;

bool _mapkitReady = true;

Future<void> initializeMapkit(String apiKey) async {
  if (apiKey.isEmpty) return;

  // The SDK works on mobile targets only.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      await init.initMapkit(
        apiKey: apiKey,
        locale: 'ru_RU',
      );
      _mapkitReady = true;
    } catch (e, st) {
      _mapkitReady = false;
      debugPrint('MapKit init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

bool get isMapkitReady => _mapkitReady;
