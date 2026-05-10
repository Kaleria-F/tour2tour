import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:go_router/go_router.dart';

import 'package:record/record.dart';

import 'trips_repo.dart';

class AddStagePayload {
  final String stageType;
  final String subtype;
  final String title;
  final String? startLocation;
  final String? endLocation;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final double? costRub;
  final String? referenceNumber;
  final String? notes;
  final String? websiteUrl;
  final double? rating;
  final String? documentKey;

  AddStagePayload({
    required this.stageType,
    required this.subtype,
    required this.title,
    this.startLocation,
    this.endLocation,
    this.address,
    this.latitude,
    this.longitude,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.costRub,
    this.referenceNumber,
    this.notes,
    this.websiteUrl,
    this.rating,
    this.documentKey,
  });
}

class StageTypePickerPage extends StatelessWidget {
  final Map<String, String> stageTypeLabels;

  const StageTypePickerPage({super.key, required this.stageTypeLabels});

  IconData _icon(String type) {
    switch (type) {
      case 'transport':
        return Icons.directions_transit_rounded;
      case 'place':
        return Icons.place_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'activity':
        return Icons.directions_run_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const _NightBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Logo(cs: cs),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Выберите тип этапа',
                              style: TextStyle(
                                fontFamily: 'Geologica',
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: stageTypeLabels.entries.map((entry) {
                            return InkWell(
                              onTap: () => Navigator.of(context).pop(entry.key),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withOpacity(0.08),
                                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(_icon(entry.key), color: cs.primary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      entry.value,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StageFormPage extends StatefulWidget {
  final Map<String, String> stageTypeLabels;
  final Map<String, List<String>> stageSubtypes;
  final String initialType;
  final String? destinationCity;
  final TripsRepo tripsRepo;
  final bool isPremium;
  final DateTime? routeDay;
  final AddStagePayload? initial;
  final String submitLabel;
  final Future<String?> Function()? onUploadDocument;

  const StageFormPage({
    super.key,
    required this.stageTypeLabels,
    required this.stageSubtypes,
    required this.initialType,
    this.destinationCity,
    required this.tripsRepo,
    required this.isPremium,
    this.routeDay,
    this.onUploadDocument,
    this.initial,
    this.submitLabel = 'Добавить',
  });

  @override
  State<StageFormPage> createState() => _StageFormPageState();
}

class _StageFormPageState extends State<StageFormPage> {
  static const String _yandexSuggestApiKey = 'e0dc35bf-6cce-44bf-a462-8f7bab2f8b92';
  static const String _yandexGeocoderApiKey = 'acf6e354-8f9c-4163-9d37-54bf33ee956b';
  static final RegExp _moneyInputPattern = RegExp(r'^\d*([.,]\d{0,2})?$');
  static const int _assistantTrialLimit = 5;
  static const Map<String, String> _subtypeLabels = <String, String>{
    'road': 'Дорога',
    'airplane': 'Самолет',
    'train': 'Поезд',
    'car': 'Автомобиль',
    'bus': 'Автобус',
    'public_transport': 'Общественный транспорт',
    'walk': 'Пешком',
    'taxi': 'Такси',
    'bicycle': 'Велосипед',
    'attraction': 'Достопримечательность',
    'excursion': 'Экскурсия',
    'museum': 'Музей',
    'park': 'Парк',
    'event': 'Мероприятие',
    'nature': 'Природный объект',
    'hotel': 'Отель',
    'hostel': 'Хостел',
    'apartment': 'Апартаменты',
    'overnight': 'Ночевка',
    'rest': 'Сон / отдых',
    'restaurant': 'Ресторан',
    'cafe': 'Кафе',
    'fastfood': 'Фастфуд',
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'to_go': 'Взять с собой',
    'mall': 'Торговый центр',
    'market': 'Рынок',
    'souvenirs': 'Сувениры',
    'shopping': 'Покупки',
    'sport': 'Спорт',
    'entertainment': 'Развлечения',
    'beach': 'Пляж',
    'tickets': 'Билеты',
    'visa': 'Виза',
    'insurance': 'Страховка',
    'booking': 'Бронь',
  };

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _startLocationCtrl = TextEditingController();
  final _endLocationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _assistantCtrl = TextEditingController();
  final _assistantFocusNode = FocusNode();
  final _notesCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final Dio _orgSuggestDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSub;
  Timer? _recordTimer;
  final List<int> _recordedAudioBytes = <int>[];
  bool _uploadingStageDocument = false;
  bool _processingAssistant = false;
  bool _recordingVoice = false;
  bool _loadingAssistantTrial = true;
  bool _titleEdited = false;
  String _transportTimeMode = 'duration';
  int _recordSecondsLeft = 30;
  int _assistantTrialUsed = 0;
  bool _assistantLimitPopupShown = false;
  Timer? _orgSuggestDebounce;
  Timer? _orgSuggestHideOnBlurTimer;
  bool _orgSuggestLoading = false;
  String _lastOrgSuggestQuery = '';
  List<_OrgSuggestItem> _orgSuggestions = const [];
  bool _titleSelectAllOnNextTap = false;
  String? _orgSuggestBbox;
  bool _orgSuggestEnabled = true;
  bool _isPickingOrgSuggestion = false;

  late String _stageType;
  late String _subtype;

  @override
  void initState() {
    super.initState();
    _assistantFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAssistantTrialState();
    _stageType = widget.initial?.stageType ?? widget.initialType;
    _subtype = widget.initial?.subtype ??
        (_stageType == 'transport'
            ? 'road'
            : (widget.stageSubtypes[_stageType]?.first ?? ''));
    final initial = widget.initial;
    if (initial != null) {
      _transportTimeMode = initial.endTime != null ? 'range' : 'duration';
      _titleCtrl.text = initial.title;
      _startLocationCtrl.text = initial.startLocation ?? '';
      _endLocationCtrl.text = initial.endLocation ?? '';
      _addressCtrl.text = initial.address ?? '';
      _latCtrl.text = initial.latitude?.toString() ?? '';
      _lngCtrl.text = initial.longitude?.toString() ?? '';
      _durationCtrl.text = initial.durationMinutes?.toString() ?? '';
      _costCtrl.text = initial.costRub?.toString() ?? '';
      _refCtrl.text = initial.referenceNumber ?? '';
      _notesCtrl.text = initial.notes ?? '';
      _websiteCtrl.text = initial.websiteUrl ?? '';
      _ratingCtrl.text = initial.rating?.toString() ?? '';
      _docCtrl.text = initial.documentKey ?? '';
      _startTimeCtrl.text = _formatTimeOnly(initial.startTime);
      _endTimeCtrl.text = _formatTimeOnly(initial.endTime);
      _titleEdited = initial.title.trim().isNotEmpty;
    } else {
      _transportTimeMode = 'duration';
      _durationCtrl.text = '60';
      _applyTransportDefaultsIfNeeded(forceTitle: true);
    }
    _titleCtrl.addListener(_onOrgSuggestTitleChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _resolveOrgSuggestBounds();
  }

  @override
  void dispose() {
    _orgSuggestDebounce?.cancel();
    _orgSuggestHideOnBlurTimer?.cancel();
    _orgSuggestDio.close(force: true);
    _titleCtrl.removeListener(_onOrgSuggestTitleChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _recordTimer?.cancel();
    _audioStreamSub?.cancel();
    _audioRecorder.dispose();
    _titleCtrl.dispose();
    _titleFocusNode.dispose();
    _startLocationCtrl.dispose();
    _endLocationCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _durationCtrl.dispose();
    _costCtrl.dispose();
    _refCtrl.dispose();
    _assistantCtrl.dispose();
    _assistantFocusNode.dispose();
    _notesCtrl.dispose();
    _websiteCtrl.dispose();
    _ratingCtrl.dispose();
    _docCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  void _onOrgSuggestTitleChanged() {
    if (!_titleFocusNode.hasFocus || !_orgSuggestEnabled) {
      if (_orgSuggestions.isNotEmpty || _orgSuggestLoading) {
        setState(() {
          _orgSuggestions = const [];
          _orgSuggestLoading = false;
        });
      }
      return;
    }
    if (_stageType == 'transport') {
      if (_orgSuggestions.isNotEmpty || _orgSuggestLoading) {
        setState(() {
          _orgSuggestions = const [];
          _orgSuggestLoading = false;
        });
      }
      return;
    }
    final query = _titleCtrl.text.trim();
    _orgSuggestDebounce?.cancel();
    _orgSuggestDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadOrgSuggestions(query);
    });
  }

  void _onTitleFocusChanged() {
    if (_titleFocusNode.hasFocus) {
      _orgSuggestHideOnBlurTimer?.cancel();
      _orgSuggestEnabled = true;
      final query = _titleCtrl.text.trim();
      if (query.length >= 2) {
        _orgSuggestDebounce?.cancel();
        _orgSuggestDebounce = Timer(
          const Duration(milliseconds: 120),
          () => _loadOrgSuggestions(query),
        );
      }
      return;
    }
    _orgSuggestHideOnBlurTimer?.cancel();
    _orgSuggestHideOnBlurTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_titleFocusNode.hasFocus) return;
      if (_orgSuggestions.isNotEmpty || _orgSuggestLoading) {
        setState(() {
          _orgSuggestions = const [];
          _orgSuggestLoading = false;
        });
      }
    });
  }

  Future<void> _loadOrgSuggestions(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      if (!mounted) return;
      setState(() {
        _orgSuggestions = const [];
        _orgSuggestLoading = false;
        _lastOrgSuggestQuery = '';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _orgSuggestLoading = true;
      _lastOrgSuggestQuery = normalized;
    });

    try {
      final response = await _orgSuggestDio.get(
        'https://suggest-maps.yandex.ru/v1/suggest',
        queryParameters: <String, dynamic>{
          'apikey': _yandexSuggestApiKey,
          'text': normalized,
          'lang': 'ru_RU',
          'results': 4,
          'types': 'biz',
          'print_address': 1,
          if ((_orgSuggestBbox ?? '').isNotEmpty) 'bbox': _orgSuggestBbox,
          if ((_orgSuggestBbox ?? '').isNotEmpty) 'strict_bounds': 1,
        },
      );

      final data = response.data;
      final results = (data is Map<String, dynamic> ? data['results'] : null);
      final parsed = <_OrgSuggestItem>[];
      if (results is List) {
        for (final raw in results) {
          if (raw is! Map) continue;
          final map = raw.cast<dynamic, dynamic>();
          String title = '';
          String subtitle = '';

          final titleRaw = map['title'];
          if (titleRaw is Map && titleRaw['text'] != null) {
            title = '${titleRaw['text']}';
          } else if (titleRaw != null) {
            title = '$titleRaw';
          }

          final subtitleRaw = map['subtitle'];
          if (subtitleRaw is Map && subtitleRaw['text'] != null) {
            subtitle = '${subtitleRaw['text']}';
          } else if (subtitleRaw != null) {
            subtitle = '$subtitleRaw';
          }

          title = _normalizeSuggestText(title);
          subtitle = _ensureAddressHasTripCity(_normalizeSuggestText(subtitle));
          if (title.isEmpty && subtitle.isEmpty) continue;
          parsed.add(_OrgSuggestItem(title: title, subtitle: subtitle));
          if (parsed.length >= 4) break;
        }
      }

      if (!mounted || _lastOrgSuggestQuery != normalized) return;
      setState(() {
        _orgSuggestions = parsed;
        _orgSuggestLoading = false;
      });
    } catch (_) {
      if (!mounted || _lastOrgSuggestQuery != normalized) return;
      setState(() {
        _orgSuggestions = const [];
        _orgSuggestLoading = false;
      });
    }
  }

  String _normalizeSuggestText(String input) {
    return input
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '')
        .replaceAll('\u202A', '')
        .replaceAll('\u202B', '')
        .replaceAll('\u202C', '')
        .replaceAll('\u202D', '')
        .replaceAll('\u202E', '')
        .replaceAll('\u2066', '')
        .replaceAll('\u2067', '')
        .replaceAll('\u2068', '')
        .replaceAll('\u2069', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _addressFromSubtitle(String subtitle) {
    final clean = _normalizeSuggestText(subtitle);
    final withCity = _ensureAddressHasTripCity(clean);
    if (clean.contains('В·')) {
      final parts = clean.split('В·').map((e) => _normalizeSuggestText(e)).toList();
      if (parts.isNotEmpty) {
        final tail = parts.last;
        if (tail.isNotEmpty) return _ensureAddressHasTripCity(tail);
      }
    }
    return withCity;
  }

  String _ensureAddressHasTripCity(String rawAddress) {
    final address = _normalizeSuggestText(rawAddress);
    final tripCity = _normalizeSuggestText(widget.destinationCity ?? '');
    if (address.isEmpty || tripCity.isEmpty) return address;

    final lowerAddress = address.toLowerCase();
    final lowerCity = tripCity.toLowerCase();
    if (lowerAddress.contains(lowerCity)) return address;

    if (address.endsWith(',')) {
      return '$address $tripCity';
    }
    return '$address, $tripCity';
  }

  void _onOrgSuggestionTap(_OrgSuggestItem item) {
    _isPickingOrgSuggestion = true;
    _orgSuggestDebounce?.cancel();
    _applyOrgSuggestion(item);
    _titleFocusNode.unfocus();
    _isPickingOrgSuggestion = false;
  }

  void _applyOrgSuggestion(_OrgSuggestItem item) {
    final orgName = _normalizeSuggestText(item.title);
    final addr = _addressFromSubtitle(item.subtitle);
    _titleCtrl.text = orgName;
    _titleCtrl.selection = TextSelection.collapsed(offset: orgName.length);
    _addressCtrl.text = addr;
    _addressCtrl.selection = TextSelection.collapsed(offset: addr.length);
    setState(() {
      _orgSuggestions = const [];
      _orgSuggestLoading = false;
      _orgSuggestEnabled = false;
      _titleEdited = orgName.isNotEmpty;
    });
  }

  Future<void> _resolveOrgSuggestBounds() async {
    final city = (widget.destinationCity ?? '').trim();
    if (city.isEmpty) return;
    try {
      final response = await _orgSuggestDio.get(
        'https://geocode-maps.yandex.ru/v1/',
        queryParameters: <String, dynamic>{
          'apikey': _yandexGeocoderApiKey,
          'geocode': city,
          'format': 'json',
          'results': 1,
          'lang': 'ru_RU',
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return;
      final members = (((data['response'] as Map?)?['GeoObjectCollection'] as Map?)
              ?['featureMember'])
          as List?;
      if (members == null || members.isEmpty) return;
      final geoObject = ((members.first as Map?)?['GeoObject']) as Map?;
      final envelope = (((geoObject?['boundedBy'] as Map?)?['Envelope']) as Map?);
      final lowerCorner = _normalizeSuggestText('${envelope?['lowerCorner'] ?? ''}');
      final upperCorner = _normalizeSuggestText('${envelope?['upperCorner'] ?? ''}');
      if (lowerCorner.isEmpty || upperCorner.isEmpty) return;
      final lower = lowerCorner.split(' ');
      final upper = upperCorner.split(' ');
      if (lower.length != 2 || upper.length != 2) return;
      if (!mounted) return;
      setState(() {
        _orgSuggestBbox = '${lower[0]},${lower[1]}~${upper[0]},${upper[1]}';
      });
    } catch (_) {
      // Fallback: suggest without area bounds.
    }
  }
  String _formatTimeOnly(DateTime? date) {
    if (date == null) return '';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime? _parseTime(String raw, DateTime? fallbackDate) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    final base = fallbackDate ?? widget.routeDay ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  String _prettySubtype(String subtype) {
    return _subtypeLabels[subtype] ?? subtype;
  }

  String _defaultStageTitle() {
    if (_subtype.trim().isEmpty) {
      return '';
    }
    if (_stageType == 'transport' && _subtype == 'road') {
      return 'Дорога';
    }
    return _prettySubtype(_subtype);
  }

  String _startTimeLabel() {
    return _stageType == 'transport' ? 'Время отправления' : 'Время начала';
  }

  String _endTimeLabel() {
    return _stageType == 'transport' ? 'Время прибытия' : 'Время окончания';
  }

  DateTime _defaultCalendarDateTime() {
    final now = DateTime.now();
    final base = widget.routeDay ?? widget.initial?.startTime ?? now;
    return DateTime(base.year, base.month, base.day, now.hour, now.minute);
  }

  void _applyTransportDefaultsIfNeeded({bool forceTitle = false}) {
    final autoTitle = _defaultStageTitle();
    if (autoTitle.isNotEmpty &&
        (forceTitle || !_titleEdited || _titleCtrl.text.trim().isEmpty)) {
      _titleCtrl.text = autoTitle;
      _titleSelectAllOnNextTap = true;
    }
    if (_durationCtrl.text.trim().isEmpty) {
      _durationCtrl.text = '60';
    }
  }

  void _handleTitleTap() {
    if (!_titleSelectAllOnNextTap) return;
    final text = _titleCtrl.text;
    if (text.isEmpty) return;
    _titleCtrl.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    _titleSelectAllOnNextTap = false;
  }

  bool get _assistantHasText => _assistantCtrl.text.trim().isNotEmpty;
  int get _assistantTrialsLeft => (_assistantTrialLimit - _assistantTrialUsed)
      .clamp(0, _assistantTrialLimit)
      .toInt();
  bool get _assistantLocked =>
      !widget.isPremium && !_loadingAssistantTrial && _assistantTrialsLeft <= 0;

  void _applyAssistantTrialStatus(StageAssistantTrialStatus status) {
    _assistantTrialUsed = status.used.clamp(0, _assistantTrialLimit).toInt();
    _loadingAssistantTrial = false;
  }

  Future<void> _loadAssistantTrialState() async {
    if (widget.isPremium) {
      if (!mounted) return;
      setState(() => _loadingAssistantTrial = false);
      return;
    }
    try {
      final status = await widget.tripsRepo.getStageAssistantTrialStatus();
      if (!mounted) return;
      setState(() {
        _applyAssistantTrialStatus(status);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAssistantTrial = false);
    }
  }

  Future<void> _consumeAssistantTrial() async {
    if (widget.isPremium) return;
    try {
      final status = await widget.tripsRepo.consumeStageAssistantTrial();
      if (!mounted) return;
      setState(() {
        _applyAssistantTrialStatus(status);
      });
    } catch (_) {}
  }

  Future<void> _showAssistantPremiumPopup() async {
    if (!mounted || _assistantLimitPopupShown) return;
    _assistantLimitPopupShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF1D1D1D),
            border: Border.all(
              color: const Color(0xFFB6A1FF).withOpacity(0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB6A1FF).withOpacity(0.18),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB6A1FF).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFB6A1FF).withOpacity(0.38),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFB6A1FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Пробные запросы закончились',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white.withOpacity(0.96),
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Откройте Тур2Тур Pro, чтобы продолжить быстрый ввод этапов голосом и текстом без ограничений.',
                style: TextStyle(
                  fontFamily: 'Geologica',
                  color: Colors.white.withOpacity(0.74),
                  fontSize: 13,
                  height: 1.42,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              _buildPremiumAssistantPreview(),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: _PremiumFeatureChip(
                      icon: Icons.mic_rounded,
                      label: 'Голосовой ввод',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _PremiumFeatureChip(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Автозаполнение',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _PremiumFeatureChip(
                icon: Icons.edit_note_rounded,
                label: 'Свободные заметки',
                fullWidth: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Немного позже'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB6A1FF),
                        foregroundColor: const Color(0xFF17131F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.push('/premium');
                      },
                      child: const Text('Перейти на Pro'),
                    ),
                  ),
                ],
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
    _assistantLimitPopupShown = false;
  }

  Widget _buildPremiumAssistantPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            const Color(0xFFB6A1FF).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFB6A1FF).withOpacity(0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB6A1FF).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9D7BFF),
                Color(0xFFB6A1FF),
              ],
            ).createShader(bounds),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'быстрый ввод',
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Colors.white.withOpacity(0.66),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB6A1FF).withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFB6A1FF).withOpacity(0.34),
              ),
            ),
            child: const Text(
              'Pro активен',
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Color(0xFFD8CCFF),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyAssistantDraft(StageAssistantDraft draft) {
    setState(() {
      _stageType = draft.stageType;
      final allowedSubtypes = widget.stageSubtypes[_stageType] ?? const <String>[];
      if (allowedSubtypes.contains(draft.subtype)) {
        _subtype = draft.subtype;
      } else if (_stageType == 'transport' && allowedSubtypes.contains('road')) {
        _subtype = 'road';
      } else if (allowedSubtypes.isNotEmpty) {
        _subtype = allowedSubtypes.first;
      }
      final assistantTitle = draft.title.trim();
      final hadEditableTitle = !_titleEdited || _titleCtrl.text.trim().isEmpty;
      if (hadEditableTitle) {
        _titleCtrl.text = assistantTitle.isEmpty ? _defaultStageTitle() : assistantTitle;
      }
      if (draft.startLocation != null && draft.startLocation!.trim().isNotEmpty) {
        _startLocationCtrl.text = draft.startLocation!.trim();
      }
      if (draft.endLocation != null && draft.endLocation!.trim().isNotEmpty) {
        _endLocationCtrl.text = draft.endLocation!.trim();
      }
      if (draft.address != null && draft.address!.trim().isNotEmpty) {
        _addressCtrl.text = draft.address!.trim();
      }
      if (draft.costRub != null) {
        _costCtrl.text = draft.costRub!.toStringAsFixed(
          draft.costRub!.truncateToDouble() == draft.costRub ? 0 : 2,
        );
      }
      if (draft.notes != null && draft.notes!.trim().isNotEmpty) {
        _notesCtrl.text = draft.notes!.trim();
      }
      if (draft.startTimeText != null) {
        _startTimeCtrl.text = draft.startTimeText!;
      }
      if (draft.endTimeText != null) {
        _endTimeCtrl.text = draft.endTimeText!;
      }
      if (draft.durationMinutes != null && draft.durationMinutes! > 0) {
        _durationCtrl.text = draft.durationMinutes!.toString();
      } else if (_durationCtrl.text.trim().isEmpty) {
        _durationCtrl.text = '60';
      }
      _transportTimeMode = draft.timeMode == 'range' ? 'range' : 'duration';
      _assistantCtrl.text = draft.sourceText;
      if (assistantTitle.isNotEmpty && hadEditableTitle) {
        _titleEdited = assistantTitle != _defaultStageTitle();
      } else {
        _applyTransportDefaultsIfNeeded(
          forceTitle: !_titleEdited || _titleCtrl.text.trim().isEmpty,
        );
      }
    });
  }

  Future<void> _fillFieldsFromAssistantText({String? sourceText}) async {
    final resolvedText = (sourceText ?? _assistantCtrl.text).trim();
    if (resolvedText.isEmpty || _processingAssistant) return;
    if (_assistantLocked) {
      await _showAssistantPremiumPopup();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _processingAssistant = true);
    try {
      await _consumeAssistantTrial();
      final draft = await widget.tripsRepo.createStageDraftFromText(
        stageType: _stageType,
        text: resolvedText,
        routeDay: widget.routeDay,
      );
      if (!mounted) return;
      if (draft == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обработать описание этапа')),
        );
        return;
      }
      _applyAssistantDraft(draft);
      if (_assistantLocked) {
        await _showAssistantPremiumPopup();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обработать описание этапа')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingAssistant = false);
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_assistantLocked) {
      await _showAssistantPremiumPopup();
      return;
    }
    if (_processingAssistant || _recordingVoice || _assistantHasText) return;
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужен доступ к микрофону')),
      );
      return;
    }
    _recordTimer?.cancel();
    await _audioStreamSub?.cancel();
    _recordedAudioBytes.clear();
    try {
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _audioStreamSub = stream.listen((chunk) {
        _recordedAudioBytes.addAll(chunk);
      });
      if (!mounted) return;
      setState(() {
        _recordingVoice = true;
        _recordSecondsLeft = 30;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted || !_recordingVoice) {
          timer.cancel();
          return;
        }
        if (_recordSecondsLeft <= 1) {
          timer.cancel();
          await _stopVoiceRecordingAndProcess();
          return;
        }
        setState(() => _recordSecondsLeft -= 1);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось начать запись')),
      );
    }
  }

