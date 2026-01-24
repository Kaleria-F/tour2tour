// lib/config.dart
import 'package:flutter/foundation.dart';

class Config {
  static const _androidEmulator = 'http://10.0.2.2:8000';
  static const _web = 'http://127.0.0.1:8000';

  static String get apiBaseUrl => kIsWeb ? _web : _androidEmulator;
}
