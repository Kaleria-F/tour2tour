import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const List<String> _cardColors = [
    '#D7E37A',
    '#B6A1FF',
    '#E3BA7A',
    '#A3E37A',
    '#E37AA2',
    '#7AE3BA',
    '#7AB4E3',
  ];

  static const List<String> _cardBackgrounds = [
    'brand_text',
    'city_text',
    'orbit',
    'waves',
    'mountains',
    'sunset',
    'aurora',
  ];

  static const List<String> _cardIcons = [
    'luggage',
    'flight',
    'terrain',
    'beach',
    'car',
    'forest',
    'camera',
  ];

  final _titleController = TextEditingController();
  final _destinationCityController = TextEditingController();
  final _plannedDaysController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _usePlannedDays = false;
  bool _saving = false;
  List<CitySuggestion> _citySuggestions = const [];
  List<CitySuggestion> _lastNonEmptyCitySuggestions = const [];
  int _cityRequestId = 0;
  String _selectedCardColor = '#D7E37A';
  String _selectedCardBackground = 'brand_text';
  String _selectedCardIcon = 'luggage';

  @override
  void dispose() {
    _titleController.dispose();
    _destinationCityController.dispose();
    _plannedDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickTripPeriod() async {
    final now = DateTime.now();
    final start = _startDate ?? now;
    final end = _endDate != null && !_endDate!.isBefore(start)
        ? _endDate!
        : start;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: start, end: end),
      helpText: 'Период поездки',
      cancelText: 'Отмена',
      saveText: 'ОК',
      fieldStartLabelText: 'Начало',
      fieldEndLabelText: 'Окончание',
      fieldStartHintText: 'дд.мм.гггг',
      fieldEndHintText: 'дд.мм.гггг',
      errorFormatText: 'Неверный формат даты',
      errorInvalidText: 'Неверный диапазон дат',
      errorInvalidRangeText: 'Дата окончания раньше даты начала',
      locale: const Locale('ru', 'RU'),
      switchToInputEntryModeIcon:
          const Icon(Icons.edit_outlined, color: Color(0xFFD7E37A)),
      switchToCalendarEntryModeIcon:
          const Icon(Icons.calendar_month_rounded, color: Color(0xFFD7E37A)),
      builder: (dialogContext, child) {
        final theme = Theme.of(dialogContext);
        return Theme(
          data: theme.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD7E37A),
              onPrimary: Color(0xFF161616),
              surface: Color(0xFF1E1F24),
              onSurface: Colors.white,
            ),
            textTheme: theme.textTheme.apply(
              fontFamily: 'Geologica',
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1F24),
            canvasColor: const Color(0xFF1E1F24),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1E1F24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF1E1F24),
              headerBackgroundColor: const Color(0xFF1E1F24),
              rangePickerBackgroundColor: const Color(0xFF1E1F24),
              rangePickerHeaderBackgroundColor: const Color(0xFF1E1F24),
              surfaceTintColor: Colors.transparent,
              rangePickerSurfaceTintColor: Colors.transparent,
              rangeSelectionBackgroundColor:
                  const Color(0xFFD7E37A).withOpacity(0.20),
              rangeSelectionOverlayColor: WidgetStateProperty.all(
                const Color(0xFFD7E37A).withOpacity(0.16),
              ),
              dayForegroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF161616);
                }
                if (states.contains(WidgetState.disabled)) {
                  return Colors.white.withOpacity(0.38);
                }
                return Colors.white;
              }),
              dayStyle: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              dayBackgroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFD7E37A);
                }
                return Colors.transparent;
              }),
              todayForegroundColor:
                  WidgetStateProperty.all(const Color(0xFFD7E37A)),
              todayBackgroundColor:
                  WidgetStateProperty.all(const Color(0xFF222715)),
              headerForegroundColor: Colors.white,
              rangePickerHeaderForegroundColor: Colors.white,
              weekdayStyle: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              yearStyle: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.white.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              rangePickerShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD7E37A),
                minimumSize: const Size(44, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontFamily: 'Geologica',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: SafeArea(child: child ?? const SizedBox.shrink()),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  Future<void> _loadCitySuggestions(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _citySuggestions = const [];
          _lastNonEmptyCitySuggestions = const [];
        });
      }
      return;
    }

    final requestId = ++_cityRequestId;
    try {
      final suggestions = await widget.tripsRepo.suggestCities(query);
      if (!mounted || requestId != _cityRequestId) return;
      setState(() {
        if (suggestions.isNotEmpty) {
          _citySuggestions = suggestions;
          _lastNonEmptyCitySuggestions = suggestions;
        } else if (_lastNonEmptyCitySuggestions.isNotEmpty) {
          _citySuggestions = _lastNonEmptyCitySuggestions;
        } else {
          _citySuggestions = const [];
        }
      });
    } catch (_) {
      if (!mounted || requestId != _cityRequestId) return;
      setState(() {
        if (_lastNonEmptyCitySuggestions.isNotEmpty) {
          _citySuggestions = _lastNonEmptyCitySuggestions;
        } else {
          _citySuggestions = const [];
        }
      });
    }
  }

  Future<void> _saveTrip() async {
    final title = _titleController.text.trim();
    final destinationCity = _destinationCityController.text.trim();
    final resolvedTitle = title.isEmpty ? destinationCity : title;

    if (destinationCity.isEmpty) {
      _showHint('Укажите город поездки');
      return;
    }
    DateTime startDate;
    DateTime endDate;
    int? plannedDays;
    if (_usePlannedDays) {
      final parsedDays = int.tryParse(_plannedDaysController.text.trim());
      if (parsedDays == null || parsedDays <= 0) {
        _showHint('Укажите корректное количество дней');
        return;
      }
      plannedDays = parsedDays;
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, now.day);
      endDate = startDate.add(Duration(days: parsedDays - 1));
    } else {
      if (_startDate == null || _endDate == null) {
        _showHint('Выберите даты поездки');
        return;
      }
      if (_startDate!.isAfter(_endDate!)) {
        _showHint('Дата начала не может быть позже даты окончания');
        return;
      }
      startDate = _startDate!;
      endDate = _endDate!;
    }

    setState(() => _saving = true);
    try {
      final trip = await widget.tripsRepo.createTrip(
        title: resolvedTitle,
        description: null,
        destinationCity: destinationCity,
        startDate: startDate,
        endDate: endDate,
        plannedDays: plannedDays,
        cardColor: _selectedCardColor,
        cardBackground: _selectedCardBackground,
        cardIcon: _selectedCardIcon,
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
          'planned_days': trip.plannedDays,
          'card_color': trip.cardColor,
          'card_background': trip.cardBackground,
          'card_icon': trip.cardIcon,
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
      title: '',
      subtitle: '',
      hideHeader: true,
      currentTab: TravelNavTab.planner,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Куда отправимся?',
            style: TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите город, и маршрут с рекомендациями автоматически подстроятся под выбранное направление.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TravelCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              _destinationCityController.value = TextEditingValue(
                                text: option.city,
                                selection: TextSelection.collapsed(
                                  offset: option.city.length,
                                ),
                              );
                              setState(() {});
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, onFieldSubmitted) {
                              if (controller.text !=
                                  _destinationCityController.text) {
                                controller.value =
                                    _destinationCityController.value;
                              }
                              return _CityTripField(
                                controller: controller,
                                focusNode: focusNode,
                                label: 'Город поездки',
                                isRequired: true,
                                hintText: 'Начните вводить город',
                                onChanged: (value) {
                                  _destinationCityController.value =
                                      controller.value;
                                  _loadCitySuggestions(value);
                                  setState(() {});
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
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
                                        final region = (option.region ?? '').trim();
                                        final district =
                                            (option.district ?? '').trim();
                                        final country = option.country.trim();

                                        final subtitleParts = <String>[
                                          if (region.isNotEmpty &&
                                              region != option.city.trim())
                                            region
                                          else if (district.isNotEmpty &&
                                              district != option.city.trim())
                                            district.toLowerCase().contains('округ')
                                                ? district
                                                : '$district округ',
                                          if (country.isNotEmpty) country,
                                        ];
                                        final subtitle = subtitleParts.join(', ');
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            option.city,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: subtitle.isEmpty
                                              ? null
                                              : Text(
                                                  '${option.city}, $subtitle',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.62),
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
                          const SizedBox(height: 10),
                          const SizedBox(height: 4),
                          _TripField(
                            controller: _titleController,
                            label: 'Название',
                            icon: Icons.luggage_rounded,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ModeChip(
                                  label: 'Точные даты',
                                  selected: !_usePlannedDays,
                                  onTap: () {
                                    setState(() {
                                      _usePlannedDays = false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ModeChip(
                                  label: 'Количество дней',
                                  selected: _usePlannedDays,
                                  onTap: () {
                                    setState(() {
                                      _usePlannedDays = true;
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_usePlannedDays)
                            _TripField(
                              controller: _plannedDaysController,
                              label: 'Количество дней',
                              isRequired: true,
                              icon: Icons.timelapse_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            )
                          else
                            _DateChip(
                              label: _tripPeriodLabel(),
                              isRequired: true,
                              onTap: _pickTripPeriod,
                            ),
                          const SizedBox(height: 14),
                          Text(
                            'Оформление карточки',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildColorPicker(),
                          const SizedBox(height: 10),
                          _buildBackgroundPicker(),
                          const SizedBox(height: 10),
                          _buildIconPicker(),
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

  String _tripPeriodLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Период поездки';
    }
    final start = _startDate!;
    final end = _endDate!;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return _fmtDate(start);
    }
    return '${_fmtDate(start)} — ${_fmtDate(end)}';
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _cardColors.map((hex) {
        final selected = _selectedCardColor == hex;
        final color = _hexToColor(hex);
        return InkWell(
          onTap: () => setState(() => _selectedCardColor = hex),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white.withOpacity(0.22),
                width: selected ? 2.2 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF171717))
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundPicker() {
    const previewAspect = 2.0; // match main trip-card art proportions
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cardBackgrounds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final bg = _cardBackgrounds[i];
          final selected = _selectedCardBackground == bg;
          return InkWell(
            onTap: () => setState(() => _selectedCardBackground = bg),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 58 * previewAspect,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? const Color(0xFFD7E37A) : Colors.white.withOpacity(0.18),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: AspectRatio(
                  aspectRatio: previewAspect,
                  child: _TripCardArt(
                    color: _hexToColor(_selectedCardColor),
                    background: bg,
                    icon: _iconByKey(_selectedCardIcon),
                    compact: true,
                    titleText: _destinationCityController.text.trim(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _cardIcons.map((key) {
        final selected = _selectedCardIcon == key;
        return InkWell(
          onTap: () => setState(() => _selectedCardIcon = key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFD7E37A) : Colors.white.withOpacity(0.16),
              ),
            ),
            child: Icon(_iconByKey(key), color: Colors.white, size: 20),
          ),
        );
      }).toList(),
    );
  }

  Color _hexToColor(String hex) {
    final raw = hex.replaceAll('#', '').trim();
    final value = int.tryParse(raw, radix: 16) ?? 0xD7E37A;
    return Color(0xFF000000 | value);
  }

  IconData _iconByKey(String key) {
    switch (key) {
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'terrain':
        return Icons.terrain_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'car':
        return Icons.directions_car_filled_rounded;
      case 'forest':
        return Icons.forest_rounded;
      case 'camera':
        return Icons.camera_alt_rounded;
      case 'luggage':
      default:
        return Icons.luggage_rounded;
    }
  }
}

class _TripCardArt extends StatelessWidget {
  final Color color;
  final String background;
  final IconData icon;
  final bool compact;
  final String? titleText;

  const _TripCardArt({
    required this.color,
    required this.background,
    required this.icon,
    this.compact = false,
    this.titleText,
  });

  @override
  Widget build(BuildContext context) {
    final base = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.38), const Color(0xFF181818)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _backgroundShape(background, color),
            if (background == 'city_text' || background == 'brand_text')
              Positioned(
                left: compact ? 8 : 18,
                right: compact ? 8 : 18,
                top: compact ? 8 : 16,
                child: Text(
                  background == 'brand_text'
                      ? 'Тур2Тур'
                      : (titleText?.trim().isNotEmpty == true
                          ? titleText!.trim()
                          : 'Город'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Geologica',
                    fontSize: compact ? 13 : 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.34),
                    height: 1.0,
                  ),
                ),
              ),
            Positioned(
              right: compact ? 8 : 22,
              top: compact ? 6 : 18,
              child: Icon(icon, size: compact ? 20 : 42, color: Colors.white.withOpacity(0.9)),
            ),
            Positioned(
              left: compact ? 10 : 22,
              right: compact ? 10 : 22,
              bottom: compact ? 8 : 22,
              child: _showTrackForIcon(icon)
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: compact ? 4 : 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    return base;
  }

  Widget _backgroundShape(String key, Color color) {
    switch (key) {
      case 'waves':
        return Positioned(
          left: -24,
          top: 12,
          child: Container(
            width: 150,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.26), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        );
      case 'mountains':
        return Positioned.fill(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              height: 70,
              width: double.infinity,
              child: CustomPaint(
                painter: _MountPainter(color.withOpacity(0.2)),
              ),
            ),
          ),
        );
      case 'grid':
      case 'sunset':
        return Positioned(
          left: -8,
          top: 10,
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: color.withOpacity(0.26),
              shape: BoxShape.circle,
            ),
          ),
        );
      case 'aurora':
        return Positioned(
          left: -10,
          right: -10,
          top: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.30),
                  const Color(0xFF6D83FF).withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      case 'city_text':
      case 'brand_text':
        return Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.42),
                  const Color(0xFF201A2D).withOpacity(0.44),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      case 'orbit':
      default:
        return Positioned(
          left: -18,
          top: 24,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
          ),
        );
    }
  }

  bool _showTrackForIcon(IconData iconData) {
    return true;
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
}


class _MountPainter extends CustomPainter {
  final Color color;
  _MountPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.22, size.height * 0.4)
      ..lineTo(size.width * 0.4, size.height)
      ..close();
    final path2 = Path()
      ..moveTo(size.width * 0.28, size.height)
      ..lineTo(size.width * 0.55, size.height * 0.28)
      ..lineTo(size.width * 0.84, size.height)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawPath(path2, p);
  }

  @override
  bool shouldRepaint(covariant _MountPainter oldDelegate) => oldDelegate.color != color;
}

class _CityTripField extends StatelessWidget {
  const _CityTripField({
    required this.controller,
    required this.label,
    this.isRequired = false,
    this.icon = Icons.location_on_outlined,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final bool isRequired;
  final IconData icon;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: 52,
        maxHeight: maxLines > 1 ? 132 : 52,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFFD7E37A),
            size: 20,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              minLines: minLines,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                label: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(
                          fontFamily: 'Geologica',
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRequired)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            color: Color(0xFFD7E37A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                hintText: hintText,
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

class _TripField extends StatelessWidget {
  const _TripField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isRequired = false,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hintText;
  final IconData icon;
  final bool isRequired;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return _CityTripField(
      controller: controller,
      focusNode: focusNode,
      label: label,
      hintText: hintText,
      icon: icon,
      isRequired: isRequired,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.onTap,
    this.isRequired = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFFD7E37A),
              size: 20,
            ),
            const SizedBox(width: 26),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isRequired)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          fontFamily: 'Geologica',
                          color: Color(0xFFD7E37A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF222715)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFD7E37A).withOpacity(0.75)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Geologica',
            color: selected
                ? const Color(0xFFD7E37A)
                : Colors.white.withOpacity(0.86),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
