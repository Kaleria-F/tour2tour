
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../core/widgets/cors_safe_network_image.dart';
import '../interactions/interactions_repo.dart';
import '../preferences/preferences_repo.dart';
import '../recommendations/recommendations_repo.dart';
import '../shared/travel_app_shell.dart';
import '../stories/stories_repo.dart';
import '../trips/trips_repo.dart';
import 'profile_repo.dart';

class ProfilePage extends StatefulWidget {
  final ProfileRepo repo;
  final TripsRepo tripsRepo;
  final PreferencesRepo preferencesRepo;
  final RecommendationsRepo recommendationsRepo;
  final InteractionsRepo interactionsRepo;
  final StoriesRepo storiesRepo;

  const ProfilePage({
    super.key,
    required this.repo,
    required this.tripsRepo,
    required this.preferencesRepo,
    required this.recommendationsRepo,
    required this.interactionsRepo,
    required this.storiesRepo,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Duration _premiumPopupDelay = Duration(seconds: 150);

  UserMe? _me;
  SurveyProfile? _surveyProfile;
  List<TripSummary> _trips = const [];
  List<RecommendationItem> _recommendations = const [];
  List<StoryItem> _stories = const [];
  final Set<String> _savedRecommendationIds = <String>{};
  Set<String> _viewedStoryIds = const <String>{};
  bool _loading = true;
  bool _recommendationsLoading = false;
  String? _error;
  Timer? _premiumPopupTimer;
  bool _premiumPopupShown = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _premiumPopupTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.repo.getMe(),
        widget.tripsRepo.listTrips(),
      ]);

      SurveyProfile profile;
      try {
        profile = await widget.preferencesRepo.getSurveyProfile();
      } catch (_) {
        profile = SurveyProfile.empty();
      }

      if (!mounted) return;
      setState(() {
        _me = results[0] as UserMe;
        _trips = results[1] as List<TripSummary>;
        _surveyProfile = profile;
      });
      _schedulePremiumPopup();

      await _loadStories();
      await _loadSavedRecommendations();
      await _loadRecommendations();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedRecommendations() async {
    final me = _me;
    if (me == null) return;
    try {
      final groups = await widget.interactionsRepo.getFavorites(
        userId: me.id.toString(),
      );
      if (!mounted) return;
      setState(() {
        _savedRecommendationIds
          ..clear()
          ..addAll(
            groups.expand((group) => group.items).map((item) => item.placeId),
          );
      });
    } catch (_) {}
  }

