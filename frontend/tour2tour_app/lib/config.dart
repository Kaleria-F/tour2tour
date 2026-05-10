// lib/config.dart
import 'package:flutter/foundation.dart';

class Config {
  static const _androidEmulator = 'http://10.0.2.2:8888';
  static const _webLocal = 'http://127.0.0.1:8888';
  static const _apiOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const _premiumCheckoutOverride =
      String.fromEnvironment('PREMIUM_CHECKOUT_URL', defaultValue: '');
  static const _forcePremiumPopupOverride =
      String.fromEnvironment('FORCE_PREMIUM_POPUP', defaultValue: 'false');
  static const _premiumInnValue = '773771991088';

  static String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) {
      return _apiOverride;
    }
    return kIsWeb ? _webLocal : _androidEmulator;
  }

  static String get premiumCheckoutUrl => _premiumCheckoutOverride;
  static String get premiumInn => _premiumInnValue;
  static bool get forcePremiumPopupForTesting =>
      _forcePremiumPopupOverride.toLowerCase() == 'true';
}
