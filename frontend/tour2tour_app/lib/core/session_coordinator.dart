class SessionCoordinator {
  SessionCoordinator._();

  static final SessionCoordinator instance = SessionCoordinator._();

  void Function()? _webSessionExpiredHandler;
  bool _handlingWebSessionExpiry = false;

  void registerWebSessionExpiredHandler(void Function() handler) {
    _webSessionExpiredHandler = handler;
  }

  void resetWebSessionExpiryState() {
    _handlingWebSessionExpiry = false;
  }

  void handleWebSessionExpired() {
    if (_handlingWebSessionExpiry) return;
    _handlingWebSessionExpiry = true;
    _webSessionExpiredHandler?.call();
  }
}