  Future<void> _stopVoiceRecordingIfNeeded() async {
    if (!_recordingVoice) return;
    await _stopVoiceRecordingAndProcess();
  }

  Future<void> _stopVoiceRecordingAndProcess() async {
    if (!_recordingVoice && _recordedAudioBytes.isEmpty) return;
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    if (!mounted) return;
    setState(() {
      _recordingVoice = false;
      _processingAssistant = true;
    });
    if (_recordedAudioBytes.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recordSecondsLeft = 30;
        _processingAssistant = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Голосовое не записалось')),
      );
      return;
    }
    try {
      final transcript = await widget.tripsRepo.transcribeStageAudio(
        audioBytes: Uint8List.fromList(_recordedAudioBytes),
      );
      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось распознать голосовое')),
        );
        return;
      }
      final recognizedText = transcript.trim();
      _assistantCtrl.text = recognizedText;
      setState(() {
        _recordSecondsLeft = 30;
        _recordingVoice = false;
        _processingAssistant = false;
      });
      await _fillFieldsFromAssistantText(sourceText: recognizedText);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось распознать голосовое')),
      );
    } finally {
      _recordedAudioBytes.clear();
      if (mounted) {
        setState(() {
          _recordSecondsLeft = 30;
          _recordingVoice = false;
          _processingAssistant = false;
        });
      }
    }
  }

  Widget _buildAssistantComposer() {
    final hasText = _assistantHasText;
    final progress = ((30 - _recordSecondsLeft) / 30).clamp(0.0, 1.0);
    final composerHeight = 48.0;
    final showHint = !hasText && !_assistantFocusNode.hasFocus;
    final accentColor = const Color(0xFFB6A1FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isPremium && !_loadingAssistantTrial)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              _assistantLocked
                  ? 'Пробные запросы закончились'
                  : 'Осталось $_assistantTrialsLeft из $_assistantTrialLimit пробных запросов',
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Colors.white.withOpacity(0.60),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _recordingVoice
                      ? accentColor.withOpacity(0.65)
                      : Colors.white.withOpacity(0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                height: composerHeight,
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        key: const ValueKey('assistant-prefix'),
                        margin: const EdgeInsets.only(right: 6),
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              colors: [Color(0xFFD87DFF), Color(0xFF9A7CFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: TextField(
                          controller: _assistantCtrl,
                          focusNode: _assistantFocusNode,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontFamily: 'Geologica',
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                          ),
                          minLines: 1,
                          maxLines: 1,
                          decoration: InputDecoration.collapsed(
                            hintText: showHint ? 'быстрый ввод' : '',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.52),
                              fontSize: 11,
                              fontFamily: 'Geologica',
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: hasText
                          ? Container(
                              key: const ValueKey('assistant-send'),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _processingAssistant
                                    ? null
                                    : _fillFieldsFromAssistantText,
                                icon: _processingAssistant
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            )
                          : (kIsWeb
                              ? Listener(
                                  key: const ValueKey('assistant-mic'),
                                  onPointerDown: (_) => _startVoiceRecording(),
                                  onPointerUp: (_) => _stopVoiceRecordingIfNeeded(),
                                  onPointerCancel: (_) => _stopVoiceRecordingIfNeeded(),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 120),
                                    scale: _recordingVoice ? 1.12 : 1,
                                    child: SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 46,
                                            height: 46,
                                            child: CircularProgressIndicator(
                                              value: _recordingVoice ? progress : 0,
                                              strokeWidth: 3,
                                              backgroundColor:
                                                  Colors.white.withOpacity(0.12),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<Color>(
                                                Color(0xFFB6A1FF),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accentColor.withOpacity(0.30),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Icon(
                                                  _recordingVoice
                                                      ? Icons.graphic_eq_rounded
                                                      : Icons.mic_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                if (_recordingVoice)
                                                  Positioned(
                                                    bottom: 2,
                                                    child: Text(
                                                      '$_recordSecondsLeft',
                                                      style: const TextStyle(
                                                        fontFamily: 'Geologica',
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w300,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  key: const ValueKey('assistant-mic'),
                                  onLongPressStart: (_) => _startVoiceRecording(),
                                  onLongPressEnd: (_) => _stopVoiceRecordingIfNeeded(),
                                  onLongPressCancel: _stopVoiceRecordingIfNeeded,
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 120),
                                    scale: _recordingVoice ? 1.12 : 1,
                                    child: SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 46,
                                            height: 46,
                                            child: CircularProgressIndicator(
                                              value: _recordingVoice ? progress : 0,
                                              strokeWidth: 3,
                                              backgroundColor:
                                                  Colors.white.withOpacity(0.12),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<Color>(
                                                Color(0xFFB6A1FF),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accentColor.withOpacity(0.30),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Icon(
                                                  _recordingVoice
                                                      ? Icons.graphic_eq_rounded
                                                      : Icons.mic_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                if (_recordingVoice)
                                                  Positioned(
                                                    bottom: 2,
                                                    child: Text(
                                                      '$_recordSecondsLeft',
                                                      style: const TextStyle(
                                                        fontFamily: 'Geologica',
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w300,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )),
                    ),
                  ],
                ),
              ),
            ),
            if (_assistantLocked)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _showAssistantPremiumPopup,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCC7B7B7B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFB6A1FF),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Pro',
                            style: TextStyle(
                              fontFamily: 'Geologica',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'transport':
        return Icons.directions_transit_rounded;
      case 'place':
        return Icons.place_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'activity':
        return Icons.directions_run_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  Future<void> _pickTime(
    TextEditingController controller, {
    TextEditingController? nextController,
  }) async {
    final current = _parseTime(controller.text, widget.routeDay);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current?.hour ?? 12, minute: current?.minute ?? 0),
                          helpText: 'Выберите время',
                          cancelText: 'Отмена',
                          confirmText: 'ОК',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFD7E37A),
                onPrimary: Color(0xFF161616),
                surface: Color(0xFF1D1D1D),
                onSurface: Colors.white,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: const Color(0xFF1D1D1D),
                hourMinuteColor: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF222715);
                  }
                  return const Color(0xFF2B2B2B);
                }),
                hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFD7E37A);
                  }
                  return Colors.white;
                }),
                dayPeriodColor: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF222715);
                  }
                  return const Color(0xFF2B2B2B);
                }),
                dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFD7E37A);
                  }
                  return Colors.white;
                }),
                dialBackgroundColor: const Color(0xFF2B2B2B),
                dialHandColor: const Color(0xFFD7E37A),
                dialTextColor: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF161616);
                  }
                  return Colors.white;
                }),
                entryModeIconColor: const Color(0xFFD7E37A),
                helpTextStyle: const TextStyle(
                  fontFamily: 'Geologica',
                  color: Color(0xFFAEB7A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
                hourMinuteTextStyle: const TextStyle(
                  fontFamily: 'Geologica',
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD7E37A),
                ),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {});
    if (nextController != null) {
      await _pickTime(nextController);
    }
  }

  void _applyQuickTime(
    TextEditingController controller,
    int hour,
    int minute,
  ) {
    controller.text =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Widget _quickTimeChip(
    String label,
    TextEditingController controller,
    int hour,
    int minute,
  ) {
    final value = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final selected = controller.text.trim() == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: TextStyle(
        fontFamily: 'Geologica',
        color: selected ? const Color(0xFFD7E37A) : Colors.white,
        fontWeight: FontWeight.w300,
      ),
      backgroundColor: const Color(0xFF2B2B2B),
      selectedColor: const Color(0xFF222715),
      side: BorderSide(
        color: selected
            ? const Color(0xFFD7E37A).withOpacity(0.6)
            : Colors.white.withOpacity(0.24),
      ),
      onSelected: (_) => _applyQuickTime(controller, hour, minute),
    );
  }

  Widget _bubble(String title, List<Widget> children, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
        ],
      ),
    );
  }

  Widget _timeField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(
        controller,
        nextController: identical(controller, _startTimeCtrl) ? _endTimeCtrl : null,
      ),
      style: const TextStyle(
        fontFamily: 'Geologica',
        color: Colors.white,
        fontWeight: FontWeight.w300,
      ),
      decoration: InputDecoration(
        labelText: label,
                                  hintText: 'Выбрать',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              ),
            IconButton(
              icon: const Icon(Icons.access_time_rounded, color: Colors.white70),
              onPressed: () => _pickTime(
                controller,
                nextController: identical(controller, _startTimeCtrl) ? _endTimeCtrl : null,
              ),
            ),
          ],
        ),
      ),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (raw.isEmpty) return null;
                                      if (_parseTime(raw, null) == null) return 'Формат времени: HH:MM';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stageTypeItems = Map<String, String>.from(widget.stageTypeLabels);
    if (!stageTypeItems.containsKey(_stageType)) {
                                stageTypeItems[_stageType] = _stageType == 'document' ? 'Документ' : _stageType;
    }
    final subtypes = widget.stageSubtypes[_stageType] ?? const <String>[];
    final isTransport = _stageType == 'transport';
    final isPlace = _stageType == 'place';
    final isStay = _stageType == 'stay';
    final isFood = _stageType == 'food';
    final isShopping = _stageType == 'shopping';
    final isActivity = _stageType == 'activity';
    final isDocument = _stageType == 'document';
    if (!subtypes.contains(_subtype) && subtypes.isNotEmpty) {
      _subtype = isTransport && subtypes.contains('road') ? 'road' : subtypes.first;
    }

    return Scaffold(
      body: Stack(
        children: [
          const _NightBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Logo(cs: cs),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                    widget.submitLabel == 'Сохранить'
                                        ? 'Редактирование этапа'
                                        : 'Новый этап',
                              style: const TextStyle(
                                fontFamily: 'Geologica',
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: const TextSelectionThemeData(
                              cursorColor: Color(0xFFD7E37A),
                              selectionColor: Color(0x55D7E37A),
                              selectionHandleColor: Color(0xFFD7E37A),
                            ),
                            textTheme: Theme.of(context).textTheme.apply(
                              fontFamily: 'Geologica',
                              bodyColor: Colors.white,
                              displayColor: Colors.white,
                            ).copyWith(
                              bodyLarge: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                              bodyMedium: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                              bodySmall: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                              labelLarge: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                              labelMedium: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                              titleMedium: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w300,
                                  ),
                            ),
                            inputDecorationTheme: InputDecorationTheme(
                              labelStyle: TextStyle(
                                fontFamily: 'Geologica',
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              hintStyle: TextStyle(
                                fontFamily: 'Geologica',
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.55),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 8),
                              children: [
                                  _bubble('Быстрое создание', [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: widget.stageTypeLabels.entries.map((entry) {
                                      final selected = entry.key == _stageType;
                                      return ChoiceChip(
                                        selected: selected,
                                        label: Text(entry.value),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        avatar: Icon(
                                          _typeIcon(entry.key),
                                          size: 16,
                                          color: selected
                                              ? const Color(0xFFD7E37A)
                                              : Colors.white70,
                                        ),
                                        labelStyle: TextStyle(
                                          fontFamily: 'Geologica',
                                          color: selected
                                              ? const Color(0xFFD7E37A)
                                              : Colors.white,
                                          fontWeight: FontWeight.w300,
                                        ),
                                        backgroundColor: const Color(0xFF2B2B2B),
                                        selectedColor: const Color(0xFF222715),
                                        side: selected
                                            ? const BorderSide(
                                                color: Color(0xFFD7E37A),
                                                width: 1.4,
                                              )
                                            : BorderSide.none,
                                        onSelected: (_) {
                                          setState(() {
                                            _stageType = entry.key;
                                            _subtype = entry.key == 'transport'
                                                ? 'road'
                                                : (widget.stageSubtypes[entry.key]?.first ?? '');
                                            _transportTimeMode = 'duration';
                                            _applyTransportDefaultsIfNeeded(
                                              forceTitle: !_titleEdited ||
                                                  _titleCtrl.text.trim().isEmpty,
                                            );
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ], cs.primary),
                                _plainSection([
                                  _buildAssistantComposer(),
                                ]),
                                  _bubble('Основное', [
                                  TextFormField(
                                    controller: _titleCtrl,
                                    focusNode: _titleFocusNode,
                                    onTap: _handleTitleTap,
                                    onChanged: (value) {
                                      final normalized = value.trim();
                                      final autoTitle = _defaultStageTitle();
                                      _titleEdited = normalized.isNotEmpty && normalized != autoTitle;
                                      if (_titleEdited) {
                                        _titleSelectAllOnNextTap = false;
                                      }
                                    },
                                    style: const TextStyle(
                                      fontFamily: 'Geologica',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w300,
                                    ),
                                      decoration: const InputDecoration(labelText: 'Название'),
                                      validator: (v) =>
                                          (v ?? '').trim().isEmpty ? 'Введите название' : null,
                                  ),
                                  if (_stageType != 'transport' &&
                                      (_orgSuggestLoading || _orgSuggestions.isNotEmpty)) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                                      ),
                                      child: _orgSuggestLoading
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                  'Ищем организации...',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                for (final entry
                                                    in _orgSuggestions.asMap().entries) ...[
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onTapDown: (_) =>
                                                          _onOrgSuggestionTap(entry.value),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                        child: Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                entry.value.title,
                                                                textAlign: TextAlign.left,
                                                                textDirection: TextDirection.ltr,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(
                                                                  fontFamily: 'Geologica',
                                                                  color: Colors.white,
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w300,
                                                                ),
                                                              ),
                                                              if (entry.value
                                                                  .subtitle
                                                                  .trim()
                                                                  .isNotEmpty)
                                                                Text(
                                                                  entry.value.subtitle,
                                                                  textAlign: TextAlign.left,
                                                                  textDirection: TextDirection.ltr,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontFamily: 'Geologica',
                                                                    color: Colors.white
                                                                        .withOpacity(0.7),
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w300,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (entry.key < _orgSuggestions.length - 1)
                                                    Divider(
                                                      height: 1,
                                                      thickness: 1,
                                                      color: Colors.white.withOpacity(0.08),
                                                    ),
                                                ],
                                              ],
                                            ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  if (isTransport) ...[
                                    TextFormField(
                                      controller: _startLocationCtrl,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                          decoration: const InputDecoration(labelText: 'Откуда'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _endLocationCtrl,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                          decoration: const InputDecoration(labelText: 'Куда'),
                                    ),
                                  ] else ...[
                                    TextFormField(
                                      controller: _addressCtrl,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: isStay
                                          ? 'Адрес проживания'
                                            : isFood
                                              ? 'Место / адрес'
                                              : 'Адрес / место',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment<String>(
                                        value: 'duration',
                                            label: Text('Продолжительность'),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'range',
                                            label: Text('Промежуток'),
                                      ),
                                    ],
                                    selected: {_transportTimeMode},
                                    showSelectedIcon: false,
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return const Color(0xFF222715);
                                        }
                                        return const Color(0xFF2B2B2B);
                                      }),
                                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return const Color(0xFFD7E37A);
                                        }
                                        return Colors.white;
                                      }),
                                      side: WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return BorderSide(
                                            color: const Color(0xFFD7E37A).withOpacity(0.6),
                                          );
                                        }
                                        return BorderSide(
                                          color: Colors.white.withOpacity(0.24),
                                        );
                                      }),
                                    ),
                                    onSelectionChanged: (selection) {
                                      final nextMode = selection.first;
                                      setState(() {
                                        _transportTimeMode = nextMode;
                                        if (nextMode == 'duration' &&
                                            _durationCtrl.text.trim().isEmpty) {
                                          _durationCtrl.text = '60';
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  if (_transportTimeMode == 'duration') ...[
                                    _timeField(_startTimeLabel(), _startTimeCtrl),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _durationCtrl,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      decoration: const InputDecoration(
                                              labelText: 'Продолжительность, мин',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _timeField(
                                            _startTimeLabel(),
                                            _startTimeCtrl,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _timeField(
                                            _endTimeLabel(),
                                            _endTimeCtrl,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ], Colors.cyan),
                                const SizedBox(height: 2),
                                  _bubble('Детали', [
                                    if (subtypes.isNotEmpty) ...[
                                      DropdownButtonFormField<String>(
                                        value: (_subtype.isNotEmpty && subtypes.contains(_subtype))
                                            ? _subtype
                                            : null,
                                        style: const TextStyle(
                                          fontFamily: 'Geologica',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w300,
                                        ),
                                        dropdownColor: const Color(0xFF2B2B2B),
                                        iconEnabledColor: Colors.white70,
                                          decoration: const InputDecoration(labelText: 'Подтип'),
                                        items: subtypes
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  _prettySubtype(e),
                                                  style: const TextStyle(
                                                    fontFamily: 'Geologica',
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        selectedItemBuilder: (context) => subtypes
                                            .map(
                                              (e) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  _prettySubtype(e),
                                                  style: const TextStyle(
                                                    fontFamily: 'Geologica',
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _subtype = value;
                                            _applyTransportDefaultsIfNeeded(
                                              forceTitle: !_titleEdited ||
                                                  _titleCtrl.text.trim().isEmpty,
                                            );
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (!isDocument) ...[
                                      TextFormField(
                                        controller: _costCtrl,
                                        style: const TextStyle(
                                          fontFamily: 'Geologica',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w300,
                                        ),
                                        decoration: InputDecoration(
                                              labelText: isFood ? 'Сколько потрачу, руб' : 'Стоимость, руб',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(_moneyInputPattern),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (isTransport || isStay || isPlace || isDocument) ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFD7E37A),
                                            side: BorderSide(
                                              color: const Color(0xFFD7E37A).withOpacity(0.45),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            textStyle: const TextStyle(
                                              fontFamily: 'Geologica',
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                          onPressed: (_uploadingStageDocument ||
                                                  widget.onUploadDocument == null)
                                              ? null
                                              : () async {
                                                  setState(() => _uploadingStageDocument = true);
                                                  final objectKey =
                                                      await widget.onUploadDocument!.call();
                                                  if (!mounted) return;
                                                  if (objectKey != null &&
                                                      objectKey.isNotEmpty) {
                                                    _docCtrl.text = objectKey;
                                                  }
                                                  setState(() => _uploadingStageDocument = false);
                                                },
                                          icon: _uploadingStageDocument
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.upload_file_rounded),
                                          label: Text(
                                            _docCtrl.text.trim().isEmpty
                                                      ? 'Загрузить документ'
                                                      : 'Документ загружен',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    TextFormField(
                                      controller: _notesCtrl,
                                      style: const TextStyle(
                                        fontFamily: 'Geologica',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      decoration: const InputDecoration(labelText: 'Комментарий'),
                                      maxLines: 3,
                                    ),
                                ], Colors.greenAccent),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD7E37A),
                                      foregroundColor: const Color(0xFF171717),
                                    ),
                                    onPressed: () {
                                      if (!(_formKey.currentState?.validate() ?? false)) return;
                                      final resolvedSubtype = _stageType == 'transport'
                                          ? (_subtype.trim().isEmpty ? 'road' : _subtype.trim())
                                          : _subtype.trim();
                                      final fallbackTitle = _defaultStageTitle();
                                      final resolvedTitle = _titleCtrl.text.trim().isEmpty
                                          ? fallbackTitle
                                          : _titleCtrl.text.trim();
                                      final fallbackStart = _defaultCalendarDateTime();
                                      DateTime? resolvedStartTime = _parseTime(
                                        _startTimeCtrl.text,
                                        widget.initial?.startTime ?? fallbackStart,
                                      );
                                      DateTime? resolvedEndTime = _parseTime(
                                        _endTimeCtrl.text,
                                        widget.initial?.endTime ?? fallbackStart,
                                      );
                                      int? resolvedDurationMinutes = int.tryParse(
                                        _durationCtrl.text.trim(),
                                      );

                                      resolvedStartTime ??= fallbackStart;
                                      if (_transportTimeMode == 'duration') {
                                        resolvedDurationMinutes ??= 60;
                                        resolvedEndTime = null;
                                      } else {
                                        if (resolvedStartTime == null && resolvedEndTime == null) {
                                          resolvedStartTime = fallbackStart;
                                          resolvedEndTime =
                                              fallbackStart.add(const Duration(hours: 1));
                                        } else if (resolvedStartTime != null &&
                                            resolvedEndTime == null) {
                                          resolvedEndTime =
                                              resolvedStartTime.add(const Duration(hours: 1));
                                        } else if (resolvedStartTime == null &&
                                            resolvedEndTime != null) {
                                          resolvedStartTime =
                                              resolvedEndTime.subtract(const Duration(hours: 1));
                                        }
                                        resolvedDurationMinutes = null;
                                      }
                                      Navigator.of(context).pop(
                                        AddStagePayload(
                                          stageType: _stageType,
                                          subtype: resolvedSubtype,
                                          title: resolvedTitle,
                                          startLocation: _startLocationCtrl.text.trim().isEmpty
                                              ? null
                                              : _startLocationCtrl.text.trim(),
                                          endLocation: _endLocationCtrl.text.trim().isEmpty
                                              ? null
                                              : _endLocationCtrl.text.trim(),
                                          address: _addressCtrl.text.trim().isEmpty
                                              ? null
                                              : _addressCtrl.text.trim(),
                                          latitude: widget.initial?.latitude,
                                          longitude: widget.initial?.longitude,
                                          startTime: resolvedStartTime,
                                          endTime: resolvedEndTime,
                                          durationMinutes: resolvedDurationMinutes,
                                          costRub: double.tryParse(
                                            _costCtrl.text
                                                .trim()
                                                .replaceAll(' ', '')
                                                .replaceAll('\u00A0', '')
                                                .replaceAll(',', '.'),
                                          ),
                                          referenceNumber: null,
                                          notes: _notesCtrl.text.trim().isEmpty
                                              ? null
                                              : _notesCtrl.text.trim(),
                                          websiteUrl: null,
                                          rating: widget.initial?.rating,
                                          documentKey: _docCtrl.text.trim().isEmpty
                                              ? null
                                              : _docCtrl.text.trim(),
                                        ),
                                      );
                                    },
                                    child: Text(widget.submitLabel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainSection(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _OrgSuggestItem {
  final String title;
  final String subtitle;

  const _OrgSuggestItem({
    required this.title,
    required this.subtitle,
  });
}

class _Logo extends StatelessWidget {
  final ColorScheme cs;
  const _Logo({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF222715),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E37A).withOpacity(0.45)),
      ),
      child: const Icon(Icons.explore_rounded, color: Color(0xFFD7E37A), size: 28),
    );
  }
}

class _NightBackground extends StatelessWidget {
  const _NightBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NightPainter(),
      child: const SizedBox.expand(),
    );
  }
}


class _NightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF151515), Color(0xFF0F0F0F)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final vignette = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
      stops: const [0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = vignette.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumFeatureChip extends StatelessWidget {
  const _PremiumFeatureChip({
    required this.icon,
    required this.label,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFD7E37A);
    final child = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.06),
            accentColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Colors.white.withOpacity(0.88),
                fontSize: 12.5,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
    return child;
  }
}








