import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interactions/interactions_repo.dart';
import '../preferences/preferences_repo.dart';
import '../profile/profile_repo.dart';
import '../recommendations/recommendations_repo.dart';
import 'trips_repo.dart';

class TripRecommendationsTab extends StatefulWidget {
  final RecommendationsRepo recommendationsRepo;
  final InteractionsRepo interactionsRepo;
  final PreferencesRepo preferencesRepo;
  final ProfileRepo profileRepo;
  final TripsRepo tripsRepo;
  final int? tripId;
  final String? destinationCity;
  final String tripTitle;
  final List<TripStage> stages;
  final VoidCallback onStagesChanged;

  const TripRecommendationsTab({
    super.key,
    required this.recommendationsRepo,
    required this.interactionsRepo,
    required this.preferencesRepo,
    required this.profileRepo,
    required this.tripsRepo,
    required this.stages,
    required this.tripTitle,
    required this.onStagesChanged,
    this.tripId,
    this.destinationCity,
  });

  @override
  State<TripRecommendationsTab> createState() => _TripRecommendationsTabState();
}

class _TripRecommendationsTabState extends State<TripRecommendationsTab> {
  bool _loading = false;
  List<RecommendationItem> _recommendations = const [];
  SurveyProfile? _surveyProfile;
  String? _currentUserId;
  final Set<String> _sentImpressions = {};
  final Set<String> _likedIds = {};
  final Set<String> _dislikedIds = {};
  final Set<String> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await widget.profileRepo.getMe();
      var profile = SurveyProfile.empty();
      try {
        profile = await widget.preferencesRepo.getSurveyProfile();
      } catch (_) {
        profile = SurveyProfile.empty();
      }
      final center = _routeCenter();
      final tripCity = _tripCity();
      final favoriteGroups = await widget.interactionsRepo.getFavorites(
        userId: me.id.toString(),
        tripId: widget.tripId,
        city: tripCity,
      );
      final items = await widget.recommendationsRepo.getPersonalized(
        profile: profile,
        city: tripCity,
        nearRoute: widget.stages.isNotEmpty,
        routeLatitude: center?.latitude,
        routeLongitude: center?.longitude,
        userId: me.id.toString(),
      );
      final filteredItems = tripCity == null || tripCity.isEmpty
          ? items
          : items
              .where((item) => item.city.trim().toLowerCase() == tripCity.toLowerCase())
              .toList();
      if (!mounted) return;
      setState(() {
        _surveyProfile = profile;
        _currentUserId = me.id.toString();
        _recommendations = filteredItems;
        _sentImpressions.clear();
        _savedIds
          ..clear()
          ..addAll(
            favoriteGroups.expand((g) => g.items).map((i) => i.placeId),
          );
      });
      _trackImpressions(filteredItems);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recommendations = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _guessCity() {
    if ((widget.destinationCity ?? '').trim().isNotEmpty) {
      return widget.destinationCity!.trim();
    }
    final scores = <String, int>{};
    void add(String? raw, {int weight = 1}) {
      if (raw == null) return;
      final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) return;
      for (final part in normalized
          .split(RegExp(r'[,;/|]'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)) {
        scores[part] = (scores[part] ?? 0) + weight;
      }
    }

    for (final stage in widget.stages) {
      add(stage.address, weight: 3);
      add(stage.startLocation, weight: 2);
      add(stage.endLocation, weight: 2);
    }
    final title = widget.tripTitle.trim();
    if (title.isNotEmpty && title.split(RegExp(r'\s+')).length <= 4) {
      add(title, weight: 1);
    }
    if (scores.isEmpty) return null;
    return (scores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  String? _tripCity() {
    final direct = (widget.destinationCity ?? '').trim();
    if (direct.isNotEmpty) return direct;
    final guessed = _guessCity()?.trim() ?? '';
    return guessed.isEmpty ? null : guessed;
  }

  ({double latitude, double longitude})? _routeCenter() {
    var count = 0;
    var latSum = 0.0;
    var lonSum = 0.0;
    for (final stage in widget.stages) {
      if (stage.latitude == null || stage.longitude == null) continue;
      latSum += stage.latitude!;
      lonSum += stage.longitude!;
      count++;
    }
    if (count == 0) return null;
    return (latitude: latSum / count, longitude: lonSum / count);
  }

  Future<void> _trackImpressions(List<RecommendationItem> items) async {
    final userId = _currentUserId;
    if (userId == null) return;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (_sentImpressions.contains(item.id)) continue;
      _sentImpressions.add(item.id);
      try {
        await widget.interactionsRepo.trackImpression(
          userId: userId,
          placeId: item.id,
          recommendationId: item.id,
          position: i,
        );
        await widget.interactionsRepo.trackEvent(
          userId: userId,
          placeId: item.id,
          action: 'shown',
          recommendationId: item.id,
        );
      } catch (_) {}
    }
  }

  Future<void> _trackAction(
    RecommendationItem item,
    String action, {
    double weight = 1.0,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await widget.interactionsRepo.trackEvent(
        userId: userId,
        placeId: item.id,
        action: action,
        recommendationId: item.id,
        weight: weight,
        metadata: metadata,
      );
    } catch (_) {}
  }

  Map<String, dynamic> _metadata(RecommendationItem item) => {
        'title': item.title,
        'city': item.city,
        'address': item.address,
        'image_url': item.imageUrl,
        'category': item.category,
        'subcategory': item.subcategory,
        'rating': item.rating,
        'description': item.description,
        'trip_id': widget.tripId,
        'trip_title': widget.tripTitle,
      };

  void _consume(String id) {
    setState(() {
      _recommendations = _recommendations.where((r) => r.id != id).toList();
    });
  }

  Future<void> _like(RecommendationItem item) async {
    setState(() {
      _likedIds.add(item.id);
      _dislikedIds.remove(item.id);
    });
    await _trackAction(item, 'liked', weight: 4, metadata: _metadata(item));
  }

  Future<void> _dislike(RecommendationItem item) async {
    setState(() {
      _dislikedIds.add(item.id);
      _likedIds.remove(item.id);
    });
    await _trackAction(item, 'disliked', weight: -4, metadata: _metadata(item));
  }

  Future<void> _save(RecommendationItem item) async {
    setState(() => _savedIds.add(item.id));
    await _trackAction(item, 'saved', weight: 3, metadata: _metadata(item));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043e \u0432 \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435'
          '${widget.destinationCity == null ? '' : ' \u00b7 ${widget.destinationCity}'}',
        ),
      ),
    );
  }

  Future<void> _addToTrip(RecommendationItem item) async {
    if (widget.tripId == null) return;
    final created = await widget.tripsRepo.createStage(
      tripId: widget.tripId!,
      stageType: 'place',
      subtype: item.subcategory.isEmpty ? 'attraction' : item.subcategory,
      title: item.title,
      address: item.address.isEmpty ? null : item.address,
      latitude: item.latitude == 0 ? null : item.latitude,
      longitude: item.longitude == 0 ? null : item.longitude,
      notes: item.description.isEmpty ? null : item.description,
      rating: item.rating == 0 ? null : item.rating,
    );
    if (created == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0434\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u044e \u0432 \u043c\u0430\u0440\u0448\u0440\u0443\u0442')),
      );
      return;
    }
    await _trackAction(item, 'added_to_trip', weight: 5, metadata: _metadata(item));
    if (!mounted) return;
    widget.onStagesChanged();
    _consume(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('\u0414\u043e\u0431\u0430\u0432\u043b\u0435\u043d\u043e \u0432 \u043c\u0430\u0440\u0448\u0440\u0443\u0442: ${item.title}')),
    );
  }

  Future<void> _onSwipe(RecommendationItem item, DismissDirection direction) async {
    _consume(item.id);
    if (direction == DismissDirection.startToEnd) {
      await _like(item);
    } else {
      await _dislike(item);
    }
  }

  Future<void> _openDetails(RecommendationItem item) async {
    await _trackAction(item, 'opened',
        weight: 2,
        metadata: {'city': item.city, 'category': item.category});
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1D1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tag(item.city),
                  if (item.address.isNotEmpty) _tag(item.address),
                  _tag('\u2605 ${item.rating.toStringAsFixed(1)}'),
                  _tag(item.subcategory.isEmpty
                      ? item.category
                      : item.subcategory),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSurvey() async {
    await context.push('/preferences?from=recommendations');
    if (!mounted) return;
    await _load();
  }

  Future<void> _openTripFavorites() async {
    final city = _tripCity();
    final params = <String, String>{
      if (widget.tripId != null) 'tripId': widget.tripId.toString(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (city != null && city.trim().isNotEmpty)
        'title': '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u043e\u0435 \u00b7 ${city.trim()}',
      'subtitle': '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u044b\u0435 \u043c\u0435\u0441\u0442\u0430 \u0434\u043b\u044f \u0433\u043e\u0440\u043e\u0434\u0430 \u044d\u0442\u043e\u0433\u043e \u043c\u0430\u0440\u0448\u0440\u0443\u0442\u0430',
    };
    final query = Uri(queryParameters: params).query;
    await context.push('/trip-favorites${query.isEmpty ? '' : '?$query'}');
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '\u0420\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u0438',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openTripFavorites,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.bookmark_rounded, size: 14),
              label: const Text('\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u043e\u0435'),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _openSurvey,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD7E37A),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('\u041e\u043f\u0440\u043e\u0441'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _surveyProfile?.skipped == true
              ? '\u041f\u043e\u043a\u0430\u0437\u044b\u0432\u0430\u0435\u043c \u0431\u0430\u0437\u043e\u0432\u044b\u0435 \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u0438. \u041f\u0440\u043e\u0439\u0434\u0438\u0442\u0435 \u043e\u043f\u0440\u043e\u0441, \u0447\u0442\u043e\u0431\u044b \u043f\u043e\u0434\u0431\u043e\u0440 \u0441\u0442\u0430\u043b \u0442\u043e\u0447\u043d\u0435\u0435.'
              : '\u0421\u0432\u0430\u0439\u043f\u0430\u0439\u0442\u0435 \u0432\u043f\u0440\u0430\u0432\u043e \u2014 \u043d\u0440\u0430\u0432\u0438\u0442\u0441\u044f, \u0432\u043b\u0435\u0432\u043e \u2014 \u043d\u0435 \u043f\u043e\u0434\u0445\u043e\u0434\u0438\u0442.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
                )
              : _recommendations.isEmpty
                  ? _EmptyState(onSurvey: _openSurvey)
                  : _Deck(
                      recommendations: _recommendations,
                      likedIds: _likedIds,
                      savedIds: _savedIds,
                      onOpen: _openDetails,
                      onApprove: (item) async {
                        await _like(item);
                        _consume(item.id);
                      },
                      onReject: (item) async {
                        await _dislike(item);
                        _consume(item.id);
                      },
                      onSave: _save,
                      onAddToTrip: _addToTrip,
                      onSwipe: _onSwipe,
                    ),
        ),
      ],
    );
  }
}

