import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'core/app_connectivity_coordinator.dart';
import 'core/app_theme.dart';
import 'core/mapkit/mapkit_initializer.dart';
import 'router.dart';

const _mapkitApiKey = 'c95547fc-7c45-4d4d-bade-669cccac5337';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await initializeMapkit(_mapkitApiKey);

  runApp(const Tour2TourApp());
}

class Tour2TourApp extends StatefulWidget {
  const Tour2TourApp({super.key});

  @override
  State<Tour2TourApp> createState() => _Tour2TourAppState();
}

class _Tour2TourAppState extends State<Tour2TourApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final router = buildRouter();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  bool get _shouldMonitorMobileConnectivity {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _startConnectivityMonitoring() async {
    if (!_shouldMonitorMobileConnectivity) return;
    final connectivity = Connectivity();
    final initialResult = await connectivity.checkConnectivity();
    _applyConnectivityState(initialResult, showNotification: false);
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((results) {
      _applyConnectivityState(results, showNotification: true);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _showConnectivitySnackBar(String message) {
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Geologica',
              color: Color(0xFF171717),
              fontWeight: FontWeight.w400,
            ),
          ),
          backgroundColor: const Color(0xFFD7E37A),
          behavior: SnackBarBehavior.floating,
          width: 430,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
  }

  void _applyConnectivityState(
    List<ConnectivityResult> results, {
    required bool showNotification,
  }) {
    final coordinator = AppConnectivityCoordinator.instance;
    final isOnline = _hasConnection(results);
    final wasOffline = coordinator.isOffline;

    if (isOnline) {
      coordinator.markOnline();
      if (showNotification && wasOffline) {
        _showConnectivitySnackBar('Соединение восстановлено');
      }
      return;
    }

    coordinator.markOffline();
    if (showNotification && !wasOffline) {
      _showConnectivitySnackBar('Нет подключения к интернету');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: router,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
