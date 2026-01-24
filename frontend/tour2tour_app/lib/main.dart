import 'package:flutter/material.dart';
import 'router.dart';

void main() {
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
