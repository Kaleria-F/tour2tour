import 'package:flutter/foundation.dart';

class SessionCoordinator extends ChangeNotifier {
  SessionCoordinator._();

  static final SessionCoordinator instance = SessionCoordinator._();

  void Function()? _webSessionExpiredHandler;
  bool _handlingWebSessionExpiry = false;
  bool _webSessionExpired = false;

  bool get webSessionExpired => _webSessionExpired;

  void registerWebSessionExpiredHandler(void Function() handler) {
    _webSessionExpiredHandler = handler;
  }

  void resetWebSessionExpiryState() {
    _handlingWebSessionExpiry = false;
    if (_webSessionExpired) {
      _webSessionExpired = false;
      notifyListeners();
    }
  }

  void handleWebSessionExpired() {
    if (_handlingWebSessionExpiry) return;
    _handlingWebSessionExpiry = true;
    _webSessionExpired = true;
    notifyListeners();
    _webSessionExpiredHandler?.call();
  }
}
