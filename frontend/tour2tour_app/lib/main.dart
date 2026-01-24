import 'package:flutter/material.dart';
import 'router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy();
  runApp(const Tour2TourApp());
}

class Tour2TourApp extends StatelessWidget {
  const Tour2TourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: buildRouter(),
    );
  }
}