// в”Ђв”Ђв”Ђ Deck в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

class _Deck extends StatelessWidget {
  const _Deck({
    required this.recommendations,
    required this.likedIds,
    required this.savedIds,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onSave,
    required this.onAddToTrip,
    required this.onSwipe,
  });

  final List<RecommendationItem> recommendations;
  final Set<String> likedIds;
  final Set<String> savedIds;
  final Future<void> Function(RecommendationItem) onOpen;
  final Future<void> Function(RecommendationItem) onApprove;
  final Future<void> Function(RecommendationItem) onReject;
  final Future<void> Function(RecommendationItem) onSave;
  final Future<void> Function(RecommendationItem) onAddToTrip;
  final Future<void> Function(RecommendationItem, DismissDirection) onSwipe;

  @override
  Widget build(BuildContext context) {
    final visible = recommendations.take(3).toList();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = visible.length - 1; i >= 0; i--)
          _buildLayer(visible[i], depth: i),
      ],
    );
  }

  Widget _buildLayer(RecommendationItem item, {required int depth}) {
    final isTop = depth == 0;
    final card = _SwipeCard(
      item: item,
      isLiked: likedIds.contains(item.id),
      isSaved: savedIds.contains(item.id),
      onOpen: () => onOpen(item),
      onApprove: () => onApprove(item),
      onSave: () => onSave(item),
      onAddToTrip: () => onAddToTrip(item),
      onReject: () => onReject(item),
    );

    final vOffset = depth * 12.0;
    final hInset = depth * 10.0;
    final scale = 1 - depth * 0.04;

    if (!isTop) {
      return Positioned.fill(
        top: vOffset,
        left: hInset,
        right: hInset,
        bottom: depth * 6.0,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: card,
        ),
      );
    }

    return Positioned.fill(
      top: vOffset,
      left: hInset,
      right: hInset,
      bottom: depth * 6.0,
      child: Dismissible(
        key: ValueKey('rec-${item.id}'),
        direction: DismissDirection.horizontal,
        background: _SwipeHint(
          alignment: Alignment.centerLeft,
          color: const Color(0xFFD7E37A),
          icon: Icons.favorite_rounded,
          label: '\u041f\u043e\u0434\u0445\u043e\u0434\u0438\u0442',
        ),
        secondaryBackground: _SwipeHint(
          alignment: Alignment.centerRight,
          color: const Color(0xFFB88D7A),
          icon: Icons.close_rounded,
          label: '\u041f\u0440\u043e\u043f\u0443\u0441\u0442\u0438\u0442\u044c',
        ),
        onDismissed: (dir) => onSwipe(item, dir),
        child: card,
      ),
    );
  }
}

