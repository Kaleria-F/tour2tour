import 'package:flutter/material.dart';
import 'router.dart';

void main() {
  runApp(const Tour2TourApp());
}

class Tour2TourApp extends StatelessWidget {
  const Tour2TourApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      title: 'Tour2Tour',
      routerConfig: router,
    );
  }
}
