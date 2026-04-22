import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

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

class Tour2TourApp extends StatelessWidget {
  const Tour2TourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildRouter(),
    );
  }
}