// в”Ђв”Ђв”Ђ Swipe card в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.item,
    required this.isLiked,
    required this.isSaved,
    required this.onOpen,
    required this.onApprove,
    required this.onSave,
    required this.onAddToTrip,
    required this.onReject,
  });

  final RecommendationItem item;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onOpen;
  final Future<void> Function() onApprove;
  final Future<void> Function() onSave;
  final Future<void> Function() onAddToTrip;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D1D),
            borderRadius: BorderRadius.circular(30),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _CardPlaceholder(city: item.city),
                          )
                        : _CardPlaceholder(city: item.city),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.76),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.24),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _MetaChip(
                                icon: Icons.star_rounded,
                                label: item.rating.toStringAsFixed(1),
                              ),
                              const SizedBox(width: 8),
                              _MetaChip(
                                icon: Icons.auto_awesome_rounded,
                                label: item.subcategory.isEmpty
                                    ? item.category
                                    : item.subcategory,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c',
                        active: isSaved,
                        onTap: () => onSave(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.route_rounded,
                        label: '\u0412 \u043c\u0430\u0440\u0448\u0440\u0443\u0442',
                        active: false,
                        onTap: () => onAddToTrip(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DecisionButton(
                      icon: Icons.close_rounded,
                      color: const Color(0xFFB88D7A),
                      onTap: () => onReject(),
                    ),
                    const SizedBox(width: 8),
                    _DecisionButton(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: const Color(0xFFD7E37A),
                      onTap: () => onApprove(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// в”Ђв”Ђв”Ђ Small widgets в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.city});
  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A4438), Color(0xFF1D231C)],
        ),
      ),
      child: Center(
        child: Text(
          city,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.16),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD7E37A), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF222715) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? const Color(0xFFD7E37A).withOpacity(0.75)
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active
                  ? const Color(0xFFD7E37A)
                  : Colors.white.withOpacity(0.78),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? const Color(0xFFD7E37A)
                      : Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft)
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          if (!isLeft) const SizedBox(width: 10),
          Icon(icon, color: color, size: 28),
          if (isLeft) const SizedBox(width: 10),
          if (isLeft)
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSurvey});
  final VoidCallback onSurvey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Color(0xFFD7E37A), size: 32),
          const SizedBox(height: 12),
          const Text(
            '\u0421\u043a\u043e\u0440\u043e \u0437\u0434\u0435\u0441\u044c \u043f\u043e\u044f\u0432\u044f\u0442\u0441\u044f \u043d\u043e\u0432\u044b\u0435 \u043c\u0435\u0441\u0442\u0430',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\u041c\u044b \u043f\u043e\u0434\u0431\u0438\u0440\u0430\u0435\u043c \u0441\u043b\u0435\u0434\u0443\u044e\u0449\u0438\u0435 \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u0438 \u0434\u043b\u044f \u044d\u0442\u043e\u0433\u043e \u043c\u0430\u0440\u0448\u0440\u0443\u0442\u0430.\n\u0417\u0430\u0439\u0434\u0438\u0442\u0435 \u0447\u0443\u0442\u044c \u043f\u043e\u0437\u0436\u0435 \u0438\u043b\u0438 \u043e\u0431\u043d\u043e\u0432\u0438\u0442\u0435 \u044d\u043a\u0440\u0430\u043d.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.64),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onSurvey,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD7E37A),
              backgroundColor: const Color(0xFF222715),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                    color: const Color(0xFFD7E37A).withOpacity(0.55)),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('\u041e\u0431\u043d\u043e\u0432\u0438\u0442\u044c \u043f\u043e\u0434\u0431\u043e\u0440'),
          ),
        ],
      ),
    );
  }
}


