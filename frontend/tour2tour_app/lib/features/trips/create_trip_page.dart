import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../core/token_storage.dart';

class CreateTripPage extends StatelessWidget {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Чтобы работать с API, нужен экземпляр ApiClient с токеном
  final ApiClient apiClient = ApiClient(TokenStorage());

  CreateTripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать путешествие')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Сбор данных для отправки
                final tripData = {
                  "title": _titleController.text,
                  "description": _descriptionController.text,
                  "start_date": "2026-05-10", // позже можно сделать выбор даты
                  "end_date": "2026-05-15",
                };

                final response = await apiClient.createTrip(tripData);

                if (response != null && response.statusCode == 200) {
                  // Если успех, закрываем экран и возвращаемся назад
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Путешествие создано!')),
                  );
                  Navigator.pop(context);
                } else {
                  // Если ошибка — выводим сообщение
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка при создании')),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
