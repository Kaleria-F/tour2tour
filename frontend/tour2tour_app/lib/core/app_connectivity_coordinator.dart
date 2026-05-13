import 'package:flutter/foundation.dart';

class AppConnectivityCoordinator extends ChangeNotifier {
  AppConnectivityCoordinator._();

  static final AppConnectivityCoordinator instance =
      AppConnectivityCoordinator._();

  bool _isOffline = false;
  int _refreshVersion = 0;

  bool get isOffline => _isOffline;
  int get refreshVersion => _refreshVersion;

  void markOffline() {
    if (_isOffline) return;
    _isOffline = true;
    notifyListeners();
  }

  void markOnline() {
    final wasOffline = _isOffline;
    _isOffline = false;
    if (wasOffline) {
      _refreshVersion += 1;
    }
    notifyListeners();
  }
}
