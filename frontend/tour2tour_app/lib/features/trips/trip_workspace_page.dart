import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../core/mapkit/mapkit_initializer.dart';
import '../../core/web_microphone_access.dart';
import '../documents/documents_repo.dart';
import '../favorites/favorites_page.dart';
import '../interactions/interactions_repo.dart';
import '../preferences/preferences_repo.dart';
import '../profile/profile_repo.dart';
import '../recommendations/recommendations_repo.dart';
import 'widgets/pdf_memory_preview.dart';
import 'widgets/yandex_city_map.dart';
import 'stage_form_page.dart';
import 'trip_recommendations_tab.dart';
import 'trips_repo.dart';

part 'trip_workspace_route_section.dart';
part 'trip_workspace_budget_section.dart';
part 'trip_workspace_documents_section.dart';

class TripWorkspacePage extends StatefulWidget {
  final String tripTitle;
  final int? tripId;
  final String? destinationCity;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? plannedDays;
  final String? cardColor;
  final String? cardBackground;
  final String? cardIcon;
  final TripsRepo tripsRepo;
  final DocumentsRepo documentsRepo;
  final PreferencesRepo preferencesRepo;
  final RecommendationsRepo recommendationsRepo;
  final InteractionsRepo interactionsRepo;
  final ProfileRepo profileRepo;

  const TripWorkspacePage({
    super.key,
    required this.tripTitle,
    required this.tripsRepo,
    required this.documentsRepo,
    required this.preferencesRepo,
    required this.recommendationsRepo,
    required this.interactionsRepo,
    required this.profileRepo,
    this.tripId,
    this.destinationCity,
    this.startDate,
    this.endDate,
    this.plannedDays,
    this.cardColor,
    this.cardBackground,
    this.cardIcon,
  });

  @override
  State<TripWorkspacePage> createState() => _TripWorkspacePageState();
}

class _TripWorkspacePageState extends State<TripWorkspacePage> {
  static const Color _popupBg = Color(0xFF1D222A);
  static const Color _popupBorder = Color(0xFF3A4751);
  static const Color _popupFieldBg = Color(0xFF2A2F36);
  static const Color _popupText = Color(0xFFF2F4F8);
  static const Color _popupSubtleText = Color(0xFFB7BDC8);
  static const Color _popupAccent = Color(0xFFD7E37A);

  static const _accent = Color(0xFFD7E37A);

  late String _tripTitle;
  late DateTime? _tripStartDate;
  late DateTime? _tripEndDate;
  late int? _tripPlannedDays;
  late String _tripCardColor;
  late String _tripCardBackground;
  late String _tripCardIcon;

  int _currentIndex = 1;
  bool _showTripFavorites = false;
  DateTime? _selectedRouteDay;

  bool _budgetLoading = false;
  bool _addingExpense = false;
  List<TripExpense> _expenses = const [];
  bool _showBudgetAnalytics = false;
  bool _stagesLoading = false;
  bool _addingStage = false;
  List<TripStage> _stages = const [];
  int? _selectedStageId;
  bool _suggestionsLoading = false;
  bool _addingSuggestedStage = false;
  List<StageSuggestion> _stageSuggestions = const [];
  final Set<String> _hiddenSuggestionKeys = <String>{};
  final AudioRecorder _routeAssistantRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _routeAssistantStreamSub;
  final List<int> _routeAssistantAudioBytes = <int>[];
  Timer? _routeAssistantTimer;
  Timer? _routeAssistantHoldTimer;
  bool _routeAssistantRecording = false;
  bool _routeAssistantProcessing = false;
  bool _routeAssistantPointerDown = false;
  int _routeAssistantSecondsLeft = 30;

  String _sortMode = 'none';
  String _categoryFilter = 'all';
  String _lastStageType = 'place';
  bool _hasPremium = false;

  List<TripDocument> _documents = const [];
  bool _documentsLoading = false;
  bool _uploadingDocument = false;

  static const _sectionTitles = [
    'Рекомендации',
    'Маршрут',
    'Бюджет',
    'Документы',
  ];

  static const _categories = {
    'food': 'Еда',
    'housing': 'Жилье',
    'transport': 'Транспорт',
    'shopping': 'Покупки',
    'entertainment': 'Развлечения',
    'other': 'Другое',
  };

  static const _categoryColors = {
    'food': Color(0xFFE37AA2), // #e37aa2
    'housing': Color(0xFFE3BA7A), // #e3ba7a
    'transport': Color(0xFF7AE3BA), // #7ae3ba
    'shopping': Color(0xFFA3E37A), // #a3e37a
    'entertainment': Color(0xFFB6A1FF), // #b6a1ff
    'other': Color(0xFF7AB4E3), // Р С–Р В°РЎР‚Р СР С•Р Р…Р С‘РЎвЂЎР Р…РЎвЂ№Р в„– 6-Р в„– (Р С–Р С•Р В»РЎС“Р В±Р С•Р в„–)
  };

  static const _stageTypeLabels = {
    'transport': 'Поездка',
    'place': 'Посещение места',
    'stay': 'Отдых / проживание',
    'food': 'Еда',
    'shopping': 'Шоппинг',
    'activity': 'Активность',
  };

  static const _stageSubtypes = {
    'transport': [
      'road',
      'airplane',
      'train',
      'car',
      'bus',
      'public_transport',
      'walk',
      'taxi',
      'bicycle',
    ],
    'place': ['attraction', 'excursion', 'museum', 'park', 'event', 'nature'],
    'stay': ['hotel', 'hostel', 'apartment', 'overnight', 'rest'],
    'food': [
      'restaurant',
      'cafe',
      'fastfood',
      'breakfast',
      'lunch',
      'dinner',
      'to_go',
    ],
    'shopping': ['mall', 'market', 'souvenirs', 'shopping'],
    'activity': ['sport', 'entertainment', 'walk', 'beach'],
  };

  @override
  void initState() {
    super.initState();
    _tripTitle = widget.tripTitle;
    _tripStartDate = widget.startDate;
    _tripEndDate = widget.endDate;
    _tripPlannedDays = widget.plannedDays;
    _tripCardColor = (widget.cardColor ?? '#D7E37A').trim();
    _tripCardBackground = (widget.cardBackground ?? 'brand_text').trim().toLowerCase();
    _tripCardIcon = (widget.cardIcon ?? 'luggage').trim().toLowerCase();
    _loadPremiumStatus();
    if (widget.tripId != null) {
      _loadExpenses();
      _loadStages();
    }
  }

