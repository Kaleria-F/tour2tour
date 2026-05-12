part of 'trip_workspace_page.dart';

extension _TripWorkspaceRouteSection on _TripWorkspacePageState {
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
                    foregroundColor: _TripWorkspacePageState._accent,
                    side: BorderSide(
                      color: _TripWorkspacePageState._accent.withOpacity(0.44),
                    ),
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
                    'Этап',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildRouteAssistantButton(),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildRouteTimelineSection(stages: visibleStages)),
        ],
      ),
    );
  }

  Future<void> _openStageDetails(TripStage stage) async {
    final typeLabel =
        _TripWorkspacePageState._stageTypeLabels[stage.stageType] ?? stage.stageType;
    final subtypeLabel = _prettySubtype(stage.subtype);
    final timeRange = _formatTimeRange(stage.startTime, stage.endTime);
    setState(() {
      _selectedStageId = stage.id;
    });
    final action = await Navigator.of(context).push<_StageDetailsAction>(
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
    if (!mounted || action == null) return;
    if (action == _StageDetailsAction.edit) {
      await _openEditStageDialog(stage);
      return;
    }
    if (action == _StageDetailsAction.copy) {
      await _copyStage(stage);
      return;
    }
    if (action == _StageDetailsAction.delete) {
      await _deleteStage(stage);
    }
  }

  Widget _buildRouteAssistantButton() {
    final progress = ((30 - _routeAssistantSecondsLeft) / 30).clamp(0.0, 1.0);
    final button = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _routeAssistantRecording ? 1.08 : 1,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: _routeAssistantRecording ? progress : 0,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB6A1FF)),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFB6A1FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB6A1FF).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  if (_routeAssistantRecording)
                    Positioned(
                      bottom: 3,
                      child: Text(
                        '$_routeAssistantSecondsLeft',
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
    );

    if (kIsWeb) {
      return Listener(
        onPointerDown: (_) => _handleRouteAssistantWebPointerDown(),
        onPointerUp: (_) => _handleRouteAssistantWebPointerUp(),
        onPointerCancel: (_) => _handleRouteAssistantWebPointerCancel(),
        child: button,
      );
    }

    return GestureDetector(
      onTap: _routeAssistantRecording || _routeAssistantProcessing
          ? null
          : _openRouteAssistantTextEntry,
      onLongPressStart: (_) => _startRouteAssistantRecording(),
      onLongPressEnd: (_) => _stopRouteAssistantRecordingIfNeeded(),
      onLongPressCancel: _stopRouteAssistantRecordingIfNeeded,
      child: button,
    );
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
                  onDragStageEnd: (stage, startMin, endMin) =>
                      _applyStageTimesFromDrag(
                    stage,
                    startMin: startMin,
                    endMin: endMin,
                  ),
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
    if (_tripPlannedDays != null && _tripPlannedDays! > 0) {
      final anchor = _tripStartDate != null
          ? toDay(_tripStartDate!)
          : DateTime.now();
      return List<DateTime>.generate(
        _tripPlannedDays!,
        (index) => anchor.add(Duration(days: index)),
      );
    }
    if (_tripStartDate != null && _tripEndDate != null) {
      final start = toDay(_tripStartDate!);
      final end = toDay(_tripEndDate!);
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
}