  Future<void> _loadStories() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.storiesRepo.listStories(),
        widget.storiesRepo.readViewedIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _stories = List<StoryItem>.from(results[0] as List<StoryItem>)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _viewedStoryIds = Set<String>.from(results[1] as Set<String>);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stories = const [];
        _viewedStoryIds = const <String>{};
      });
    }
  }

  Future<void> _loadRecommendations() async {
    final profile = _surveyProfile;
    if (profile == null) return;
    setState(() => _recommendationsLoading = true);
    try {
      final items = await widget.recommendationsRepo.getPersonalized(
        profile: profile,
        userId: _me?.id.toString(),
      );
      if (!mounted) return;
      setState(() => _recommendations = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recommendations = const []);
    } finally {
      if (!mounted) return;
      setState(() => _recommendationsLoading = false);
    }
  }

  void _schedulePremiumPopup() {
    _premiumPopupTimer?.cancel();
    if (_me?.isPremium == true || _premiumPopupShown) return;
    _premiumPopupTimer = Timer(_premiumPopupDelay, () {
      if (!mounted || _me?.isPremium == true || _premiumPopupShown) return;
      _premiumPopupShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E37A).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFD7E37A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Тур2Тур Pro',
                        style: TextStyle(
                          fontFamily: 'Geologica',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Быстрый ввод этапов голосом и текстом. Просто продиктуйте мысль, а приложение заполнит маршрут за вас.',
                  style: TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/premium');
                    },
                    child: const Text('Подробнее'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
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
      };

  Future<void> _toggleRecommendationSaved(RecommendationItem item) async {
    final me = _me;
    if (me == null) return;
    final wasSaved = _savedRecommendationIds.contains(item.id);
    setState(() {
      if (wasSaved) {
        _savedRecommendationIds.remove(item.id);
      } else {
        _savedRecommendationIds.add(item.id);
      }
    });
    try {
      await widget.interactionsRepo.setFavorite(
        userId: me.id.toString(),
        placeId: item.id,
        recommendationId: item.id,
        metadata: _metadata(item),
        saved: !wasSaved,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved
                ? 'Удалено из избранного: ${item.title}'
                : 'Сохранено в избранное: ${item.title}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedRecommendationIds.add(item.id);
        } else {
          _savedRecommendationIds.remove(item.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved
                ? 'Не удалось убрать место из избранного'
                : 'Не удалось сохранить место',
          ),
        ),
      );
    }
  }

  Future<void> _openRecommendationDetails(RecommendationItem item) async {
    final me = _me;
    if (me != null) {
      try {
        await widget.interactionsRepo.trackEvent(
          userId: me.id.toString(),
          placeId: item.id,
          action: 'opened',
          recommendationId: item.id,
          weight: 2,
          metadata: _metadata(item),
        );
      } catch (_) {}
    }

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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(icon: Icons.location_on_rounded, label: item.city),
                  if (item.address.isNotEmpty)
                    _MetaChip(
                      icon: Icons.place_outlined,
                      label: item.address,
                    ),
                  _MetaChip(
                    icon: Icons.star_rounded,
                    label: item.rating.toStringAsFixed(1),
                  ),
                  _MetaChip(
                    icon: Icons.auto_awesome_rounded,
                    label: item.subcategory.isEmpty
                        ? item.category
                        : item.subcategory,
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savedRecommendationIds.contains(item.id)
                      ? () async {
                          Navigator.of(context).pop();
                          await _toggleRecommendationSaved(item);
                        }
                      : () async {
                          Navigator.of(context).pop();
                          await _toggleRecommendationSaved(item);
                        },
                  icon: Icon(
                    _savedRecommendationIds.contains(item.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    _savedRecommendationIds.contains(item.id)
                        ? 'Убрать из избранного'
                        : 'Сохранить',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStory(StoryItem story) async {
    final storyIndex = _stories.indexWhere((item) => item.id == story.id);
    if (!_viewedStoryIds.contains(story.id)) {
      try {
        await widget.storiesRepo.markViewed(story.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _viewedStoryIds = {..._viewedStoryIds, story.id};
        });
      }
    }
    if (!mounted) return;
    context.push(
      '/story-viewer',
      extra: {
        'story': story,
        'stories': _stories,
        'initialIndex': storyIndex < 0 ? 0 : storyIndex,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_me?.displayName ?? '').trim();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeTrips = _trips
        .where((trip) {
          if (trip.plannedDays != null && trip.plannedDays! > 0) {
            // "Количество дней" = даты еще не зафиксированы, такие поездки всегда считаем активными.
            return true;
          }
          final tripEnd = DateTime(
            trip.endDate.year,
            trip.endDate.month,
            trip.endDate.day,
          );
          return !tripEnd.isBefore(today);
        })
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return TravelAppShell(
      title: displayName.isEmpty ? 'Привет' : 'Привет, $displayName',
      subtitle: 'Соберите поездку и посмотрите новые идеи для путешествий',
      currentTab: TravelNavTab.home,
      headerAction: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.go('/preferences'),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_stories.isNotEmpty) ...[
                        _StoriesRow(
                          stories: _stories,
                          viewedStoryIds: _viewedStoryIds,
                          onOpen: _openStory,
                        ),
                        const SizedBox(height: 18),
                      ],
                      const _SectionHeader(title: 'Мои поездки'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 248,
                        child: activeTrips.isEmpty
                            ? _EmptyStrip(
                                title: 'Пока нет поездок',
                                subtitle: 'Создайте путешествие, и здесь появятся ваши маршруты.',
                                actionLabel: 'Создать путешествие',
                                centered: true,
                                purpleAction: true,
                                onAction: () => context.go('/create-trip'),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: activeTrips.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (_, index) {
                                  final trip = activeTrips[index];
                                  return _TripCarouselCard(
                                    trip: trip,
                                    onTap: () {
                                      context.go('/trip-workspace', extra: {
                                        'id': trip.id,
                                        'title': trip.title,
                                        'destination_city': trip.destinationCity,
                                        'start_date': trip.startDate,
                                        'end_date': trip.endDate,
                                        'planned_days': trip.plannedDays,
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Идеи для вас',
                        trailing: TextButton(
                          onPressed: () => context.go('/preferences?from=recommendations'),
                          child: const Text('Настроить'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 324,
                        child: _recommendationsLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD7E37A),
                                ),
                              )
                            : _recommendations.isEmpty
                                ? _EmptyStrip(
                                    title: 'Нет рекомендаций',
                                    subtitle: 'Заполните предпочтения, чтобы получить персональные подборки.',
                                    actionLabel: 'Открыть предпочтения',
                                    onAction: () => context.go('/preferences?from=recommendations'),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _recommendations.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (_, index) {
                                      final item = _recommendations[index];
                                      return _RecommendationCarouselCard(
                                        item: item,
                                        saved: _savedRecommendationIds.contains(item.id),
                                        onTap: () => _openRecommendationDetails(item),
                                        onSave: () => _toggleRecommendationSaved(item),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StoriesRow extends StatelessWidget {
  final List<StoryItem> stories;
  final Set<String> viewedStoryIds;
  final ValueChanged<StoryItem> onOpen;

  const _StoriesRow({
    required this.stories,
    required this.viewedStoryIds,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final story = stories[index];
          final viewed = viewedStoryIds.contains(story.id);
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onOpen(story),
            child: SizedBox(
              width: 78,
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: viewed
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFD7E37A), Color(0xFFD7E37A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: viewed ? const Color(0xFF3A3A3A) : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF161616),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _StoryImage(url: story.circleImageUrl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: viewed
                          ? Colors.white.withOpacity(0.64)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _TripCarouselCard extends StatelessWidget {
  final TripSummary trip;
  final VoidCallback onTap;

  const _TripCarouselCard({
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final city = (trip.destinationCity ?? '').trim();
    final hasPlannedDays = trip.plannedDays != null && trip.plannedDays! > 0;
    final sameDay = trip.startDate.year == trip.endDate.year &&
        trip.startDate.month == trip.endDate.month &&
        trip.startDate.day == trip.endDate.day;
    final dateLabel = sameDay
        ? '${_twoDigits(trip.startDate.day)}.${_twoDigits(trip.startDate.month)}'
        : '${_twoDigits(trip.startDate.day)}.${_twoDigits(trip.startDate.month)} - ${_twoDigits(trip.endDate.day)}.${_twoDigits(trip.endDate.month)}';

    return SizedBox(
      width: 286,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF252525), Color(0xFF171717)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: _TripPlaceholderArt()),
                  const SizedBox(height: 16),
                  Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (city.isNotEmpty)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: city,
                        ),
                      if (hasPlannedDays)
                        _MetaChip(
                          icon: Icons.schedule_outlined,
                          label: '${trip.plannedDays} дн.',
                        )
                      else
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: dateLabel,
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
  }
}

class _RecommendationCarouselCard extends StatelessWidget {
  final RecommendationItem item;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback? onSave;

  const _RecommendationCarouselCard({
    required this.item,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 286,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF1C1C1C),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 184,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: item.imageUrl.trim().isEmpty
                        ? const _RecommendationPlaceholderArt()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CorsSafeNetworkImage(
                                url: item.imageUrl,
                                fit: BoxFit.cover,
                                fallback:
                                    const _RecommendationPlaceholderArt(),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.45),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: Icons.location_on_outlined,
                                    label: item.city,
                                  ),
                                  _MetaChip(
                                    icon: Icons.star_rounded,
                                    label: item.rating.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: onSave,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFD7E37A),
                                foregroundColor: const Color(0xFF171717),
                              ),
                              icon: Icon(
                                saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_add_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFD7E37A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool centered;
  final bool purpleAction;

  const _EmptyStrip({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.centered = false,
    this.purpleAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (purpleAction)
            ElevatedButton.icon(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA996FF),
                foregroundColor: const Color(0xFF1A1530),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel),
            )
          else
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF2B879),
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'Не удалось загрузить профиль',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => onRetry(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripPlaceholderArt extends StatelessWidget {
  const _TripPlaceholderArt();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F3A1D), Color(0xFF191919)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -18,
            top: 24,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E37A).withOpacity(0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 18,
            child: Icon(
              Icons.luggage_rounded,
              size: 42,
              color: Colors.white.withOpacity(0.84),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD7E37A),
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
}

class _RecommendationPlaceholderArt extends StatelessWidget {
  const _RecommendationPlaceholderArt();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B2B2B), Color(0xFF181818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -10,
            bottom: -20,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E37A).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.landscape_rounded,
              size: 44,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryImage extends StatelessWidget {
  final String url;

  const _StoryImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3C3C3C), Color(0xFF1D1D1D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }

    return CorsSafeNetworkImage(
      url: url,
      fit: BoxFit.cover,
      fallback: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3C3C3C), Color(0xFF1D1D1D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