  @override
  void dispose() {
    _routeAssistantHoldTimer?.cancel();
    _routeAssistantTimer?.cancel();
    _routeAssistantStreamSub?.cancel();
    _routeAssistantRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final me = await widget.profileRepo.getMe();
      if (!mounted) return;
      setState(() => _hasPremium = me.isPremium);
    } catch (_) {}
  }

  int _totalTripDays({
    required DateTime startDate,
    required DateTime endDate,
    required int? plannedDays,
  }) {
    if (plannedDays != null && plannedDays > 0) return plannedDays;
    return endDate.difference(startDate).inDays + 1;
  }

  Future<void> _openTripSettingsDialog() async {
    if (widget.tripId == null) return;
    final result = await showDialog<_TripSettingsResult>(
      context: context,
      builder: (_) => _TripSettingsDialog(
        initialTitle: _tripTitle,
        city: widget.destinationCity ?? '',
        initialStartDate: _tripStartDate,
        initialEndDate: _tripEndDate,
        initialPlannedDays: _tripPlannedDays,
        initialCardColor: _tripCardColor,
        initialCardBackground: _tripCardBackground,
        initialCardIcon: _tripCardIcon,
      ),
    );
    if (result == null) return;
    if (result.action == _TripSettingsAction.archive) {
      try {
        final updated = await widget.tripsRepo.updateTrip(
          tripId: widget.tripId!,
          isArchived: true,
        );
        if (!mounted) return;
        if (updated == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось перенести путешествие в архив')),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Путешествие перенесено в архив')),
        );
        context.go('/profile');
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось перенести путешествие в архив')),
        );
      }
      return;
    }
    if (result.action == _TripSettingsAction.delete) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1F24),
          title: const Text(
            'Удалить путешествие?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Путешествие и связанные с ним этапы/расходы будут удалены без возможности восстановления.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD7E37A)),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await widget.tripsRepo.deleteTrip(widget.tripId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Путешествие удалено')),
        );
        context.go('/profile');
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить путешествие')),
        );
      }
      return;
    }

    final currentStart = _tripStartDate ?? DateTime.now();
    final currentEnd = _tripEndDate ?? currentStart;
    final oldDays = _totalTripDays(
      startDate: currentStart,
      endDate: currentEnd,
      plannedDays: _tripPlannedDays,
    );
    final newDays = _totalTripDays(
      startDate: result.startDate,
      endDate: result.endDate,
      plannedDays: result.plannedDays,
    );

    var confirmTrim = false;
    if (newDays < oldDays) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF1E1F24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Подтвердите изменение',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Новый выбранный период меньше предыдущего. Если продолжить, последние дни, не входящие в новый период, будут удалены вместе с маршрутами и данными этих дней.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB16E4B),
                        ),
                        child: const Text('Отмена'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB16E4B),
                        ),
                        child: const Text('ОК'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (ok != true) return;
      confirmTrim = true;
    }

    try {
      final updated = await widget.tripsRepo.updateTrip(
        tripId: widget.tripId!,
        title: result.title,
        startDate: result.startDate,
        endDate: result.endDate,
        plannedDays: result.plannedDays,
        includePlannedDays: true,
        confirmTrim: confirmTrim,
        cardColor: result.cardColor,
        cardBackground: result.cardBackground,
        cardIcon: result.cardIcon,
      );
      if (!mounted) return;
      if (updated == null) return;
      setState(() {
        _tripTitle = updated.title;
        _tripStartDate = updated.startDate;
        _tripEndDate = updated.endDate;
        _tripPlannedDays = updated.plannedDays;
        _tripCardColor = updated.cardColor?.trim().isNotEmpty == true
            ? updated.cardColor!.trim()
            : _tripCardColor;
        _tripCardBackground =
            updated.cardBackground?.trim().isNotEmpty == true
                ? updated.cardBackground!.trim().toLowerCase()
                : _tripCardBackground;
        _tripCardIcon = updated.cardIcon?.trim().isNotEmpty == true
            ? updated.cardIcon!.trim().toLowerCase()
            : _tripCardIcon;
        _selectedRouteDay = _ensureSelectedRouteDay(
          _selectedRouteDay,
          stages: [..._stages]..sort((a, b) => a.position.compareTo(b.position)),
        );
      });
      await _loadStages();
      await _loadExpenses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Параметры маршрута обновлены')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить параметры маршрута')),
      );
    }
  }

  Future<void> _loadExpenses() async {
    if (widget.tripId == null) return;

    setState(() {
      _budgetLoading = true;
    });

    try {
      final items = await widget.tripsRepo.listExpenses(widget.tripId!);
      if (!mounted) return;
      setState(() {
        _expenses = items;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить расходы')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _budgetLoading = false;
        });
      }
    }
  }

  Future<void> _loadStages() async {
    if (widget.tripId == null) return;

    setState(() {
      _stagesLoading = true;
    });

    try {
      final items = await widget.tripsRepo.listStages(widget.tripId!);
      if (!mounted) return;
      final ordered = [...items]
        ..sort((a, b) => a.position.compareTo(b.position));
      final hasSelected = _selectedStageId != null &&
          ordered.any((item) => item.id == _selectedStageId);
      final nextSelectedId = ordered.isEmpty
          ? null
          : (hasSelected ? _selectedStageId : ordered.first.id);
      setState(() {
        _stages = ordered;
        _selectedStageId = nextSelectedId;
        _selectedRouteDay = _ensureSelectedRouteDay(
          _selectedRouteDay,
          stages: ordered,
        );
      });
      if (nextSelectedId != null) {
        final selected = ordered.cast<TripStage?>().firstWhere(
          (item) => item?.id == nextSelectedId,
          orElse: () => null,
        );
        if (selected != null) {
          await _loadSuggestionsForStage(selected);
        } else {
          setState(() {
            _stageSuggestions = const [];
          });
        }
      } else {
        setState(() {
          _stageSuggestions = const [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить этапы маршрута')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _stagesLoading = false;
        });
      }
    }
  }

  DateTime? _currentAssistantRouteDay() {
    final ordered = [..._stages]..sort((a, b) => a.position.compareTo(b.position));
    return _ensureSelectedRouteDay(_selectedRouteDay, stages: ordered);
  }

  DateTime? _parseAssistantTimeText(String? hhmm) {
    final value = (hhmm ?? '').trim();
    if (value.isEmpty || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final base = _currentAssistantRouteDay() ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  AddStagePayload _buildAssistantPayloadFromDraft(StageAssistantDraft draft) {
    return AddStagePayload(
      stageType: draft.stageType,
      subtype: draft.subtype,
      title: draft.title,
      startLocation: draft.startLocation,
      endLocation: draft.endLocation,
      address: draft.address,
      startTime: _parseAssistantTimeText(draft.startTimeText),
      endTime: _parseAssistantTimeText(draft.endTimeText),
      durationMinutes: draft.durationMinutes,
      costRub: draft.costRub,
      notes: draft.notes,
    );
  }

  Future<void> _submitStagePayload(AddStagePayload payload) async {
    if (widget.tripId == null) return;
    setState(() {
      _addingStage = true;
      _lastStageType = payload.stageType;
    });

    try {
      final created = await widget.tripsRepo.createStage(
        tripId: widget.tripId!,
        stageType: payload.stageType,
        subtype: payload.subtype,
        title: payload.title,
        startLocation: payload.startLocation,
        endLocation: payload.endLocation,
        address: payload.address,
        latitude: payload.latitude,
        longitude: payload.longitude,
        startTime: payload.startTime,
        endTime: payload.endTime,
        durationMinutes: payload.durationMinutes,
        costRub: payload.costRub,
        referenceNumber: payload.referenceNumber,
        notes: payload.notes,
        websiteUrl: payload.websiteUrl,
        rating: payload.rating,
        documentKey: payload.documentKey,
      );
      if (!mounted) return;
      if (created != null) {
        await _loadStages();
        await _loadExpenses();
        if (!mounted) return;
        setState(() {
          _selectedStageId = created.id;
        });
        await _loadSuggestionsForStage(created);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить этап маршрута')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingStage = false;
        });
      }
    }
  }

  void _showRouteAssistantSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Geologica',
              color: Color(0xFF171717),
              fontWeight: FontWeight.w300,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD7E37A),
          width: 430,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
  }

  String _friendlyAssistantErrorMessage(
    Object error, {
    required String fallback,
  }) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final detail = error.response?.data;
      final detailText = detail is Map
          ? detail['detail']?.toString()
          : detail?.toString();
      final normalized = (detailText ?? '').toLowerCase();
      if (normalized.contains('unknown api key') || normalized.contains('unauthorized')) {
        return 'Сервис быстрого ввода временно недоступен. Попробуйте позже.';
      }
      if (normalized.contains('speech was not recognized')) {
        return 'Не удалось распознать речь. Попробуйте сказать фразу четче.';
      }
      if (normalized.contains('audio payload is empty')) {
        return 'Запись получилась пустой. Нажмите и удерживайте кнопку чуть дольше.';
      }
      if (normalized.contains('invalid wav') ||
          normalized.contains('16 khz') ||
          normalized.contains('mono audio') ||
          normalized.contains('16-bit pcm')) {
        return 'Не удалось обработать аудио в этом браузере. Попробуйте Chrome или Edge.';
      }
      if (status == 401 || status == 403) {
        return 'Сессия истекла. Войдите в аккаунт снова.';
      }
      if (status == 500 || status == 502 || status == 503) {
        return 'Сервис временно недоступен. Попробуйте еще раз чуть позже.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Нет соединения с сервером. Проверьте интернет и попробуйте снова.';
      }
    }
    return fallback;
  }

  Future<void> _processAssistantSourceText(String sourceText) async {
    final normalized = sourceText.trim();
    if (normalized.isEmpty || widget.tripId == null) return;
    setState(() => _routeAssistantProcessing = true);
    try {
      final draft = await widget.tripsRepo.createStageDraftFromText(
        text: normalized,
        routeDay: _currentAssistantRouteDay(),
      );
      if (!mounted) return;
      if (draft == null) {
        _showRouteAssistantSnackBar('Не удалось обработать описание этапа');
        return;
      }
      final payload = await Navigator.of(context).push<AddStagePayload>(
        MaterialPageRoute(
          builder: (_) => StageFormPage(
            stageTypeLabels: _stageTypeLabels,
            stageSubtypes: _stageSubtypes,
            initialType: draft.stageType,
            destinationCity: widget.destinationCity,
            tripsRepo: widget.tripsRepo,
            isPremium: _hasPremium,
            routeDay: _currentAssistantRouteDay(),
            initial: _buildAssistantPayloadFromDraft(draft),
            onUploadDocument: _pickAndUploadDocumentForStage,
          ),
        ),
      );
      if (payload != null) {
        await _submitStagePayload(payload);
      }
    } catch (error) {
      if (!mounted) return;
      _showRouteAssistantSnackBar(
        _friendlyAssistantErrorMessage(
          error,
          fallback: 'Не удалось обработать описание этапа',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _routeAssistantProcessing = false);
      }
    }
  }

  Future<void> _openRouteAssistantTextEntry() async {
    if (widget.tripId == null) {
      _showRouteAssistantSnackBar('Сначала нужно открыть конкретное путешествие.');
      return;
    }
    final text = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _RouteAssistantTextDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    await _processAssistantSourceText(text);
  }

  Future<void> _startRouteAssistantRecording() async {
    if (_routeAssistantRecording || _routeAssistantProcessing || widget.tripId == null) {
      return;
    }
    try {
      if (kIsWeb) {
        final granted = await requestBrowserMicrophoneAccess();
        if (!granted) {
          _showRouteAssistantSnackBar(
            'Разрешите доступ к микрофону в браузере для голосового ввода.',
          );
          return;
        }
      }
      final hasPermission = await _routeAssistantRecorder.hasPermission();
      if (!hasPermission) {
        _showRouteAssistantSnackBar(
          'Разрешите доступ к микрофону в браузере для голосового ввода.',
        );
        return;
      }
      _routeAssistantTimer?.cancel();
      _routeAssistantStreamSub?.cancel();
      _routeAssistantAudioBytes.clear();

      if (kIsWeb) {
        await _routeAssistantRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: 'route_assistant_recording.wav',
        );
      } else {
        final stream = await _routeAssistantRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        _routeAssistantStreamSub = stream.listen((chunk) {
          _routeAssistantAudioBytes.addAll(chunk);
        });
      }
      if (!mounted) return;
      setState(() {
        _routeAssistantRecording = true;
        _routeAssistantSecondsLeft = 30;
      });
      _routeAssistantTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_routeAssistantSecondsLeft <= 1) {
          timer.cancel();
          _stopRouteAssistantRecordingIfNeeded();
          return;
        }
        setState(() {
          _routeAssistantSecondsLeft -= 1;
        });
      });
    } catch (_) {
      _showRouteAssistantSnackBar('Не удалось начать запись');
    }
  }

  void _handleRouteAssistantWebPointerDown() {
    if (_routeAssistantProcessing) return;
    _routeAssistantPointerDown = true;
    _routeAssistantHoldTimer?.cancel();
    _routeAssistantHoldTimer = Timer(const Duration(milliseconds: 180), () {
      if (_routeAssistantPointerDown && !_routeAssistantRecording) {
        _startRouteAssistantRecording();
      }
    });
  }

  Future<void> _handleRouteAssistantWebPointerUp() async {
    _routeAssistantHoldTimer?.cancel();
    final wasRecording = _routeAssistantRecording;
    _routeAssistantPointerDown = false;
    if (wasRecording) {
      await _stopRouteAssistantRecordingIfNeeded();
      return;
    }
    if (!_routeAssistantProcessing) {
      await _openRouteAssistantTextEntry();
    }
  }

  Future<void> _handleRouteAssistantWebPointerCancel() async {
    _routeAssistantHoldTimer?.cancel();
    final wasRecording = _routeAssistantRecording;
    _routeAssistantPointerDown = false;
    if (wasRecording) {
      await _stopRouteAssistantRecordingIfNeeded();
    }
  }

  Future<void> _stopRouteAssistantRecordingIfNeeded() async {
    if (!_routeAssistantRecording) return;
    _routeAssistantTimer?.cancel();
    _routeAssistantTimer = null;
    setState(() {
      _routeAssistantRecording = false;
      _routeAssistantSecondsLeft = 30;
      _routeAssistantProcessing = true;
    });

    try {
      Uint8List audioBytes;
      String filename;
      String mimeType;
      if (kIsWeb) {
        final path = await _routeAssistantRecorder.stop();
        if (path == null || path.isEmpty) {
          throw Exception('empty audio');
        }
        final response = await Dio().get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('empty audio');
        }
        audioBytes = Uint8List.fromList(bytes);
        filename = 'stage-voice.wav';
        mimeType = 'audio/wav';
      } else {
        await _routeAssistantRecorder.stop();
        await _routeAssistantStreamSub?.cancel();
        _routeAssistantStreamSub = null;
        if (_routeAssistantAudioBytes.isEmpty) {
          throw Exception('empty audio');
        }
        audioBytes = Uint8List.fromList(_routeAssistantAudioBytes);
        filename = 'stage-voice.raw';
        mimeType = 'application/octet-stream';
      }
      final transcript = await widget.tripsRepo.transcribeStageAudio(
        audioBytes: audioBytes,
        filename: filename,
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        _showRouteAssistantSnackBar('Не удалось распознать голосовое');
        return;
      }
      await _processAssistantSourceText(transcript);
    } catch (error) {
      if (!mounted) return;
      _showRouteAssistantSnackBar(
        _friendlyAssistantErrorMessage(
          error,
          fallback: 'Не удалось распознать голосовое',
        ),
      );
    } finally {
      _routeAssistantAudioBytes.clear();
      if (mounted) {
        setState(() => _routeAssistantProcessing = false);
      }
    }
  }

  Future<void> _openAddStageDialog({
    String? presetAddressFromMap,
    String? presetTitleFromMap,
  }) async {
    if (widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У этого путешествия нет ID для добавления этапов'),
        ),
      );
      return;
    }

    final presetAddress = (presetAddressFromMap ?? '').trim();
    final presetTitle = (presetTitleFromMap ?? '').trim();
    final payload = await Navigator.of(context).push<AddStagePayload>(
      MaterialPageRoute(
        builder: (_) => StageFormPage(
          stageTypeLabels: _stageTypeLabels,
          stageSubtypes: _stageSubtypes,
          initialType: _lastStageType,
          destinationCity: widget.destinationCity,
          tripsRepo: widget.tripsRepo,
          isPremium: _hasPremium,
          routeDay: _ensureSelectedRouteDay(
            _selectedRouteDay,
            stages: [..._stages]..sort((a, b) => a.position.compareTo(b.position)),
          ),
          initial: presetAddress.isEmpty
              ? null
              : AddStagePayload(
                  stageType: _lastStageType,
                  subtype: _lastStageType == 'transport'
                      ? 'road'
                      : (_stageSubtypes[_lastStageType]?.first ?? 'other'),
                  title: presetTitle.isEmpty ? presetAddress : presetTitle,
                  address: presetAddress,
                  notes: null,
                ),
          onUploadDocument: _pickAndUploadDocumentForStage,
        ),
      ),
    );
    if (payload == null) return;
    await _submitStagePayload(payload);
    return;

    setState(() {
      _addingStage = true;
      _lastStageType = payload.stageType;
    });

    try {
      final created = await widget.tripsRepo.createStage(
        tripId: widget.tripId!,
        stageType: payload.stageType,
        subtype: payload.subtype,
        title: payload.title,
        startLocation: payload.startLocation,
        endLocation: payload.endLocation,
        address: payload.address,
        latitude: payload.latitude,
        longitude: payload.longitude,
        startTime: payload.startTime,
        endTime: payload.endTime,
        durationMinutes: payload.durationMinutes,
        costRub: payload.costRub,
        referenceNumber: payload.referenceNumber,
        notes: payload.notes,
        websiteUrl: payload.websiteUrl,
        rating: payload.rating,
        documentKey: payload.documentKey,
      );
      if (!mounted) return;
      if (created != null) {
        await _loadStages();
        await _loadExpenses();
        if (!mounted) return;
        setState(() {
          _selectedStageId = created.id;
        });
        await _loadSuggestionsForStage(created);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить этап маршрута')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingStage = false;
        });
      }
    }
  }

  Future<void> _openEditStageDialog(TripStage stage) async {
    if (widget.tripId == null) return;

    final payload = await Navigator.of(context).push<AddStagePayload>(
      MaterialPageRoute(
        builder: (_) => StageFormPage(
          stageTypeLabels: _stageTypeLabels,
          stageSubtypes: _stageSubtypes,
          initialType: stage.stageType,
          destinationCity: widget.destinationCity,
          tripsRepo: widget.tripsRepo,
          isPremium: _hasPremium,
          onUploadDocument: _pickAndUploadDocumentForStage,
          initial: AddStagePayload(
            stageType: stage.stageType,
            subtype: stage.subtype,
            title: stage.title,
            startLocation: stage.startLocation,
            endLocation: stage.endLocation,
            address: stage.address,
            latitude: stage.latitude,
            longitude: stage.longitude,
            startTime: stage.startTime,
            endTime: stage.endTime,
            durationMinutes: stage.durationMinutes,
            costRub: stage.costRub,
            referenceNumber: stage.referenceNumber,
            notes: stage.notes,
            websiteUrl: stage.websiteUrl,
            rating: stage.rating,
            documentKey: stage.documentKey,
          ),
          submitLabel: 'Сохранить',
        ),
      ),
    );
    if (payload == null) return;

    try {
      await widget.tripsRepo.updateStage(
        tripId: widget.tripId!,
        stageId: stage.id,
        patch: {
          'stage_type': payload.stageType,
          'subtype': payload.subtype,
          'title': payload.title,
          'start_location': payload.startLocation,
          'end_location': payload.endLocation,
          'address': payload.address,
          'latitude': payload.latitude,
          'longitude': payload.longitude,
          'start_time': payload.startTime?.toIso8601String(),
          'end_time': payload.endTime?.toIso8601String(),
          'duration_minutes': payload.durationMinutes,
          'cost_rub': payload.costRub?.toStringAsFixed(2),
          'reference_number': payload.referenceNumber,
          'notes': payload.notes,
          'website_url': payload.websiteUrl,
          'rating': payload.rating,
          'document_key': payload.documentKey,
        },
      );
      await _loadStages();
      await _loadExpenses();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить этап')),
      );
    }
  }

  Future<void> _openEditStageDialogWithTimes(
    TripStage stage, {
    required int startMin,
    required int endMin,
  }) async {
    if (widget.tripId == null) return;
    final base = stage.startTime ?? stage.endTime ?? _selectedRouteDay ?? DateTime.now();
    DateTime atMinutes(int minutes) {
      final clamped = minutes.clamp(0, 24 * 60) as int;
      final h = (clamped ~/ 60).clamp(0, 23);
      final m = clamped % 60;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final payload = await Navigator.of(context).push<AddStagePayload>(
      MaterialPageRoute(
        builder: (_) => StageFormPage(
          stageTypeLabels: _stageTypeLabels,
          stageSubtypes: _stageSubtypes,
          initialType: stage.stageType,
          destinationCity: widget.destinationCity,
          tripsRepo: widget.tripsRepo,
          isPremium: _hasPremium,
          onUploadDocument: _pickAndUploadDocumentForStage,
          initial: AddStagePayload(
            stageType: stage.stageType,
            subtype: stage.subtype,
            title: stage.title,
            startLocation: stage.startLocation,
            endLocation: stage.endLocation,
            address: stage.address,
            latitude: stage.latitude,
            longitude: stage.longitude,
            startTime: atMinutes(startMin),
            endTime: atMinutes(endMin),
            durationMinutes: stage.durationMinutes,
            costRub: stage.costRub,
            referenceNumber: stage.referenceNumber,
            notes: stage.notes,
            websiteUrl: stage.websiteUrl,
            rating: stage.rating,
            documentKey: stage.documentKey,
          ),
          submitLabel: 'Сохранить',
        ),
      ),
    );
    if (payload == null) return;

    try {
      await widget.tripsRepo.updateStage(
        tripId: widget.tripId!,
        stageId: stage.id,
        patch: {
          'stage_type': payload.stageType,
          'subtype': payload.subtype,
          'title': payload.title,
          'start_location': payload.startLocation,
          'end_location': payload.endLocation,
          'address': payload.address,
          'latitude': payload.latitude,
          'longitude': payload.longitude,
          'start_time': payload.startTime?.toIso8601String(),
          'end_time': payload.endTime?.toIso8601String(),
          'duration_minutes': payload.durationMinutes,
          'cost_rub': payload.costRub?.toStringAsFixed(2),
          'reference_number': payload.referenceNumber,
          'notes': payload.notes,
          'website_url': payload.websiteUrl,
          'rating': payload.rating,
          'document_key': payload.documentKey,
        },
      );
      await _loadStages();
      await _loadExpenses();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить этап')),
      );
    }
  }

  Future<void> _applyStageTimesFromDrag(
    TripStage stage, {
    required int startMin,
    required int endMin,
  }) async {
    if (widget.tripId == null) return;
    final base = stage.startTime ?? stage.endTime ?? _selectedRouteDay ?? DateTime.now();
    DateTime atMinutes(int minutes) {
      final clamped = minutes.clamp(0, 24 * 60) as int;
      final h = (clamped ~/ 60).clamp(0, 23);
      final m = clamped % 60;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final newStart = atMinutes(startMin);
    final newEnd = atMinutes(endMin);
    try {
      await widget.tripsRepo.updateStage(
        tripId: widget.tripId!,
        stageId: stage.id,
        patch: {
          'start_time': newStart.toIso8601String(),
          'end_time': newEnd.toIso8601String(),
          'duration_minutes': null,
        },
      );
      await _loadStages();
      await _loadExpenses();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить время этапа')),
      );
    }
  }

  Future<void> _deleteStage(TripStage stage) async {
    if (widget.tripId == null) return;
    try {
      await widget.tripsRepo.deleteStage(
        tripId: widget.tripId!,
        stageId: stage.id,
      );
      await _loadStages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить этап')));
    }
  }

  Future<void> _copyStage(TripStage stage) async {
    if (widget.tripId == null) return;
    try {
      await widget.tripsRepo.copyStage(
        tripId: widget.tripId!,
        stageId: stage.id,
      );
      await _loadStages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось скопировать этап')),
      );
    }
  }

  Future<void> _moveStage(int oldIndex, int newIndex) async {
    if (widget.tripId == null) return;
    final current = [..._stages]
      ..sort((a, b) => a.position.compareTo(b.position));
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex >= current.length) {
      return;
    }

    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);

    setState(() {
      _stages = current;
    });

    try {
      final updated = await widget.tripsRepo.reorderStages(
        tripId: widget.tripId!,
        orderedIds: current.map((e) => e.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _stages = updated;
      });
    } catch (_) {
      await _loadStages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить порядок этапов')),
      );
    }
  }

  Future<void> _loadSuggestionsForStage(TripStage stage) async {
    if (widget.tripId == null) return;

    setState(() {
      _suggestionsLoading = true;
    });

    try {
      final suggestions = await widget.tripsRepo.listStageSuggestions(
        tripId: widget.tripId!,
        stageId: stage.id,
      );
      if (!mounted) return;
      final incomingKeys = suggestions.map(_suggestionKey).toSet();
      setState(() {
        _stageSuggestions = suggestions;
        _hiddenSuggestionKeys.removeWhere((key) => !incomingKeys.contains(key));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stageSuggestions = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить предложения')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _suggestionsLoading = false;
        });
      }
    }
  }

  Future<void> _addSuggestedStage(StageSuggestion suggestion) async {
    if (widget.tripId == null) return;
    setState(() {
      _addingSuggestedStage = true;
    });

    try {
      await widget.tripsRepo.createStageFromSuggestion(
        tripId: widget.tripId!,
        suggestion: suggestion,
      );
      final suggestionKey = _suggestionKey(suggestion);
      if (mounted) {
        setState(() {
          _hiddenSuggestionKeys.add(suggestionKey);
        });
      }
      await _loadStages();
      await _loadExpenses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этап добавлен в маршрут')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить этап из предложения')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingSuggestedStage = false;
        });
      }
    }
  }

  String _suggestionKey(StageSuggestion suggestion) {
    return '${suggestion.stageType}|${suggestion.subtype}|${suggestion.title}|${suggestion.address ?? ''}';
  }

  IconData _iconForStageType(String stageType) {
    switch (stageType) {
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

  _StageVisualConfig _stageVisual(String stageType) {
    switch (stageType) {
      case 'transport':
        return const _StageVisualConfig(
          iconColor: Color(0xFF7AE3BA), // #7ae3ba
          backgroundColor: Color(0x1A7AE3BA),
          borderColor: Color(0x337AE3BA),
        );
      case 'place':
        return const _StageVisualConfig(
          iconColor: Color(0xFFB6A1FF), // #b6a1ff
          backgroundColor: Color(0x1AB6A1FF),
          borderColor: Color(0x33B6A1FF),
        );
      case 'stay':
        return const _StageVisualConfig(
          iconColor: Color(0xFFE3BA7A), // #e3ba7a
          backgroundColor: Color(0x1AE3BA7A),
          borderColor: Color(0x33E3BA7A),
        );
      case 'food':
        return const _StageVisualConfig(
          iconColor: Color(0xFFE37AA2), // #e37aa2
          backgroundColor: Color(0x1AE37AA2),
          borderColor: Color(0x33E37AA2),
        );
      case 'shopping':
        return const _StageVisualConfig(
          iconColor: Color(0xFFA3E37A), // #a3e37a
          backgroundColor: Color(0x1AA3E37A),
          borderColor: Color(0x33A3E37A),
        );
      case 'activity':
        return const _StageVisualConfig(
          iconColor: Color(0xFF7AB4E3), // Р С–Р В°РЎР‚Р СР С•Р Р…Р С‘РЎвЂЎР Р…РЎвЂ№Р в„– Р С–Р С•Р В»РЎС“Р В±Р С•Р в„–
          backgroundColor: Color(0x1A7AB4E3),
          borderColor: Color(0x337AB4E3),
        );
      case 'document':
        return const _StageVisualConfig(
          iconColor: Color(0xFF7AE3BA), // #7ae3ba
          backgroundColor: Color(0x1A7AE3BA),
          borderColor: Color(0x337AE3BA),
        );
      default:
        return const _StageVisualConfig(
          iconColor: Color(0xFFB6A1FF), // #b6a1ff
          backgroundColor: Color(0x1AB6A1FF),
          borderColor: Color(0x33B6A1FF),
        );
    }
  }

  String _prettySubtype(String subtype) {
    const labels = <String, String>{
      'road': 'Дорога',
      'airplane': 'Самолет',
      'train': 'Поезд',
      'car': 'Авто',
      'bus': 'Автобус',
      'public_transport': 'ОТ',
      'walk': 'Пешком',
      'taxi': 'Такси',
      'bicycle': 'Велосипед',
      'attraction': 'Достоприм.',
      'excursion': 'Экскурсия',
      'museum': 'Музей',
      'park': 'Парк',
      'event': 'Событие',
      'nature': 'Природа',
      'hotel': 'Отель',
      'hostel': 'Хостел',
      'apartment': 'Апарт.',
      'overnight': 'Ночевка',
      'rest': 'Отдых',
      'restaurant': 'Ресторан',
      'cafe': 'Кафе',
      'fastfood': 'Фастфуд',
      'breakfast': 'Завтрак',
      'lunch': 'Обед',
      'dinner': 'Ужин',
      'to_go': 'С собой',
      'mall': 'ТЦ',
      'market': 'Рынок',
      'souvenirs': 'Сувениры',
      'shopping': 'Покупки',
      'sport': 'Спорт',
      'entertainment': 'Развлеч.',
      'beach': 'Пляж',
      'tickets': 'Билеты',
      'visa': 'Виза',
      'insurance': 'Страховка',
      'booking': 'Бронь',
    };
    return labels[subtype] ?? subtype;
  }

  String? _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return null;
    String format(DateTime? date) {
      if (date == null) return '--:--';
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${format(start)}-${format(end)}';
  }

  Future<void> _openAddExpenseDialog() async {
    if (widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У этого путешествия нет ID для добавления расходов'),
        ),
      );
      return;
    }

    final result = await showDialog<_AddExpensePayload>(
      context: context,
      builder: (context) => _AddExpenseDialog(categories: _categories),
    );

    if (result == null) return;

    setState(() {
      _addingExpense = true;
    });

    try {
      final created = await widget.tripsRepo.createExpense(
        tripId: widget.tripId!,
        description: result.description,
        amountRub: result.amountRub,
        category: result.category,
      );

      if (!mounted) return;
      if (created != null) {
        setState(() {
          _expenses = [created, ..._expenses];
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить расход')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingExpense = false;
        });
      }
    }
  }

  Future<void> _openEditExpenseDialog(TripExpense expense) async {
    if (widget.tripId == null) return;

    final result = await showDialog<_AddExpensePayload>(
      context: context,
      builder: (context) => _AddExpenseDialog(
        categories: _categories,
        title: 'Редактировать расход',
        submitLabel: 'Сохранить',
        initial: _AddExpensePayload(
          description: expense.description,
          amountRub: expense.amountRub,
          category: expense.category,
        ),
      ),
    );

    if (result == null) return;

    try {
      final updated = await widget.tripsRepo.updateExpense(
        tripId: widget.tripId!,
        expenseId: expense.id,
        description: result.description,
        amountRub: result.amountRub,
        category: result.category,
      );

      if (!mounted || updated == null) return;
      setState(() {
        _expenses = _expenses
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить расход')),
      );
    }
  }

  Future<void> _deleteExpense(TripExpense expense) async {
    if (widget.tripId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1D222A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text(
          'Удалить расход?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Geologica',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Расход "${expense.description}" будет удалён без возможности восстановления.',
          style: const TextStyle(
            color: Color(0xFFB7BDC8),
            fontFamily: 'Geologica',
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB7BDC8)),
            child: const Text(
              'Отмена',
              style: TextStyle(fontFamily: 'Geologica', fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7E37A),
              foregroundColor: const Color(0xFF151515),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Удалить',
              style: TextStyle(fontFamily: 'Geologica', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.tripsRepo.deleteExpense(
        tripId: widget.tripId!,
        expenseId: expense.id,
      );

      if (!mounted) return;
      setState(() {
        _expenses = _expenses.where((item) => item.id != expense.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить расход')),
      );
    }
  }

  Future<void> _loadDocuments() async {
    if (widget.tripId == null) return;
    setState(() {
      _documentsLoading = true;
    });
    try {
      final items = await widget.documentsRepo.listTripDocuments(
        widget.tripId!,
      );
      if (!mounted) return;
      setState(() {
        _documents = items;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить документы')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _documentsLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
    await _pickAndUploadDocumentForStage(showSuccessSnackBar: true);
  }

  Future<String?> _pickAndUploadDocumentForStage({
    bool showSuccessSnackBar = false,
  }) async {
    if (widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала откройте путешествие с корректным ID'),
        ),
      );
      return null;
    }

    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось прочитать файл')),
      );
      return null;
    }

    final contentType = _resolveContentType(file.name);
    if (contentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Разрешены только PDF, JPG, PNG')),
      );
      return null;
    }

    final customTitle = await _openDocumentTitleDialog(file.name);
    if (customTitle == null) return null;

    final targetFileName = _buildTargetFileName(
      customTitle: customTitle,
      originalFileName: file.name,
    );

    setState(() {
      _uploadingDocument = true;
    });
    try {
      final uploaded = await widget.documentsRepo.uploadBytesDirect(
        tripId: widget.tripId!,
        fileName: targetFileName,
        bytes: bytes,
        contentType: contentType,
      );
      await _loadDocuments();
      if (!mounted) return null;
      if (showSuccessSnackBar) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Документ загружен')));
      }
      return uploaded.objectKey;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки документа')),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _uploadingDocument = false;
        });
      }
    }
    return null;
  }

  Future<String?> _openDocumentTitleDialog(String originalFileName) async {
    final defaultName = _fileNameWithoutExtension(originalFileName);
    final controller = TextEditingController(text: defaultName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _popupBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _popupBorder),
          ),
          title: const Text(
            'Название документа',
            style: TextStyle(
              color: _popupText,
              fontFamily: 'Geologica',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              color: _popupText,
              fontFamily: 'Geologica',
            ),
            decoration: const InputDecoration(
              labelText: 'Введите название',
              hintText: 'Например: Билет Москва-СПб',
              labelStyle: TextStyle(
                color: _popupSubtleText,
                fontFamily: 'Geologica',
              ),
              hintStyle: TextStyle(
                color: _popupSubtleText,
                fontFamily: 'Geologica',
              ),
              filled: true,
              fillColor: _popupFieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: _popupBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: _popupAccent),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  color: _popupSubtleText,
                  fontFamily: 'Geologica',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _popupAccent,
                foregroundColor: const Color(0xFF161616),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _openDocumentPreview(TripDocument doc) async {
    try {
      final downloadUrl = await widget.documentsRepo.getDownloadUrl(
        doc.objectKey,
      );
      if (!mounted) return;

      final fileType = _resolvePreviewType(doc.fileName);
      if (fileType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предпросмотр доступен только для PDF, JPG и PNG'),
          ),
        );
        return;
      }
      final fileBytes = await widget.documentsRepo.fetchFileBytes(downloadUrl);
      if (!mounted) return;
      if (fileBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл пустой или недоступен')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => _DocumentPreviewDialog(
          title: doc.fileName,
          fileBytes: fileBytes,
          fileType: fileType,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть предпросмотр')),
      );
    }
  }

  Future<void> _openDocumentByKey(String objectKey, String title) async {
    try {
      final downloadUrl = await widget.documentsRepo.getDownloadUrl(objectKey);
      if (!mounted) return;
      final fileType = _resolvePreviewType(objectKey);
      if (fileType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предпросмотр доступен только для PDF, JPG и PNG'),
          ),
        );
        return;
      }
      final fileBytes = await widget.documentsRepo.fetchFileBytes(downloadUrl);
      if (!mounted) return;
      if (fileBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл пустой или недоступен')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => _DocumentPreviewDialog(
          title: title,
          fileBytes: fileBytes,
          fileType: fileType,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть документ этапа')),
      );
    }
  }

  Future<void> _deleteDocument(TripDocument doc) async {
    try {
      await widget.documentsRepo.deleteObject(doc.objectKey);
      if (!mounted) return;
      setState(() {
        _documents = _documents
            .where((d) => d.objectKey != doc.objectKey)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка удаления документа')),
      );
    }
  }

  Future<void> _openRouteMap() async {
    final city = (widget.destinationCity ?? '').trim();
    final stagesForDay = _visibleStagesForSelectedDay();
    int sortStamp(TripStage stage) {
      final dt = stage.startTime ?? stage.endTime;
      if (dt == null) return 1 << 30;
      return dt.hour * 60 + dt.minute;
    }

    final orderedStages = [...stagesForDay]
      ..sort((a, b) {
        final byTime = sortStamp(a).compareTo(sortStamp(b));
        if (byTime != 0) return byTime;
        return a.position.compareTo(b.position);
      });

    final stagePoints = <Map<String, String>>[];
    var routeOrder = 1;
    String fmtHm(DateTime? dt) {
      if (dt == null) return '';
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    String stageTimeRange(TripStage stage) {
      final start = fmtHm(stage.startTime);
      final end = fmtHm(stage.endTime);
      if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
      if (start.isNotEmpty) return start;
      if (end.isNotEmpty) return end;
      return '';
    }

    for (final stage in orderedStages) {
      final cityNorm = city.trim().toLowerCase();
      final candidates = <String>[
        (stage.address ?? '').trim(),
        (stage.endLocation ?? '').trim(),
        (stage.startLocation ?? '').trim(),
      ].where((e) => e.isNotEmpty).toList();
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) => b.length.compareTo(a.length));
      var address = candidates.first;
      if (address.toLowerCase() == cityNorm && candidates.length > 1) {
        address = candidates.firstWhere(
          (c) => c.toLowerCase() != cityNorm,
          orElse: () => address,
        );
      }
      if (address.isEmpty) continue;
      final time = stageTimeRange(stage);
      final duration = stage.durationMinutes != null && stage.durationMinutes! > 0
          ? '${stage.durationMinutes} мин'
          : '';
      stagePoints.add({
        'title': stage.title.trim(),
        'stage_type': stage.stageType,
        'subtype': stage.subtype,
        'start_location': (stage.startLocation ?? '').trim(),
        'end_location': (stage.endLocation ?? '').trim(),
        'address': address,
        'order': '$routeOrder',
        'time': time.isNotEmpty ? time : duration,
        'start_time': fmtHm(stage.startTime),
        'end_time': fmtHm(stage.endTime),
        'cost': stage.costRub == null ? '' : '${stage.costRub!.toStringAsFixed(2)} руб.',
        'duration': duration,
        'reference_number': (stage.referenceNumber ?? '').trim(),
        'notes': (stage.notes ?? '').trim(),
        'website_url': (stage.websiteUrl ?? '').trim(),
        'rating': stage.rating == null ? '' : stage.rating!.toStringAsFixed(1),
        'document_key': (stage.documentKey ?? '').trim(),
      });
      routeOrder += 1;
    }
    if (city.isEmpty && stagePoints.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет адресов этапов для отображения')),
      );
      return;
    }
    final result = await Navigator.of(context).push<_MapAddStagePayload>(
      MaterialPageRoute(
        builder: (_) => _TripRouteMapPage(
          tripTitle: _tripTitle,
          destinationCity: city,
          stagePoints: stagePoints,
          startDate: _tripStartDate,
          endDate: _tripEndDate,
          tripsRepo: widget.tripsRepo,
        ),
      ),
    );
    if (!mounted) return;
    final mapAddress = (result?.address ?? '').trim();
    final mapTitle = (result?.title ?? '').trim();
    if (mapAddress.isNotEmpty) {
      await _openAddStageDialog(
        presetAddressFromMap: mapAddress,
        presetTitleFromMap: mapTitle,
      );
    }
    if (!mounted) return;
    setState(() {
      _currentIndex = 1;
    });
  }

  void _openTripFavoritesView() {
    setState(() {
      _currentIndex = 0;
      _showTripFavorites = true;
    });
  }

  void _closeTripFavoritesView() {
    setState(() {
      _currentIndex = 0;
      _showTripFavorites = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final routeOrdered = [..._stages]
      ..sort((a, b) => a.position.compareTo(b.position));
    final routeDays = _tripDays(stages: routeOrdered);
    final routeSelectedDay = _ensureSelectedRouteDay(
      _selectedRouteDay,
      stages: routeOrdered,
    );

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
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go('/profile'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.14)),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded,
                                size: 18),
                            label: const Text('К поездкам'),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Редактировать маршрут',
                            onPressed: _openTripSettingsDialog,
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _tripTitle,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_currentIndex == 1 && routeDays.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _RouteDayStrip(
                          days: routeDays,
                          selectedDay: routeSelectedDay,
                          numberedOnly:
                              _tripPlannedDays != null && _tripPlannedDays! > 0,
                          compact: true,
                          onDayTap: (day) {
                            setState(() {
                              _selectedRouteDay = day;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: _currentIndex == 1
                            ? _buildRouteCard(cs)
                            : _currentIndex == 2
                                ? _buildBudgetCard(cs)
                                : _currentIndex == 3
                                    ? _buildDocumentsCard()
                                    : _showTripFavorites
                                        ? FavoritesPage(
                                            interactionsRepo:
                                                widget.interactionsRepo,
                                            profileRepo: widget.profileRepo,
                                            tripsRepo: widget.tripsRepo,
                                            tripId: widget.tripId,
                                            city: widget.destinationCity,
                                            titleOverride: 'Сохраненные места',
                                            embedded: true,
                                            onBack: _closeTripFavoritesView,
                                          )
                                        : TripRecommendationsTab(
                                            recommendationsRepo:
                                                widget.recommendationsRepo,
                                            interactionsRepo:
                                                widget.interactionsRepo,
                                            preferencesRepo:
                                                widget.preferencesRepo,
                                            profileRepo: widget.profileRepo,
                                            tripsRepo: widget.tripsRepo,
                                            tripId: widget.tripId,
                                            destinationCity:
                                                widget.destinationCity,
                                            tripTitle: _tripTitle,
                                            stages: _stages,
                                            onStagesChanged: _loadStages,
                                            onOpenTripFavorites:
                                                _openTripFavoritesView,
                                          ),
                      ),
                      const SizedBox(height: 14),
                      _BottomMenu(
                        currentIndex: _currentIndex,
                        lightStyle: false,
                        onTap: (index) {
                          setState(() {
                            _currentIndex = index;
                            if (index != 0) _showTripFavorites = false;
                            if (index != 2) _showBudgetAnalytics = false;
                          });
                          if (index == 2) {
                            _loadExpenses();
                          } else if (index == 1) {
                            _loadStages();
                          } else if (index == 3) {
                            _loadDocuments();
                          }
                        },
                      ),
                      const SizedBox(height: 18),
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

class _DocumentPreviewDialog extends StatelessWidget {
  final String title;
  final Uint8List fileBytes;
  final String fileType;

  const _DocumentPreviewDialog({
    required this.title,
    required this.fileBytes,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF1D222A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF3A4751)),
      ),
      child: SizedBox(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF2F4F8),
                        fontFamily: 'Geologica',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFD7E37A),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF3A4751)),
            Expanded(
              child: fileType == 'pdf'
                  ? PdfMemoryPreview(bytes: fileBytes)
                  : InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.memory(
                          fileBytes,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'Не удалось отобразить изображение',
                              style: TextStyle(
                                color: Color(0xFFB7BDC8),
                                fontFamily: 'Geologica',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  final Map<String, double> values;
  final Map<String, Color> colors;
  final double total;

  const _ExpensePieChart({
    required this.values,
    required this.colors,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _ExpensePiePainter(values: values, colors: colors),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Итого',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${total.toStringAsFixed(2)} руб.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpensePiePainter extends CustomPainter {
  final Map<String, double> values;
  final Map<String, Color> colors;

  const _ExpensePiePainter({
    required this.values,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = values.values.fold<double>(0, (sum, v) => sum + v);

    if (total <= 0) {
      final emptyPaint = Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26;
      canvas.drawCircle(center, radius - 13, emptyPaint);
      return;
    }

    var start = -math.pi / 2;
    values.forEach((key, value) {
      if (value <= 0) return;
      final sweep = (value / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[key] ?? colors['other'] ?? Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    });
  }

  @override
  bool shouldRepaint(covariant _ExpensePiePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _AddExpensePayload {
  final String description;
  final double amountRub;
  final String category;

  _AddExpensePayload({
    required this.description,
    required this.amountRub,
    required this.category,
  });
}

class _AddExpenseDialog extends StatefulWidget {
  final Map<String, String> categories;
  final _AddExpensePayload? initial;
  final String title;
  final String submitLabel;

  const _AddExpenseDialog({
    required this.categories,
    this.initial,
    this.title = 'Добавить расход',
    this.submitLabel = 'Создать',
  });

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  static final RegExp _moneyInputPattern = RegExp(r'^\d*([.,]\d{0,2})?$');
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl = TextEditingController(
      text: widget.initial?.description ?? '',
    );
    _amountCtrl = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.amountRub.toStringAsFixed(2),
    );
    _category = widget.initial?.category ?? 'food';
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1D222A);
    const border = Color(0xFF3A4751);
    const fieldBg = Color(0xFF2A2F36);
    const text = Color(0xFFF2F4F8);
    const subtle = Color(0xFFB7BDC8);
    const accent = Color(0xFFD7E37A);
    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: border),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: text,
          fontFamily: 'Geologica',
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionCtrl,
                style: const TextStyle(color: text, fontFamily: 'Geologica'),
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  labelStyle: TextStyle(color: subtle, fontFamily: 'Geologica'),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Введите описание';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_moneyInputPattern),
                ],
                style: const TextStyle(color: text, fontFamily: 'Geologica'),
                decoration: const InputDecoration(
                  labelText: 'Сумма (руб)',
                  labelStyle: TextStyle(color: subtle, fontFamily: 'Geologica'),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) {
                  final raw = (v ?? '').trim().replaceAll(',', '.');
                  final amount = double.tryParse(raw);
                  if (amount == null || amount <= 0) {
                    return 'Введите корректную сумму';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: bg,
                style: const TextStyle(
                  color: text,
                  fontFamily: 'Geologica',
                  fontWeight: FontWeight.w500,
                ),
                iconEnabledColor: accent,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  labelStyle: TextStyle(color: subtle, fontFamily: 'Geologica'),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                items: widget.categories.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: text,
                            fontFamily: 'Geologica',
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Отмена',
            style: TextStyle(
              color: subtle,
              fontFamily: 'Geologica',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: const Color(0xFF161616),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _AddExpensePayload(
                description: _descriptionCtrl.text.trim(),
                amountRub: double.parse(
                  _amountCtrl.text.trim().replaceAll(',', '.'),
                ),
                category: _category,
              ),
            );
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _AddStagePayload {
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

  _AddStagePayload({
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

class _StageTypePickerPage extends StatelessWidget {
  final Map<String, String> stageTypeLabels;

  const _StageTypePickerPage({required this.stageTypeLabels});

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
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
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

class _StageFormPage extends StatefulWidget {
  final Map<String, String> stageTypeLabels;
  final Map<String, List<String>> stageSubtypes;
  final String initialType;
  final DateTime? routeDay;
  final _AddStagePayload? initial;
  final String submitLabel;
  final Future<String?> Function()? onUploadDocument;

  const _StageFormPage({
    required this.stageTypeLabels,
    required this.stageSubtypes,
    required this.initialType,
    this.routeDay,
    this.onUploadDocument,
    this.initial,
    this.submitLabel = 'Добавить',
  });

  @override
  State<_StageFormPage> createState() => _StageFormPageState();
}

class _StageFormPageState extends State<_StageFormPage> {
  static final RegExp _moneyInputPattern = RegExp(r'^\d*([.,]\d{0,2})?$');
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
  final _startLocationCtrl = TextEditingController();
  final _endLocationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  bool _uploadingStageDocument = false;
  bool _titleEdited = false;
  String _transportTimeMode = 'duration';

  late String _stageType;
  late String _subtype;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startLocationCtrl.dispose();
    _endLocationCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _durationCtrl.dispose();
    _costCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    _websiteCtrl.dispose();
    _ratingCtrl.dispose();
    _docCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
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
    }
    if (_durationCtrl.text.trim().isEmpty) {
      _durationCtrl.text = '60';
    }
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
                  color: Color(0xFFAEB7A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                hourMinuteTextStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
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
        color: selected ? const Color(0xFFD7E37A) : Colors.white,
        fontWeight: FontWeight.w500,
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
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
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
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
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
                            inputDecorationTheme: InputDecorationTheme(
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
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
                                        avatar: Icon(
                                          _typeIcon(entry.key),
                                          size: 16,
                                          color: selected
                                              ? const Color(0xFFD7E37A)
                                              : Colors.white70,
                                        ),
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? const Color(0xFFD7E37A)
                                              : Colors.white,
                                          fontWeight: FontWeight.w700,
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
                                _bubble('Основное', [
                                  TextFormField(
                                    controller: _titleCtrl,
                                    onChanged: (value) {
                                      final normalized = value.trim();
                                      final autoTitle = _defaultStageTitle();
                                      _titleEdited = normalized.isNotEmpty && normalized != autoTitle;
                                    },
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(labelText: 'Название'),
                                    validator: (v) =>
                                        (v ?? '').trim().isEmpty ? 'Введите название' : null,
                                  ),
                                  const SizedBox(height: 8),
                                  if (isTransport) ...[
                                    TextFormField(
                                      controller: _startLocationCtrl,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(labelText: 'Откуда'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _endLocationCtrl,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(labelText: 'Куда'),
                                    ),
                                  ] else ...[
                                    TextFormField(
                                      controller: _addressCtrl,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
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
                                                    fontWeight: FontWeight.w600,
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
                                                    fontWeight: FontWeight.w600,
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(labelText: 'Комментарий'),
                                      maxLines: 3,
                                    ),
                                ], Colors.greenAccent),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
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
                                        _AddStagePayload(
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
                              widget.submitLabel == 'Добавить' ? 'Новый этап' : 'Редактирование этапа',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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
                            inputDecorationTheme: InputDecorationTheme(
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
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
                              _bubble('Тип этапа', [
                                DropdownButtonFormField<String>(
                                  value: _stageType,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  dropdownColor: const Color(0xFF2B2B2B),
                                  iconEnabledColor: Colors.white70,
                                  decoration: const InputDecoration(labelText: 'Тип'),
                                  items: stageTypeItems.entries
                                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _stageType = value;
                                      _subtype = widget.stageSubtypes[value]?.first ?? '';
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: (_subtype.isNotEmpty && subtypes.contains(_subtype)) ? _subtype : null,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                                              fontWeight: FontWeight.w600,
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
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (subtypes.isEmpty) return;
                                    if (value == null) return;
                                    setState(() {
                                      _subtype = value;
                                    });
                                  },
                                ),
                              ], cs.primary),
                              _bubble('Основное', [
                                TextFormField(
                                  controller: _titleCtrl,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(labelText: 'Название'),
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Введите название' : null,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _addressCtrl,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(labelText: 'Адрес / место'),
                                ),
                              ], Colors.cyan),
                              _bubble('Логистика и время', [
                                if (isTransport) ...[
                                  TextFormField(
                                    controller: _startLocationCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(labelText: 'Откуда'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _endLocationCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(labelText: 'Куда'),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(children: [
                                  Expanded(child: _timeField(isTransport ? 'Время отправления' : 'Время начала', _startTimeCtrl)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _timeField(isTransport ? 'Время прибытия' : 'Время окончания', _endTimeCtrl)),
                                ]),
                              ], Colors.amber),
                              _bubble('Финансы и детали', [
                                if (!isDocument) ...[
                                  TextFormField(
                                    controller: _costCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(labelText: isFood ? 'Сколько потрачу, руб' : 'Стоимость, руб'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(_moneyInputPattern),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ], Colors.greenAccent),
                              _bubble('Файлы и заметки', [
                                if (isTransport || isStay) ...[
                                  TextFormField(
                                    controller: _docCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(labelText: 'Ключ документа'),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (isDocument) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: (_uploadingStageDocument || widget.onUploadDocument == null)
                                          ? null
                                          : () async {
                                              setState(() => _uploadingStageDocument = true);
                                              final objectKey = await widget.onUploadDocument!.call();
                                              if (!mounted) return;
                                              if (objectKey != null && objectKey.isNotEmpty) {
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(labelText: 'Комментарий'),
                                  maxLines: 3,
                                ),
                              ], Colors.pinkAccent),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!(_formKey.currentState?.validate() ?? false)) return;
                                    Navigator.of(context).pop(
                                      _AddStagePayload(
                                        stageType: _stageType,
                                        subtype: _subtype,
                                        title: _titleCtrl.text.trim(),
                                        startLocation: _startLocationCtrl.text.trim().isEmpty ? null : _startLocationCtrl.text.trim(),
                                        endLocation: _endLocationCtrl.text.trim().isEmpty ? null : _endLocationCtrl.text.trim(),
                                        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                                        latitude: widget.initial?.latitude,
                                        longitude: widget.initial?.longitude,
                                        startTime: _parseTime(_startTimeCtrl.text, widget.initial?.startTime),
                                        endTime: _parseTime(_endTimeCtrl.text, widget.initial?.endTime),
                                        durationMinutes: widget.initial?.durationMinutes,
                                        costRub: double.tryParse(
                                          _costCtrl.text
                                              .trim()
                                              .replaceAll(' ', '')
                                              .replaceAll('\u00A0', '')
                                              .replaceAll(',', '.'),
                                        ),
                                        referenceNumber: null,
                                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                                        websiteUrl: null,
                                        rating: widget.initial?.rating,
                                        documentKey: _docCtrl.text.trim().isEmpty ? null : _docCtrl.text.trim(),
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
}

class _BottomMenu extends StatelessWidget {
  final int currentIndex;
  final bool lightStyle;
  final ValueChanged<int> onTap;

  const _BottomMenu({
    required this.currentIndex,
    required this.onTap,
    this.lightStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Рекомендации', 'Маршрут', 'Бюджет', 'Документы'];
    const icons = [
      Icons.auto_awesome,
      Icons.route,
      Icons.account_balance_wallet,
      Icons.description,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == currentIndex;
          final inactiveColor = Colors.white.withOpacity(0.72);
          final activeColor = const Color(0xFFD7E37A);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(index),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF242424)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[index],
                        size: 19,
                        color: selected ? activeColor : inactiveColor,
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 12,
                        child: Center(
                          child: Text(
                            labels[index],
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected ? activeColor : inactiveColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TimelineStageItem {
  final TripStage stage;
  final int startMin;
  final int endMin;
  final Color color;

  const _TimelineStageItem({
    required this.stage,
    required this.startMin,
    required this.endMin,
    required this.color,
  });
}

enum _StageDetailsAction { edit, copy, delete }

class _RouteTimeline extends StatefulWidget {
  final List<_TimelineStageItem> items;
  final ValueChanged<TripStage> onTapStage;
  final Future<void> Function(TripStage stage, int startMin, int endMin)?
      onDragStageEnd;

  const _RouteTimeline({
    required this.items,
    required this.onTapStage,
    this.onDragStageEnd,
  });

  @override
  State<_RouteTimeline> createState() => _RouteTimelineState();
}

class _RouteTimelineState extends State<_RouteTimeline> {
  static const int _startHour = 0;
  static const int _endHour = 24;
  static const double _pxPerHour = 56;
  static const double _timeColumnWidth = 52;
  static const double _dragSnapMinutes = 15;

  final Map<int, int> _dragOffsetByStageId = <int, int>{};
  final Map<int, double> _dragRawOffsetMinutesByStageId = <int, double>{};
  final Set<int> _draggingStageIds = <int>{};
  int? _activeDragStageId;
  final ScrollController _scrollController = ScrollController();
  String _itemsSignature = '';

  @override
  void initState() {
    super.initState();
    _itemsSignature = _buildItemsSignature(widget.items);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFirstStage(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _RouteTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeDragStageId != null &&
        !widget.items.any((e) => e.stage.id == _activeDragStageId)) {
      _activeDragStageId = null;
    }
    final nextSig = _buildItemsSignature(widget.items);
    if (nextSig != _itemsSignature) {
      _itemsSignature = nextSig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstStage(animate: false);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _snapToQuarterHour(int minutes) {
    final snapped = (minutes / _dragSnapMinutes).round() * _dragSnapMinutes;
    return snapped.toInt();
  }

  ({int start, int end}) _windowWithOffset(_TimelineStageItem item) {
    final offset = _dragOffsetByStageId[item.stage.id] ?? 0;
    final duration = (item.endMin - item.startMin).clamp(15, 24 * 60);
    var start = item.startMin + offset;
    start = start.clamp(0, 24 * 60 - duration);
    final end = (start + duration).clamp(start + 15, 24 * 60);
    return (start: start, end: end);
  }

  String _buildItemsSignature(List<_TimelineStageItem> items) {
    if (items.isEmpty) return 'empty';
    final sorted = [...items]..sort((a, b) => a.stage.id.compareTo(b.stage.id));
    return sorted
        .map((e) => '${e.stage.id}:${e.startMin}:${e.endMin}')
        .join('|');
  }

  void _scrollToFirstStage({required bool animate}) {
    if (!_scrollController.hasClients || widget.items.isEmpty) return;
    final starts = widget.items.map((e) => _windowWithOffset(e).start).toList()..sort();
    final firstStart = starts.first;
    const verticalInset = 8.0;
    final target = (verticalInset + (firstStart / 60.0) * _pxPerHour - 8).clamp(0.0, double.infinity);
    final max = _scrollController.position.maxScrollExtent;
    final offset = target > max ? max : target;
    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayStart = _startHour * 60;
    final dayEnd = _endHour * 60;
    const verticalInset = 8.0;

    final visible = widget.items.where((item) {
      final win = _windowWithOffset(item);
      return win.end > dayStart && win.start < dayEnd;
    }).toList()
      ..sort((a, b) {
        final aw = _windowWithOffset(a);
        final bw = _windowWithOffset(b);
        return aw.start.compareTo(bw.start);
      });

    final layout = <_TimelineStageItem, int>{};
    final clusterByItem = <_TimelineStageItem, int>{};
    final clusterMaxColumns = <int, int>{};
    final active = <_TimelineStageItem>[];
    var clusterId = -1;

    for (final item in visible) {
      final iw = _windowWithOffset(item);
      active.removeWhere((a) {
        final aw = _windowWithOffset(a);
        return aw.end <= iw.start;
      });

      if (active.isEmpty) {
        clusterId += 1;
      }

      final usedCols = active.map((a) => layout[a]!).toSet();
      var col = 0;
      while (usedCols.contains(col)) {
        col += 1;
      }

      layout[item] = col;
      clusterByItem[item] = clusterId;
      active.add(item);

      final currentMax = clusterMaxColumns[clusterId] ?? 1;
      if (col + 1 > currentMax) {
        clusterMaxColumns[clusterId] = col + 1;
      } else {
        clusterMaxColumns[clusterId] = currentMax;
      }
    }

    final totalHours = _endHour - _startHour;
    final timelineHeight = totalHours * _pxPerHour;
    final canvasHeight = timelineHeight + verticalInset * 2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: canvasHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentLeft = _timeColumnWidth + 6;
              final contentWidth =
                  (constraints.maxWidth - contentLeft - 8).clamp(120, 1200).toDouble();
              const gap = 6.0;

              return Stack(
                children: [
                  for (var hour = _startHour; hour <= _endHour; hour++) ...[
                    Positioned(
                      top: verticalInset + (hour - _startHour) * _pxPerHour - 8,
                      left: 0,
                      width: _timeColumnWidth,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      top: verticalInset + (hour - _startHour) * _pxPerHour,
                      left: _timeColumnWidth + 8,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                  for (final item in visible)
                    KeyedSubtree(
                      key: ValueKey<int>(item.stage.id),
                      child: Builder(
                        builder: (_) {
                          final clusterId = clusterByItem[item] ?? 0;
                          final columnsInCluster = clusterMaxColumns[clusterId] ?? 1;
                          final blockWidth =
                              (contentWidth - gap * (columnsInCluster - 1)) /
                                  columnsInCluster;
                          final win = _windowWithOffset(item);
                          return Positioned(
                            top: verticalInset +
                                ((win.start - dayStart) / 60) * _pxPerHour +
                                2,
                            left: contentLeft + (layout[item]! * (blockWidth + gap)),
                            width: blockWidth,
                            height: (((win.end - win.start) / 60) * _pxPerHour)
                                .clamp(34, timelineHeight),
                            child: GestureDetector(
                            onVerticalDragStart: (_) {
                              if (_activeDragStageId != null &&
                                  _activeDragStageId != item.stage.id) {
                                return;
                              }
                              setState(() {
                                _activeDragStageId = item.stage.id;
                                _draggingStageIds.add(item.stage.id);
                                _dragRawOffsetMinutesByStageId[item.stage.id] =
                                    (_dragOffsetByStageId[item.stage.id] ?? 0).toDouble();
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              if (_activeDragStageId != item.stage.id) return;
                              final currentRaw =
                                  _dragRawOffsetMinutesByStageId[item.stage.id] ?? 0.0;
                              final nextRaw =
                                  currentRaw + (details.delta.dy / _pxPerHour * 60.0);
                              final next = _snapToQuarterHour(nextRaw.round());
                              final duration = (item.endMin - item.startMin).clamp(15, 24 * 60);
                              final bounded = next.clamp(
                                -item.startMin,
                                (24 * 60 - duration) - item.startMin,
                              );
                              setState(() {
                                _dragRawOffsetMinutesByStageId[item.stage.id] = nextRaw;
                                _dragOffsetByStageId[item.stage.id] = bounded;
                              });
                            },
                            onVerticalDragEnd: (_) async {
                              if (_activeDragStageId != item.stage.id) return;
                              final offset = _dragOffsetByStageId[item.stage.id] ?? 0;
                              final duration = (item.endMin - item.startMin).clamp(15, 24 * 60);
                              final start = (item.startMin + offset).clamp(0, 24 * 60 - duration);
                              final end = (start + duration).clamp(start + 15, 24 * 60);
                              if (widget.onDragStageEnd != null) {
                                await widget.onDragStageEnd!(item.stage, start, end);
                              }
                              setState(() {
                                _draggingStageIds.remove(item.stage.id);
                                _dragOffsetByStageId.remove(item.stage.id);
                                _dragRawOffsetMinutesByStageId.remove(item.stage.id);
                                if (_activeDragStageId == item.stage.id) {
                                  _activeDragStageId = null;
                                }
                              });
                            },
                            onVerticalDragCancel: () {
                              if (_activeDragStageId != item.stage.id) return;
                              setState(() {
                                _draggingStageIds.remove(item.stage.id);
                                _dragOffsetByStageId.remove(item.stage.id);
                                _dragRawOffsetMinutesByStageId.remove(item.stage.id);
                                _activeDragStageId = null;
                              });
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => widget.onTapStage(item.stage),
                              child: Opacity(
                                opacity: _draggingStageIds.contains(item.stage.id) ? 0.9 : 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: item.color.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: item.color.withOpacity(0.6)),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final canShowTime = constraints.maxHeight >= 52;
                                      final verticalPadding = canShowTime ? 6.0 : 4.0;
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: verticalPadding,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: canShowTime
                                              ? MainAxisAlignment.start
                                              : MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.stage.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                height: 1.15,
                                              ),
                                            ),
                                            if (canShowTime) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_hhmm(win.start)} - ${_hhmm(win.end)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RouteDayStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final bool compact;
  final bool numberedOnly;

  const _RouteDayStrip({
    required this.days,
    required this.selectedDay,
    required this.onDayTap,
    this.compact = false,
    this.numberedOnly = false,
  });

  String _weekday(DateTime day) {
    const map = <int, String>{
      DateTime.monday: 'ПН',
      DateTime.tuesday: 'ВТ',
      DateTime.wednesday: 'СР',
      DateTime.thursday: 'ЧТ',
      DateTime.friday: 'ПТ',
      DateTime.saturday: 'СБ',
      DateTime.sunday: 'ВС',
    };
    return map[day.weekday] ?? '';
  }

  String _month(DateTime day) {
    const map = <int, String>{
      1: 'ЯНВ',
      2: 'ФЕВ',
      3: 'МАР',
      4: 'АПР',
      5: 'МАЙ',
      6: 'ИЮН',
      7: 'ИЮЛ',
      8: 'АВГ',
      9: 'СЕН',
      10: 'ОКТ',
      11: 'НОЯ',
      12: 'ДЕК',
    };
    return map[day.month] ?? '';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = compact ? 46.0 : 56.0;
    final itemHeight = compact ? 64.0 : 78.0;
    final dayFont = compact ? 16.0 : 21.0;
    final weekFont = compact ? 9.0 : 10.0;
    final radius = compact ? 16.0 : 20.0;
    final vertical = compact ? 6.0 : 8.0;

    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final day = days[index];
          final selected = _sameDay(day, selectedDay);
          return InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: () => onDayTap(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: itemWidth,
              padding: EdgeInsets.symmetric(vertical: vertical),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF222715)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD7E37A).withOpacity(0.75)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    numberedOnly ? '${index + 1}' : day.day.toString(),
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFD7E37A)
                          : Colors.white.withOpacity(0.9),
                      fontSize: dayFont,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  if (!numberedOnly) ...[
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      _month(day),
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFD7E37A).withOpacity(0.9)
                            : Colors.white.withOpacity(0.62),
                        fontSize: weekFont,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      _weekday(day),
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFD7E37A).withOpacity(0.9)
                            : Colors.white.withOpacity(0.62),
                        fontSize: weekFont,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripSettingsResult {
  final _TripSettingsAction action;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int? plannedDays;
  final String cardColor;
  final String cardBackground;
  final String cardIcon;

  const _TripSettingsResult({
    this.action = _TripSettingsAction.save,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.plannedDays,
    required this.cardColor,
    required this.cardBackground,
    required this.cardIcon,
  });
}

enum _TripSettingsAction { save, delete, archive }

class _TripSettingsDialog extends StatefulWidget {
  final String initialTitle;
  final String city;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final int? initialPlannedDays;
  final String initialCardColor;
  final String initialCardBackground;
  final String initialCardIcon;

  const _TripSettingsDialog({
    required this.initialTitle,
    required this.city,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialPlannedDays,
    required this.initialCardColor,
    required this.initialCardBackground,
    required this.initialCardIcon,
  });

  @override
  State<_TripSettingsDialog> createState() => _TripSettingsDialogState();
}

class _TripSettingsDialogState extends State<_TripSettingsDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _daysCtrl;
  late bool _usePlannedDays;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedCardColor;
  late String _selectedCardBackground;
  late String _selectedCardIcon;

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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _daysCtrl = TextEditingController(
      text: (widget.initialPlannedDays ?? '').toString(),
    );
    _usePlannedDays =
        widget.initialPlannedDays != null && widget.initialPlannedDays! > 0;
    final now = DateTime.now();
    _startDate = widget.initialStartDate ?? DateTime(now.year, now.month, now.day);
    _endDate = widget.initialEndDate ?? _startDate;
    _selectedCardColor = widget.initialCardColor;
    _selectedCardBackground = widget.initialCardBackground;
    _selectedCardIcon = widget.initialCardIcon;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('ru', 'RU'),
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

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    int? plannedDays;
    DateTime start = _startDate;
    DateTime end = _endDate;
    if (_usePlannedDays) {
      final parsed = int.tryParse(_daysCtrl.text.trim());
      if (parsed == null || parsed <= 0) return;
      plannedDays = parsed;
      end = start.add(Duration(days: parsed - 1));
    }
    if (end.isBefore(start)) return;

    Navigator.of(context).pop(
      _TripSettingsResult(
        action: _TripSettingsAction.save,
        title: title,
        startDate: start,
        endDate: end,
        plannedDays: plannedDays,
        cardColor: _selectedCardColor,
        cardBackground: _selectedCardBackground,
        cardIcon: _selectedCardIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFFD7E37A);
    return Dialog(
      backgroundColor: const Color(0xFF1E1F24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 430,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Редактировать маршрут',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Название',
                  alignLabelWithHint: true,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Город: ${widget.city}',
                textAlign: TextAlign.left,
                style: TextStyle(color: Colors.white.withOpacity(0.75)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  _SettingsChip(
                    label: 'Точные даты',
                    selected: !_usePlannedDays,
                    onTap: () => setState(() => _usePlannedDays = false),
                  ),
                  _SettingsChip(
                    label: 'Количество дней',
                    selected: _usePlannedDays,
                    onTap: () => setState(() => _usePlannedDays = true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_usePlannedDays)
                TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Количество дней',
                    alignLabelWithHint: true,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                  ),
                )
              else
                InkWell(
                  onTap: _pickRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      '${_fmtDate(_startDate)} вЂ” ${_fmtDate(_endDate)}',
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Оформление карточки',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Geologica',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _cardColors.map((hex) {
                  final selected = _selectedCardColor == hex;
                  final color = _hexToColor(hex);
                  return InkWell(
                    onTap: () => setState(() => _selectedCardColor = hex),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white.withOpacity(0.22),
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const _SizedBoxH8(),
              SizedBox(
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
                        width: 58 * 2.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFD7E37A)
                                : Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: _TripCardPreviewArt(
                            color: _hexToColor(_selectedCardColor),
                            background: bg,
                            icon: _iconByKey(_selectedCardIcon),
                            titleText: widget.city,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cardIcons.map((key) {
                  final selected = _selectedCardIcon == key;
                  return InkWell(
                    onTap: () => setState(() => _selectedCardIcon = key),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD7E37A)
                              : Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: Icon(_iconByKey(key), size: 18, color: Colors.white),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1D222A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: const BorderSide(color: Color(0xFF3A4751)),
                          ),
                          title: const Text(
                            'Архивировать путешествие?',
                            style: TextStyle(
                              color: Color(0xFFF2F4F8),
                              fontFamily: 'Geologica',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: const Text(
                            'Путешествие исчезнет с главной страницы и останется только в списке поездок профиля.',
                            style: TextStyle(
                              color: Color(0xFFB7BDC8),
                              fontFamily: 'Geologica',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text(
                                'Отмена',
                                style: TextStyle(
                                  color: Color(0xFFB7BDC8),
                                  fontFamily: 'Geologica',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD7E37A),
                                foregroundColor: const Color(0xFF151515),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Архивировать',
                                style: TextStyle(
                                  fontFamily: 'Geologica',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true || !context.mounted) return;
                      Navigator.of(context).pop(
                        _TripSettingsResult(
                          action: _TripSettingsAction.archive,
                          title: _titleCtrl.text.trim().isEmpty
                              ? widget.initialTitle
                              : _titleCtrl.text.trim(),
                          startDate: _startDate,
                          endDate: _endDate,
                          plannedDays: _usePlannedDays
                              ? int.tryParse(_daysCtrl.text.trim())
                              : null,
                          cardColor: _selectedCardColor,
                          cardBackground: _selectedCardBackground,
                          cardIcon: _selectedCardIcon,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.28)),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('Архивировать'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _TripSettingsResult(
                          action: _TripSettingsAction.delete,
                          title: widget.initialTitle,
                          startDate: _startDate,
                          endDate: _endDate,
                          plannedDays: widget.initialPlannedDays,
                          cardColor: _selectedCardColor,
                          cardBackground: _selectedCardBackground,
                          cardIcon: _selectedCardIcon,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.28)),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Удалить'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: const Color(0xFF151515),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

class _SettingsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFFD7E37A);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF222715) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? green.withOpacity(0.72) : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? green : Colors.white.withOpacity(0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TripCardPreviewArt extends StatelessWidget {
  final Color color;
  final String background;
  final IconData icon;
  final String titleText;

  const _TripCardPreviewArt({
    required this.color,
    required this.background,
    required this.icon,
    required this.titleText,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
              left: 6,
              right: 6,
              top: 6,
              child: Text(
                background == 'brand_text'
                    ? 'Тур2Тур'
                    : (titleText.trim().isEmpty ? 'Город' : titleText.trim()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Geologica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.34),
                  height: 1.0,
                ),
              ),
            ),
          Positioned(
            right: 7,
            top: 6,
            child: Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundShape(String key, Color color) {
    switch (key) {
      case 'waves':
        return Positioned(
          left: -20,
          top: 6,
          child: Container(
            width: 100,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.26), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        );
      case 'mountains':
        return Positioned.fill(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              height: 30,
              width: double.infinity,
              child: CustomPaint(
                painter: _MountPainter(color.withOpacity(0.2)),
              ),
            ),
          ),
        );
      case 'sunset':
        return Positioned(
          left: -8,
          top: 5,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.26),
              shape: BoxShape.circle,
            ),
          ),
        );
      case 'aurora':
        return Positioned.fill(
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
          left: -12,
          top: 10,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
          ),
        );
    }
  }
}

class _SizedBoxH8 extends StatelessWidget {
  const _SizedBoxH8();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 8);
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
  bool shouldRepaint(covariant _MountPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TripRouteMapPage extends StatefulWidget {
  final String tripTitle;
  final String destinationCity;
  final List<Map<String, String>> stagePoints;
  final DateTime? startDate;
  final DateTime? endDate;
  final TripsRepo tripsRepo;

  const _TripRouteMapPage({
    required this.tripTitle,
    required this.destinationCity,
    required this.stagePoints,
    this.startDate,
    this.endDate,
    required this.tripsRepo,
  });

  @override
  State<_TripRouteMapPage> createState() => _TripRouteMapPageState();
}

class _TripRouteMapPageState extends State<_TripRouteMapPage> {
  static const _yandexSuggestApiKey = 'e0dc35bf-6cce-44bf-a462-8f7bab2f8b92';
  static const _yandexGeocoderApiKey = 'acf6e354-8f9c-4163-9d37-54bf33ee956b';
  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocusNode;
  late String _mapQuery;
  final Dio _suggestDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  Timer? _suggestDebounce;
  bool _suggestLoading = false;
  bool _showSuggestions = false;
  List<_MapSuggestItem> _suggestions = const [];
  String _lastSuggestQuery = '';
  bool _applyingSuggestionSelection = false;
  String? _tripBoundsBbox;
  double? _tripCenterLat;
  double? _tripCenterLon;
  String? _selectedSuggestionTitle;
  double? _searchPointLat;
  double? _searchPointLon;

  @override
  void initState() {
    super.initState();
    _mapQuery = '';
    _searchCtrl = TextEditingController(text: _mapQuery);
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _resolveTripBounds();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _suggestDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _suggestDio.close(force: true);
    super.dispose();
  }


  void _onSearchFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus) {
      setState(() => _showSuggestions = true);
      _onSearchChanged();
      return;
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (!_applyingSuggestionSelection &&
        _selectedSuggestionTitle != null &&
        query != _mapQuery.trim()) {
      _selectedSuggestionTitle = null;
    }
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadSuggest(query);
    });
  }

  Future<void> _loadSuggest(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _suggestLoading = false;
        _lastSuggestQuery = '';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _suggestLoading = true;
      _lastSuggestQuery = normalized;
    });

    try {
      final response = await _suggestDio.get(
        'https://suggest-maps.yandex.ru/v1/suggest',
        queryParameters: <String, dynamic>{
          'apikey': _yandexSuggestApiKey,
          'text': normalized,
          'lang': 'ru_RU',
          'results': 5,
          'print_address': 1,
          if ((_tripBoundsBbox ?? '').isNotEmpty) 'bbox': _tripBoundsBbox,
          if ((_tripBoundsBbox ?? '').isNotEmpty) 'strict_bounds': 1,
        },
      );

      final data = response.data;
      final results = (data is Map<String, dynamic> ? data['results'] : null);
      final parsed = <_MapSuggestItem>[];
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

          final displayText = map['display_text'];
          if ((title).trim().isEmpty && displayText != null) {
            title = '$displayText';
          }

          title = _normalizeSuggestText(title);
          subtitle = _normalizeSuggestText(subtitle);
          if (title.isEmpty && subtitle.isEmpty) continue;
          final uri = _normalizeSuggestText('${map['uri'] ?? ''}');
          final kind = _normalizeSuggestText('${map['kind'] ?? map['type'] ?? ''}').toLowerCase();
          final searchTextRaw = _normalizeSuggestText('${map['search_text'] ?? ''}');
          final displayTextRaw = _normalizeSuggestText('${map['display_text'] ?? ''}');
          final isBiz = _isBusinessSuggest(
            title: title,
            subtitle: subtitle,
            uri: uri,
            kind: kind,
            searchText: searchTextRaw,
            displayText: displayTextRaw,
          );
          double? centerLat;
          double? centerLon;
          final centerRaw = map['center'];
          if (centerRaw is List && centerRaw.length >= 2) {
            centerLon = (centerRaw[0] as num?)?.toDouble();
            centerLat = (centerRaw[1] as num?)?.toDouble();
          } else if (centerRaw is Map) {
            centerLon = (centerRaw['lon'] as num?)?.toDouble() ??
                double.tryParse('${centerRaw['lon'] ?? ''}');
            centerLat = (centerRaw['lat'] as num?)?.toDouble() ??
                double.tryParse('${centerRaw['lat'] ?? ''}');
          } else {
            final posRaw = '${map['pos'] ?? ''}'.trim();
            final parts = posRaw.split(' ');
            if (parts.length == 2) {
              centerLon = double.tryParse(parts[0]);
              centerLat = double.tryParse(parts[1]);
            }
          }
          parsed.add(
            _MapSuggestItem(
              title: title.isEmpty ? subtitle : title,
              subtitle: subtitle,
              searchText: searchTextRaw,
              displayText: displayTextRaw,
              centerLat: centerLat,
              centerLon: centerLon,
              isBusiness: isBiz,
            ),
          );
          if (parsed.length >= 5) break;
        }
      }

      if (!mounted || _lastSuggestQuery != normalized) return;
      setState(() {
        _suggestions = parsed;
        _suggestLoading = false;
      });
    } catch (_) {
      if (!mounted || _lastSuggestQuery != normalized) return;
      setState(() {
        _suggestions = const [];
        _suggestLoading = false;
      });
    }
  }

  void _onSuggestionTap(_MapSuggestItem item) {
    final query = item.addressQuery;
    _selectedSuggestionTitle = item.stageTitle;
    _searchPointLat = item.centerLat;
    _searchPointLon = item.centerLon;
    _suggestDebounce?.cancel();
    _applyingSuggestionSelection = true;
    _searchCtrl.text = query;
    _searchCtrl.selection = TextSelection.collapsed(offset: _searchCtrl.text.length);
    setState(() {
      _mapQuery = '';
    });
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _mapQuery = query;
      });
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _showSuggestions = false;
        _suggestions = const [];
        _suggestLoading = false;
      });
      _searchFocusNode.unfocus();
      _applyingSuggestionSelection = false;
    });
  }

  String _normalizeSuggestText(String input) {
    var out = input
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u2009', ' ')
        .replaceAll('\u200A', ' ')
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
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u2060', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Some suggest rows may still start with hidden unicode separators.
    while (out.isNotEmpty) {
      final code = out.codeUnitAt(0);
      final isAsciiSpace = code <= 0x20;
      final isUnicodeSpace = code == 0x00A0 ||
          code == 0x1680 ||
          (code >= 0x2000 && code <= 0x200A) ||
          code == 0x2028 ||
          code == 0x2029 ||
          code == 0x202F ||
          code == 0x205F ||
          code == 0x3000;
      final isFormat = code == 0x200B ||
          code == 0x200E ||
          code == 0x200F ||
          (code >= 0x202A && code <= 0x202E) ||
          (code >= 0x2066 && code <= 0x2069) ||
          code == 0x200C ||
          code == 0x200D ||
          code == 0x2060 ||
          code == 0xFEFF;
      if (!(isAsciiSpace || isUnicodeSpace || isFormat)) break;
      out = out.substring(1);
    }
    return out;
  }

  bool _looksLikeAddressText(String value) {
    final text = value.toLowerCase().trim();
    if (text.isEmpty) return false;
    final hasDigits = RegExp(r'\d').hasMatch(text);
    final addressWords = RegExp(
      r'\b(ул\.?|улиц|просп|пр-т|пр\.?|пер\.?|переул|пл\.?|площад|наб\.?|набереж|шоссе|ш\.?|бульв|бул\.?|д\.?|дом|корп\.?|корпус|стр\.?|строен|кв\.?|квартир)\b',
      caseSensitive: false,
    );
    return addressWords.hasMatch(text) || hasDigits;
  }

  bool _isBusinessSuggest({
    required String title,
    required String subtitle,
    required String uri,
    required String kind,
    required String searchText,
    required String displayText,
  }) {
    if (uri.trim().isNotEmpty) return true;
    if (kind.contains('biz') || kind.contains('business') || kind.contains('org')) {
      return true;
    }
    final titleLooksAddress = _looksLikeAddressText(title);
    final searchLooksAddress = _looksLikeAddressText(searchText);
    final displayLooksAddress = _looksLikeAddressText(displayText);
    // If title is not address-like and subtitle is present, most often this is organization.
    if (!titleLooksAddress && subtitle.trim().isNotEmpty) return true;
    // If the entered/result text clearly looks like an address, classify as geo-address.
    if (searchLooksAddress || displayLooksAddress || titleLooksAddress) return false;
    // Conservative fallback: treat as business only when we have a distinct title + subtitle pair.
    return title.trim().isNotEmpty && subtitle.trim().isNotEmpty;
  }

  Future<void> _resolveTripBounds() async {
    final city = widget.destinationCity.trim();
    if (city.isEmpty) return;
    final core = city.split(',').first.trim();
    final candidates = <String>[
      city,
      if (core.isNotEmpty) core,
      '$city, Россия',
      if (core.isNotEmpty) '$core, Россия',
    ];
    for (final candidate in candidates) {
      try {
        final response = await _suggestDio.get(
          'https://geocode-maps.yandex.ru/v1/',
          queryParameters: <String, dynamic>{
            'apikey': _yandexGeocoderApiKey,
            'geocode': candidate,
            'format': 'json',
            'results': 1,
            'lang': 'ru_RU',
          },
        );
        final data = response.data;
        if (data is! Map<String, dynamic>) continue;
        final members = (((data['response'] as Map?)?['GeoObjectCollection'] as Map?)
                ?['featureMember'])
            as List?;
        if (members == null || members.isEmpty) continue;
        final geoObject = ((members.first as Map?)?['GeoObject']) as Map?;
        final envelope = (((geoObject?['boundedBy'] as Map?)?['Envelope']) as Map?);
        final lowerCorner = _normalizeSuggestText('${envelope?['lowerCorner'] ?? ''}');
        final upperCorner = _normalizeSuggestText('${envelope?['upperCorner'] ?? ''}');
        if (lowerCorner.isEmpty || upperCorner.isEmpty) continue;

        final lower = lowerCorner.split(' ');
        final upper = upperCorner.split(' ');
        if (lower.length != 2 || upper.length != 2) continue;
        final bbox = '${lower[0]},${lower[1]}~${upper[0]},${upper[1]}';
        if (!mounted) return;
        setState(() {
          _tripBoundsBbox = bbox;
          final lon = double.tryParse(lower[0]);
          final lat = double.tryParse(lower[1]);
          final lon2 = double.tryParse(upper[0]);
          final lat2 = double.tryParse(upper[1]);
          if (lon != null && lon2 != null && lat != null && lat2 != null) {
            _tripCenterLon = (lon + lon2) / 2.0;
            _tripCenterLat = (lat + lat2) / 2.0;
          }
        });
        return;
      } catch (_) {
        // try next candidate
      }
    }

    try {
      final fromPlaces = await widget.tripsRepo.suggestCities(city, limit: 1);
      if (fromPlaces.isEmpty) return;
      final lat = fromPlaces.first.latitude;
      final lon = fromPlaces.first.longitude;
      if (lat == null || lon == null) return;
      // Practical bounds for city-scoped suggest fallback.
      const lonSpan = 1.2;
      const latSpan = 0.8;
      final minLon = (lon - lonSpan).clamp(-180.0, 180.0);
      final maxLon = (lon + lonSpan).clamp(-180.0, 180.0);
      final minLat = (lat - latSpan).clamp(-90.0, 90.0);
      final maxLat = (lat + latSpan).clamp(-90.0, 90.0);
      if (!mounted) return;
      setState(() {
        _tripCenterLat = lat;
        _tripCenterLon = lon;
        _tripBoundsBbox = '$minLon,$minLat~$maxLon,$maxLat';
      });
    } catch (_) {
      // no-op, keep unbounded fallback
    }
  }

  void _submitSearch() {
    final value = _searchCtrl.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите адрес для поиска')),
      );
      return;
    }
    setState(() {
      _selectedSuggestionTitle = null;
      _searchPointLat = null;
      _searchPointLon = null;
      _showSuggestions = false;
      _suggestions = const [];
      _mapQuery = '';
    });
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _mapQuery = value;
      });
    });
    _searchFocusNode.unfocus();
  }

  String _fmtDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d.$m.$y';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = (widget.startDate != null && widget.endDate != null)
        ? '${_fmtDate(widget.startDate!)} - ${_fmtDate(widget.endDate!)}'
        : null;

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
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('К этапам'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.tripTitle,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (dateLabel != null)
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.14)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _submitSearch(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Введите адрес',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _submitSearch,
                              child: const Text('Найти'),
                            ),
                          ],
                        ),
                      ),
                      if (_showSuggestions &&
                          (_suggestLoading || _suggestions.isNotEmpty))
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D27).withOpacity(0.96),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: _suggestLoading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Ищем подсказки...',
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < _suggestions.length; i++) ...[
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _onSuggestionTap(_suggestions[i]),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _suggestions[i].title,
                                                    textAlign: TextAlign.left,
                                                    textDirection: TextDirection.ltr,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (_suggestions[i]
                                                      .subtitle
                                                      .trim()
                                                      .isNotEmpty)
                                                    Text(
                                                      _suggestions[i].subtitle,
                                                      textAlign: TextAlign.left,
                                                      textDirection: TextDirection.ltr,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.72),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (i < _suggestions.length - 1)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Colors.white.withOpacity(0.08),
                                        ),
                                    ],
                                  ],
                                ),
                        ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: YandexCityMap(
                            city: widget.destinationCity,
                            cityCenterLat: _tripCenterLat,
                            cityCenterLon: _tripCenterLon,
                            searchQuery: _mapQuery,
                            searchPointLat: _searchPointLat,
                            searchPointLon: _searchPointLon,
                            onAddRouteFromSearch: (address) {
                              Navigator.of(context).pop(
                                _MapAddStagePayload(
                                  address: address.trim(),
                                  title: (_selectedSuggestionTitle ?? '').trim(),
                                ),
                              );
                            },
                            stagePoints: widget.stagePoints,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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

class _MapSuggestItem {
  final String title;
  final String subtitle;
  final String searchText;
  final String displayText;
  final double? centerLat;
  final double? centerLon;
  final bool isBusiness;

  const _MapSuggestItem({
    required this.title,
    required this.subtitle,
    this.searchText = '',
    this.displayText = '',
    this.centerLat,
    this.centerLon,
    this.isBusiness = false,
  });

  String get fullSearchText {
    final t = title.trim();
    final s = subtitle.trim();
    if (t.isEmpty) return s;
    if (s.isEmpty) return t;
    return '$t, $s';
  }

  String get addressQuery {
    if (!isBusiness) {
      final titleTrim = title.trim();
      final subtitleTrim = subtitle.trim();
      final searchTrim = searchText.trim();
      final displayTrim = displayText.trim();
      if (titleTrim.isNotEmpty && subtitleTrim.isNotEmpty) {
        return '$titleTrim, $subtitleTrim';
      }
      if (displayTrim.isNotEmpty) return displayTrim;
      if (searchTrim.isNotEmpty) return searchTrim;
      if (titleTrim.isNotEmpty) return titleTrim;
      return subtitleTrim;
    }

    final s = subtitle.trim();
    if (s.isNotEmpty) {
      if (s.contains('·')) {
        final parts = s
            .split('·')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          return parts.last;
        }
      }
      return s;
    }
    return title.trim();
  }

  String get stageTitle {
    if (!isBusiness) return '';
    return title.trim();
  }
}

class _MapAddStagePayload {
  final String address;
  final String title;

  const _MapAddStagePayload({
    required this.address,
    required this.title,
  });
}

class _StageVisualConfig {
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StageVisualConfig({
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}

class _StageDetailsPage extends StatelessWidget {
  final TripStage stage;
  final String typeLabel;
  final String subtypeLabel;
  final String? timeRange;
  final VoidCallback? onOpenDocument;

  const _StageDetailsPage({
    required this.stage,
    required this.typeLabel,
    required this.subtypeLabel,
    required this.timeRange,
    this.onOpenDocument,
  });

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _line(String label, String? value) {
    final data = (value ?? '').trim();
    if (data.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: $data',
        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
      ),
    );
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
                              'Детали этапа',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stage.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _infoChip(typeLabel),
                                    _infoChip(subtypeLabel),
                                    if (timeRange != null) _infoChip(timeRange!),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _actionIcon(
                                      context,
                                      icon: Icons.edit_rounded,
                                      onTap: () => Navigator.of(context).pop(
                                        _StageDetailsAction.edit,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _actionIcon(
                                      context,
                                      icon: Icons.copy_rounded,
                                      onTap: () => Navigator.of(context).pop(
                                        _StageDetailsAction.copy,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _actionIcon(
                                      context,
                                      icon: Icons.delete_outline_rounded,
                                      onTap: () => Navigator.of(context).pop(
                                        _StageDetailsAction.delete,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _line('Адрес / место', stage.address),
                                _line('Откуда', stage.startLocation),
                                _line('Куда', stage.endLocation),
                                _line('Стоимость', stage.costRub == null ? null : '${stage.costRub} руб.'),
                                _line('Комментарий', stage.notes),
                                if ((stage.documentKey ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: onOpenDocument,
                                    icon: const Icon(Icons.attach_file_rounded),
                                    label: const Text('Открыть документ'),
                                  ),
                                ],
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

  Widget _actionIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
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

class _RouteAssistantTextDialog extends StatefulWidget {
  const _RouteAssistantTextDialog();

  @override
  State<_RouteAssistantTextDialog> createState() => _RouteAssistantTextDialogState();
}

class _RouteAssistantTextDialogState extends State<_RouteAssistantTextDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1D222A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB6A1FF).withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFB6A1FF),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Быстрый ввод',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(
                  fontFamily: 'Geologica',
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  hintText: 'Например: в 19:00 хочу поужинать в White Rabbit, потрачу около 2500 руб, важно место с красивым видом',
                  hintStyle: TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white.withOpacity(0.45),
                    fontWeight: FontWeight.w300,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white70,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB6A1FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text(
                      'Заполнить',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}








