import 'package:flutter/material.dart';
import 'features/trips/create_trip_page.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тест создания путешествия',
      home: CreateTripPage(), // сразу открываем наш экран
    );
  }
}
