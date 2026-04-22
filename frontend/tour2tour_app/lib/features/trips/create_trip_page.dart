import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/travel_app_shell.dart';
import 'trips_repo.dart';

class CreateTripPage extends StatefulWidget {
  final TripsRepo tripsRepo;

  const CreateTripPage({super.key, required this.tripsRepo});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _destinationCityController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  List<CitySuggestion> _citySuggestions = const [];
  int _cityRequestId = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _destinationCityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (_startDate ?? initialDate) : (_endDate ?? initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _loadCitySuggestions(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) {
        setState(() => _citySuggestions = const []);
      }
      return;
    }

    final requestId = ++_cityRequestId;
    try {
      final suggestions = await widget.tripsRepo.suggestCities(query);
      if (!mounted || requestId != _cityRequestId) return;
      setState(() => _citySuggestions = suggestions);
    } catch (_) {
      if (!mounted || requestId != _cityRequestId) return;
      setState(() => _citySuggestions = const []);
    }
  }

  Future<void> _saveTrip() async {
    final title = _titleController.text.trim();
    final destinationCity = _destinationCityController.text.trim();

    if (title.isEmpty) {
      _showHint('Введите название путешествия');
      return;
    }
    if (destinationCity.isEmpty) {
      _showHint('Укажите город поездки');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showHint('Выберите даты поездки');
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      _showHint('Дата начала не может быть позже даты окончания');
      return;
    }

    setState(() => _saving = true);
    try {
      final trip = await widget.tripsRepo.createTrip(
        title: title,
        description: _descriptionController.text.trim(),
        destinationCity: destinationCity,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (!mounted) return;
      if (trip == null) {
        _showHint('Не удалось создать путешествие');
        return;
      }

      context.go(
        '/trip-workspace',
        extra: {
          'id': trip.id,
          'title': trip.title,
          'destination_city': trip.destinationCity,
          'start_date': trip.startDate,
          'end_date': trip.endDate,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TravelAppShell(
      title: 'Plan your trip',
      subtitle: 'Соберите маршрут и подберите город для рекомендаций',
      currentTab: TravelNavTab.planner,
      headerAction: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.go('/profile'),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Icon(Icons.person_outline_rounded, color: Colors.white),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TravelSearchBar(
            label: _destinationCityController.text.trim().isEmpty
                ? 'Куда отправимся?'
                : _destinationCityController.text.trim(),
            onTap: () {},
            trailing: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TravelCapsuleButton(
                  label: 'Weekend',
                  active: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TravelCapsuleButton(
                  label: 'Culture',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TravelCapsuleButton(
                  label: 'Route',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TravelCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Создать путешествие',
                    style: TextStyle(
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Сначала выберите город. Затем маршрут и рекомендации будут подстраиваться под поездку.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _TripField(
                            controller: _titleController,
                            label: 'Название',
                            icon: Icons.luggage_rounded,
                          ),
                          const SizedBox(height: 12),
                          Autocomplete<CitySuggestion>(
                            displayStringForOption: (option) => option.city,
                            optionsBuilder: (textEditingValue) {
                              final query =
                                  textEditingValue.text.trim().toLowerCase();
                              if (query.length < 2) {
                                return const Iterable<CitySuggestion>.empty();
                              }
                              return _citySuggestions.where((item) {
                                return item.city.toLowerCase().contains(query) ||
                                    item.displayName
                                        .toLowerCase()
                                        .contains(query);
                              });
                            },
                            onSelected: (option) {
                              _destinationCityController.value =
                                  TextEditingValue(
                                text: option.city,
                                selection: TextSelection.collapsed(
                                  offset: option.city.length,
                                ),
                              );
                              setState(() {});
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              if (controller.text !=
                                  _destinationCityController.text) {
                                controller.value =
                                    _destinationCityController.value;
                              }
                              return _TripField(
                                controller: controller,
                                focusNode: focusNode,
                                label: 'Город поездки',
                                hintText: 'Начните вводить город',
                                icon: Icons.location_on_outlined,
                                onChanged: (value) {
                                  _destinationCityController.value =
                                      controller.value;
                                  _loadCitySuggestions(value);
                                  setState(() {});
                                },
                              );
                            },
                            optionsViewBuilder:
                                (context, onSelected, options) {
                              final items = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: const BoxConstraints(
                                      maxWidth: 360,
                                      maxHeight: 240,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF212121),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      shrinkWrap: true,
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                      itemBuilder: (context, index) {
                                        final option = items[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            option.city,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: Text(
                                            option.displayName,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.62),
                                            ),
                                          ),
                                          onTap: () => onSelected(option),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _TripField(
                            controller: _descriptionController,
                            label: 'Описание',
                            icon: Icons.notes_rounded,
                            minLines: 3,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _DateChip(
                                  label: _startDate == null
                                      ? 'Дата начала'
                                      : _fmtDate(_startDate!),
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateChip(
                                  label: _endDate == null
                                      ? 'Дата окончания'
                                      : _fmtDate(_endDate!),
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD7E37A),
                        foregroundColor: const Color(0xFF151515),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Сохранить',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class _TripField extends StatelessWidget {
  const _TripField({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hintText;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF272727),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            margin: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD7E37A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              minLines: minLines,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                ),
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF272727),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                color: Color(0xFFD7E37A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
