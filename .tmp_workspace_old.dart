import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../documents/documents_repo.dart';
import '../interactions/interactions_repo.dart';
import '../preferences/preferences_repo.dart';
import '../profile/profile_repo.dart';
import '../recommendations/recommendations_repo.dart';
import 'widgets/pdf_memory_preview.dart';
import 'widgets/yandex_city_map.dart';
import 'trip_recommendations_tab.dart';
import 'trips_repo.dart';

class TripWorkspacePage extends StatefulWidget {
  final String tripTitle;
  final int? tripId;
  final String? destinationCity;
  final DateTime? startDate;
  final DateTime? endDate;
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
  });

  @override
  State<TripWorkspacePage> createState() => _TripWorkspacePageState();
}

class _TripWorkspacePageState extends State<TripWorkspacePage> {
  static const _accent = Color(0xFFD7E37A);

  int _currentIndex = 1;
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

  String _sortMode = 'none';
  String _categoryFilter = 'all';

  List<TripDocument> _documents = const [];
  bool _documentsLoading = false;
  bool _uploadingDocument = false;
  bool _bucketReady = false;

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
    'entertainment': 'Развлечения',
    'other': 'Другое',
  };

  static const _categoryColors = {
    'food': Color(0xFFFF8A65),
    'housing': Color(0xFFFFD54F),
    'transport': Color(0xFF4FC3F7),
    'entertainment': Color(0xFFBA68C8),
    'other': Color(0xFF90A4AE),
  };

  static const _stageTypeLabels = {
    'transport': 'Поездка',
    'place': 'Посещение места',
    'stay': 'Отдых / проживание',
    'food': 'Еда',
    'shopping': 'Шопинг',
    'activity': 'Активность',
  };

  static const _stageSubtypes = {
    'transport': [
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
    if (widget.tripId != null) {
      _loadExpenses();
      _loadStages();
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

  Future<void> _openAddStageDialog() async {
    if (widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У этого путешествия нет ID для добавления этапов'),
        ),
      );
      return;
    }

    final pickedType = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _StageTypePickerPage(stageTypeLabels: _stageTypeLabels),
      ),
    );
    if (pickedType == null || !mounted) return;
    final payload = await Navigator.of(context).push<_AddStagePayload>(
      MaterialPageRoute(
        builder: (_) => _StageFormPage(
          stageTypeLabels: _stageTypeLabels,
          stageSubtypes: _stageSubtypes,
          initialType: pickedType,
          routeDay: _ensureSelectedRouteDay(
            _selectedRouteDay,
            stages: [..._stages]..sort((a, b) => a.position.compareTo(b.position)),
          ),
          onUploadDocument: _pickAndUploadDocumentForStage,
        ),
      ),
    );
    if (payload == null) return;

    setState(() {
      _addingStage = true;
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

    final payload = await Navigator.of(context).push<_AddStagePayload>(
      MaterialPageRoute(
        builder: (_) => _StageFormPage(
          stageTypeLabels: _stageTypeLabels,
          stageSubtypes: _stageSubtypes,
          initialType: stage.stageType,
          onUploadDocument: _pickAndUploadDocumentForStage,
          initial: _AddStagePayload(
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить этап')),
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
          iconColor: Color(0xFF65E3D6),
          backgroundColor: Color(0x1A65E3D6),
          borderColor: Color(0x3365E3D6),
        );
      case 'place':
        return const _StageVisualConfig(
          iconColor: Color(0xFF9B8CFF),
          backgroundColor: Color(0x1A9B8CFF),
          borderColor: Color(0x339B8CFF),
        );
      case 'stay':
        return const _StageVisualConfig(
          iconColor: Color(0xFFFFC973),
          backgroundColor: Color(0x1AFFC973),
          borderColor: Color(0x33FFC973),
        );
      case 'food':
        return const _StageVisualConfig(
          iconColor: Color(0xFFFF78B2),
          backgroundColor: Color(0x1AFF78B2),
          borderColor: Color(0x33FF78B2),
        );
      case 'shopping':
        return const _StageVisualConfig(
          iconColor: Color(0xFFD989FF),
          backgroundColor: Color(0x1AD989FF),
          borderColor: Color(0x33D989FF),
        );
      case 'activity':
        return const _StageVisualConfig(
          iconColor: Color(0xFF58B8FF),
          backgroundColor: Color(0x1A58B8FF),
          borderColor: Color(0x3358B8FF),
        );
      case 'document':
        return const _StageVisualConfig(
          iconColor: Color(0xFF9DE46B),
          backgroundColor: Color(0x1A9DE46B),
          borderColor: Color(0x339DE46B),
        );
      default:
        return const _StageVisualConfig(
          iconColor: Color(0xFFE9D9FF),
          backgroundColor: Color(0x1AE9D9FF),
          borderColor: Color(0x33E9D9FF),
        );
    }
  }

  String _prettySubtype(String subtype) {
    const labels = <String, String>{
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
      if (!_bucketReady) {
        await widget.documentsRepo.ensureBucket();
        _bucketReady = true;
      }
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
      if (!_bucketReady) {
        await widget.documentsRepo.ensureBucket();
        _bucketReady = true;
      }
      final init = await widget.documentsRepo.uploadInit(
        tripId: widget.tripId!,
        fileName: targetFileName,
        contentType: contentType,
      );
      await widget.documentsRepo.uploadBytesToPresigned(
        uploadUrl: init.uploadUrl,
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
      return init.objectKey;
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
          title: const Text('Название документа'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Введите название',
              hintText: 'Например: Билет Москва-СПб',
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
              child: const Text('Отмена'),
            ),
            ElevatedButton(
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
    for (final stage in orderedStages) {
      final address = (stage.address ?? '').trim();
      if (address.isEmpty) continue;
      stagePoints.add({
        'title': stage.title.trim(),
        'address': address,
        'order': '$routeOrder',
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TripRouteMapPage(
          tripTitle: widget.tripTitle,
          destinationCity: city,
          stagePoints: stagePoints,
          startDate: widget.startDate,
          endDate: widget.endDate,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _currentIndex = 1;
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
                        mainAxisAlignment: MainAxisAlignment.end,
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
                            icon: const Icon(Icons.exit_to_app_rounded,
                                size: 18),
                            label: const Text('К поездкам'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.tripTitle,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
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
                                        tripTitle: widget.tripTitle,
                                        stages: _stages,
                                        onStagesChanged: _loadStages,
                                      ),
                      ),
                      const SizedBox(height: 14),
                      _BottomMenu(
                        currentIndex: _currentIndex,
                        lightStyle: false,
                        onTap: (index) {
                          setState(() {
                            _currentIndex = index;
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

  Widget _buildRouteCard(ColorScheme cs) {
    final ordered = [..._stages]..sort((a, b) => a.position.compareTo(b.position));
    final selectedDay = _ensureSelectedRouteDay(_selectedRouteDay, stages: ordered);
    final visibleStages = _filterStagesByDay(
      ordered,
      selectedDay,
      _tripDays(stages: ordered),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRouteMap(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withOpacity(0.44)),
                    backgroundColor: const Color(0xFF222715),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text(
                    'Маршрут на карте',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addingStage ? null : _openAddStageDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD7E37A),
                    foregroundColor: const Color(0xFF161616),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: _addingStage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_road_rounded, size: 16),
                  label: const Text(
                    'Добавить этап',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildRouteTimelineSection(stages: visibleStages)),
        ],
      ),
    );
  }

  Future<void> _openStageDetails(TripStage stage) async {
    final typeLabel = _stageTypeLabels[stage.stageType] ?? stage.stageType;
    final subtypeLabel = _prettySubtype(stage.subtype);
    final timeRange = _formatTimeRange(stage.startTime, stage.endTime);
    setState(() {
      _selectedStageId = stage.id;
    });
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StageDetailsPage(
          stage: stage,
          typeLabel: typeLabel,
          subtypeLabel: subtypeLabel,
          timeRange: timeRange,
          onOpenDocument: (stage.documentKey ?? '').isEmpty
              ? null
              : () => _openDocumentByKey(stage.documentKey!, stage.title),
        ),
      ),
    );
  }

  Future<void> _showStageActions(TripStage stage) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Редактировать'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Копировать'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openEditStageDialog(stage);
    } else if (action == 'copy') {
      await _copyStage(stage);
    } else if (action == 'delete') {
      await _deleteStage(stage);
    }
  }

  Widget _buildRouteTimelineSection({required List<TripStage> stages}) {
    if (_stagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stages.isEmpty) {
      return Center(
        child: Text(
          'На выбранный день нет этапов',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }

    final timed = <_TimelineStageItem>[];
    final withoutTime = <TripStage>[];
    for (final stage in stages) {
      final item = _toTimelineStage(stage);
      if (item == null) {
        withoutTime.add(stage);
      } else {
        timed.add(item);
      }
    }

    return Column(
      children: [
        if (withoutTime.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Без времени',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: withoutTime.map((stage) {
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openStageDetails(stage),
                onLongPress: () => _showStageActions(stage),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(
                    stage.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: timed.isEmpty
              ? Center(
                  child: Text(
                    'Добавьте время этапам, чтобы они появились на шкале',
                    style: TextStyle(color: Colors.white.withOpacity(0.82)),
                    textAlign: TextAlign.center,
                  ),
                )
              : _RouteTimeline(
                  items: timed,
                  onTapStage: (stage) => _openStageDetails(stage),
                  onLongPressStage: (stage) => _showStageActions(stage),
                ),
        ),
      ],
    );
  }

  _TimelineStageItem? _toTimelineStage(TripStage stage) {
    final start = stage.startTime;
    final end = stage.endTime;
    if (start == null && end == null) return null;

    int minutesOfDay(DateTime date) => date.hour * 60 + date.minute;
    var startMin = start != null ? minutesOfDay(start) : minutesOfDay(end!) - 60;
    var endMin = end != null ? minutesOfDay(end) : startMin + 60;
    if (endMin <= startMin) {
      endMin = startMin + 45;
    }

    startMin = startMin.clamp(0, 23 * 60 + 59);
    endMin = endMin.clamp(startMin + 15, 24 * 60);
    final visual = _stageVisual(stage.stageType);
    return _TimelineStageItem(
      stage: stage,
      startMin: startMin,
      endMin: endMin,
      color: visual.iconColor,
    );
  }

  List<DateTime> _tripDays({required List<TripStage> stages}) {
    DateTime toDay(DateTime date) => DateTime(date.year, date.month, date.day);
    if (widget.startDate != null && widget.endDate != null) {
      final start = toDay(widget.startDate!);
      final end = toDay(widget.endDate!);
      if (!end.isBefore(start)) {
        final days = <DateTime>[];
        var cursor = start;
        while (!cursor.isAfter(end)) {
          days.add(cursor);
          cursor = cursor.add(const Duration(days: 1));
        }
        return days;
      }
    }
    final values = stages
        .map((stage) => stage.startTime ?? stage.endTime)
        .whereType<DateTime>()
        .map(toDay)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    if (values.isNotEmpty) return values;
    final now = DateTime.now();
    return [DateTime(now.year, now.month, now.day)];
  }

  DateTime _ensureSelectedRouteDay(
    DateTime? selected, {
    required List<TripStage> stages,
  }) {
    final days = _tripDays(stages: stages);
    if (days.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    if (selected == null) return days.first;
    final normalized = DateTime(selected.year, selected.month, selected.day);
    return days.firstWhere((day) => day == normalized, orElse: () => days.first);
  }

  List<TripStage> _filterStagesByDay(
    List<TripStage> stages,
    DateTime selectedDay,
    List<DateTime> tripDays,
  ) {
    DateTime toDay(DateTime date) => DateTime(date.year, date.month, date.day);
    final firstDay = tripDays.isNotEmpty ? tripDays.first : selectedDay;
    return stages.where((stage) {
      final candidate = stage.startTime ?? stage.endTime;
      if (candidate == null) {
        return selectedDay == firstDay;
      }
      return toDay(candidate) == selectedDay;
    }).toList();
  }

  List<TripStage> _visibleStagesForSelectedDay() {
    final ordered = [..._stages]..sort((a, b) => a.position.compareTo(b.position));
    final days = _tripDays(stages: ordered);
    final selectedDay = _ensureSelectedRouteDay(_selectedRouteDay, stages: ordered);
    return _filterStagesByDay(ordered, selectedDay, days);
  }
  Widget _buildBudgetCard(ColorScheme cs) {
    if (_showBudgetAnalytics) {
      return _buildBudgetAnalyticsCard(cs);
    }

    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amountRub);

    final visible = _expenses
        .where((e) => _categoryFilter == 'all' || e.category == _categoryFilter)
        .toList();

    if (_sortMode == 'asc') {
      visible.sort((a, b) => a.amountRub.compareTo(b.amountRub));
    } else if (_sortMode == 'desc') {
      visible.sort((a, b) => b.amountRub.compareTo(a.amountRub));
    } else {
      visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Общие расходы: ${total.toStringAsFixed(2)} руб.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Диаграмма расходов',
                onPressed: () {
                  setState(() {
                    _showBudgetAnalytics = true;
                  });
                },
                icon: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Сортировка',
                onSelected: (value) {
                  setState(() {
                    _sortMode = value;
                  });
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'none', child: Text('Без сортировки')),
                  PopupMenuItem(value: 'asc', child: Text('По возрастанию')),
                  PopupMenuItem(value: 'desc', child: Text('По убыванию')),
                ],
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoryFilter,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Все категории'),
                        ),
                        ..._categories.entries.map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _categoryFilter = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _addingExpense ? null : _openAddExpenseDialog,
              icon: _addingExpense
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Добавить расходы'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _budgetLoading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет расходов',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final expense = visible[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _categories[expense.category] ??
                                        expense.category,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${expense.amountRub.toStringAsFixed(2)} руб.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Редактировать',
                              onPressed: () => _openEditExpenseDialog(expense),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => _deleteExpense(expense),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAnalyticsCard(ColorScheme cs) {
    final totalsByCategory = <String, double>{};
    for (final expense in _expenses) {
      totalsByCategory[expense.category] =
          (totalsByCategory[expense.category] ?? 0) + expense.amountRub;
    }

    final items = totalsByCategory.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = items.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showBudgetAnalytics = false;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Назад к расходам'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: _ExpensePieChart(
              values: {
                for (final item in items) item.key: item.value,
              },
              colors: _categoryColors,
              total: total,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет данных для диаграммы',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final categoryKey = item.key;
                      final categoryLabel = _categories[categoryKey] ?? categoryKey;
                      final color = _categoryColors[categoryKey] ?? _categoryColors['other']!;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                categoryLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${item.value.toStringAsFixed(2)} руб.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _uploadingDocument ? null : _pickAndUploadDocument,
              icon: _uploadingDocument
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('Загрузить документ'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _documentsLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет документов',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final doc = _documents[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openDocumentPreview(doc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _fmtBytes(doc.sizeBytes),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Удалить',
                                  onPressed: () => _deleteDocument(doc),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  String? _resolvePreviewType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))
      return 'image';
    return null;
  }

  String _buildTargetFileName({
    required String customTitle,
    required String originalFileName,
  }) {
    final clean = customTitle.trim();
    final ext = _fileExtension(originalFileName);
    if (ext.isEmpty) return clean;

    if (clean.toLowerCase().endsWith(ext.toLowerCase())) {
      return clean;
    }
    return '$clean$ext';
  }

  String _fileNameWithoutExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx <= 0) return fileName;
    return fileName.substring(0, idx);
  }

  String _fileExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx <= 0 || idx == fileName.length - 1) return '';
    return fileName.substring(idx);
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                              style: TextStyle(color: Colors.black54),
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
    this.title = 'Добавить расходы',
    this.submitLabel = 'Создать',
  });

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
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
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Описание'),
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
                decoration: const InputDecoration(labelText: 'Сумма (руб)'),
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
                decoration: const InputDecoration(labelText: 'Категория'),
                items: widget.categories.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
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
          child: const Text('Отмена'),
        ),
        ElevatedButton(
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
  static const Map<String, String> _subtypeLabels = <String, String>{
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

  late String _stageType;
  late String _subtype;

  @override
  void initState() {
    super.initState();
    _stageType = widget.initial?.stageType ?? widget.initialType;
    _subtype = widget.initial?.subtype ?? (widget.stageSubtypes[_stageType]?.first ?? '');

    final initial = widget.initial;
    if (initial != null) {
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

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _parseTime(controller.text, widget.routeDay);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current?.hour ?? 12, minute: current?.minute ?? 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _timeField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:MM',
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time_rounded, color: Colors.white70),
          onPressed: () => _pickTime(controller),
        ),
      ),
      keyboardType: TextInputType.datetime,
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
    final needsReference =
        (isTransport && const {'airplane', 'train', 'bus'}.contains(_subtype)) ||
        isStay;
    if (!subtypes.contains(_subtype) && subtypes.isNotEmpty) {
      _subtype = subtypes.first;
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
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.primary.withOpacity(0.8), width: 1.4),
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
                                          child: Text(_prettySubtype(e)),
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
                                    decoration: InputDecoration(labelText: isFood ? 'Средний чек, руб' : 'Стоимость, руб'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (needsReference) ...[
                                  TextFormField(
                                    controller: _refCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(labelText: 'Номер рейса / брони'),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (isPlace) ...[
                                  TextFormField(
                                    controller: _websiteCtrl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(labelText: 'Сайт'),
                                  ),
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
                                        costRub: double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')),
                                        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
                                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                                        websiteUrl: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
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

class _RouteTimeline extends StatelessWidget {
  final List<_TimelineStageItem> items;
  final ValueChanged<TripStage> onTapStage;
  final ValueChanged<TripStage> onLongPressStage;

  const _RouteTimeline({
    required this.items,
    required this.onTapStage,
    required this.onLongPressStage,
  });

  static const int _startHour = 8;
  static const int _endHour = 22;
  static const double _pxPerHour = 56;
  static const double _timeColumnWidth = 52;

  String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final dayStart = _startHour * 60;
    final dayEnd = _endHour * 60;

    final visible = items.where((item) {
      return item.endMin > dayStart && item.startMin < dayEnd;
    }).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    final layout = <_TimelineStageItem, int>{};
    final colEnd = <int>[];
    var maxColumns = 1;
    for (final item in visible) {
      var col = -1;
      for (var i = 0; i < colEnd.length; i++) {
        if (item.startMin >= colEnd[i] + 2) {
          col = i;
          break;
        }
      }
      if (col == -1) {
        col = colEnd.length;
        colEnd.add(item.endMin);
      } else {
        colEnd[col] = item.endMin;
      }
      layout[item] = col;
      if (col + 1 > maxColumns) maxColumns = col + 1;
    }

    final totalHours = _endHour - _startHour;
    final timelineHeight = totalHours * _pxPerHour;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          height: timelineHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentLeft = _timeColumnWidth + 6;
              final contentWidth =
                  (constraints.maxWidth - contentLeft - 8).clamp(120, 1200).toDouble();
              final gap = 6.0;
              final blockWidth = (contentWidth - gap * (maxColumns - 1)) / maxColumns;

              return Stack(
                children: [
                  for (var hour = _startHour; hour <= _endHour; hour++) ...[
                    Positioned(
                      top: (hour - _startHour) * _pxPerHour - 8,
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
                      top: (hour - _startHour) * _pxPerHour,
                      left: _timeColumnWidth + 8,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                  for (final item in visible)
                    Positioned(
                      top: ((item.startMin - dayStart) / 60) * _pxPerHour + 2,
                      left: contentLeft + (layout[item]! * (blockWidth + gap)),
                      width: blockWidth,
                      height: (((item.endMin - item.startMin) / 60) * _pxPerHour)
                          .clamp(34, 170),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onTapStage(item.stage),
                        onLongPress: () => onLongPressStage(item.stage),
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
                                        '${_hhmm(item.startMin)} - ${_hhmm(item.endMin)}',
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

  const _RouteDayStrip({
    required this.days,
    required this.selectedDay,
    required this.onDayTap,
    this.compact = false,
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
                    day.day.toString(),
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFD7E37A)
                          : Colors.white.withOpacity(0.9),
                      fontSize: dayFont,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 4),
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
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripRouteMapPage extends StatefulWidget {
  final String tripTitle;
  final String destinationCity;
  final List<Map<String, String>> stagePoints;
  final DateTime? startDate;
  final DateTime? endDate;

  const _TripRouteMapPage({
    required this.tripTitle,
    required this.destinationCity,
    required this.stagePoints,
    this.startDate,
    this.endDate,
  });

  @override
  State<_TripRouteMapPage> createState() => _TripRouteMapPageState();
}

class _TripRouteMapPageState extends State<_TripRouteMapPage> {
  late final TextEditingController _searchCtrl;
  late String _mapQuery;

  @override
  void initState() {
    super.initState();
    _mapQuery = widget.destinationCity.trim();
    _searchCtrl = TextEditingController(text: _mapQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      _mapQuery = value;
    });
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
                          fontWeight: FontWeight.w800,
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
                      const SizedBox(height: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: YandexCityMap(
                            city: _mapQuery,
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
                                const SizedBox(height: 12),
                                _line('Адрес / место', stage.address),
                                _line('Откуда', stage.startLocation),
                                _line('Куда', stage.endLocation),
                                _line('Стоимость', stage.costRub == null ? null : '${stage.costRub} руб.'),
                                _line('Номер рейса / брони', stage.referenceNumber),
                                _line('Сайт', stage.websiteUrl),
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


