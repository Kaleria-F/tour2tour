import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'core/token_storage.dart';
import 'features/trips/create_trip_page.dart';
import 'features/trips/trips_repo.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(TokenStorage());
    final tripsRepo = TripsRepo(api);

    return MaterialApp(
      title: 'Тест создания путешествия',
      home: CreateTripPage(tripsRepo: tripsRepo), // сразу открываем наш экран
    );
  }
}
