import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../core/token_storage.dart';

class CreateTripPage extends StatefulWidget {
  const CreateTripPage({super.key});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  final ApiClient apiClient = ApiClient(TokenStorage());

  Future<void> _pickDate({required bool isStart}) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2030);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? initialDate) : (_endDate ?? initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTrip() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите даты начала и окончания')),
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дата начала не может быть позже даты окончания')),
      );
      return;
    }

    final tripData = {
      "title": _titleController.text,
      "description": _descriptionController.text,
      "start_date": _startDate!.toIso8601String().split('T')[0],
      "end_date": _endDate!.toIso8601String().split('T')[0],
    };

    final response = await apiClient.createTrip(tripData);

    if (response != null && response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Путешествие создано!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при создании')),
      );
    }
  }

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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_startDate == null
                        ? 'Выбрать дату начала'
                        : 'Начало: ${_startDate!.toLocal().toString().split(' ')[0]}'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_endDate == null
                        ? 'Выбрать дату окончания'
                        : 'Окончание: ${_endDate!.toLocal().toString().split(' ')[0]}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveTrip,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
