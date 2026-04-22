import 'package:flutter/foundation.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;

Future<void> initializeMapkit(String apiKey) async {
  if (apiKey.isEmpty) return;

  // The SDK works on mobile targets only.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await init.initMapkit(apiKey: apiKey);
  }
}
