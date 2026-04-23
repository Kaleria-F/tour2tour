import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../preferences/preferences_repo.dart';
import '../recommendations/recommendations_repo.dart';
import '../shared/travel_app_shell.dart';
import '../trips/trips_repo.dart';
import 'profile_repo.dart';

class ProfilePage extends StatefulWidget {
  final ProfileRepo repo;
  final TripsRepo tripsRepo;
  final PreferencesRepo preferencesRepo;
  final RecommendationsRepo recommendationsRepo;

  const ProfilePage({
    super.key,
    required this.repo,
    required this.tripsRepo,
    required this.preferencesRepo,
    required this.recommendationsRepo,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _storyLabels = [
    'Для вас',
    'Москва',
    'Природа',
    'Еда',
    'Маршруты',
  ];

  UserMe? _me;
  SurveyProfile? _surveyProfile;
  List<TripSummary> _trips = const [];
  List<RecommendationItem> _recommendations = const [];
  bool _loading = true;
  bool _recommendationsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
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
      await _loadRecommendations();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
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
        userId: _me?.id?.toString(),
      );
      if (!mounted) return;
      setState(() {
        _recommendations = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendations = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _recommendationsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TravelAppShell(
      title: 'Привет',
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
                      _StoriesRow(labels: _storyLabels),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: 'Мои поездки',
                        actionLabel: 'Все',
                        onTap: () => context.go('/create-trip'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 248,
                        child: _trips.isEmpty
                            ? const _EmptyStrip(
                                title: 'Пока нет поездок',
                                subtitle: 'Создайте первое путешествие, и здесь появятся ваши маршруты.',
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _trips.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (_, index) {
                                  final trip = _trips[index];
                                  return _TripCarouselCard(
                                    trip: trip,
                                    onTap: () {
                                      context.go(
                                        '/trip-workspace',
                                        extra: {
                                          'id': trip.id,
                                          'title': trip.title,
                                          'destination_city':
                                              trip.destinationCity,
                                          'start_date': trip.startDate,
                                          'end_date': trip.endDate,
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        title: 'Рекомендации',
                        actionLabel: 'Настроить',
                        onTap: () => context.go('/preferences'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 248,
                        child: _recommendationsLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD7E37A),
                                ),
                              )
                            : _recommendations.isEmpty
                                ? const _EmptyStrip(
                                    title: 'Пока нет рекомендаций',
                                    subtitle: 'Пройдите опрос предпочтений, и подборка появится здесь.',
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _recommendations.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (_, index) {
                                      final item = _recommendations[index];
                                      return _RecommendationCarouselCard(
                                        item: item,
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _fmtDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFD7E37A),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final label = labels[index];
          return Column(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD7E37A),
                      Color(0xFF6E7A34),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E1E1E),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFD7E37A),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripCarouselCard extends StatelessWidget {
  const _TripCarouselCard({
    required this.trip,
    required this.onTap,
  });

  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final city = trip.destinationCity;
    final cityLabel = city == null || city.isEmpty ? 'Маршрут' : city;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: SizedBox(
        width: 240,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xFF1D1D1D),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _TripPlaceholderArt(seed: trip.id, city: cityLabel),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.24),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.north_east_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cityLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_rounded,
                          label:
                              '${_twoDigits(trip.startDate.day)}.${_twoDigits(trip.startDate.month)}',
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.route_rounded,
                          label:
                              '${_twoDigits(trip.endDate.day)}.${_twoDigits(trip.endDate.month)}',
                        ),
                      ],
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

class _RecommendationCarouselCard extends StatelessWidget {
  const _RecommendationCarouselCard({required this.item});

  final RecommendationItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0xFF1D1D1D),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.imageUrl.isNotEmpty
                ? Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _RecommendationPlaceholderArt(
                      city: item.city,
                    ),
                  )
                : _RecommendationPlaceholderArt(city: item.city),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.24),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.star_rounded,
                        label: item.rating.toStringAsFixed(1),
                      ),
                      const SizedBox(width: 8),
                      _MetaChip(
                        icon: Icons.auto_awesome_rounded,
                        label: item.category,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return TravelCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFD7E37A),
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.64),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TravelCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить экран',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TravelCapsuleButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              active: true,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripPlaceholderArt extends StatelessWidget {
  const _TripPlaceholderArt({
    required this.seed,
    required this.city,
  });

  final int seed;
  final String city;

  @override
  Widget build(BuildContext context) {
    final gradients = [
      const [Color(0xFF6F826A), Color(0xFF2E3F2B)],
      const [Color(0xFF8A6D58), Color(0xFF493427)],
      const [Color(0xFF697C8F), Color(0xFF24313D)],
      const [Color(0xFF7A5F6B), Color(0xFF35242C)],
    ];
    final palette = gradients[seed % gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 18,
            left: 18,
            child: Text(
              city,
              style: TextStyle(
                color: Colors.white.withOpacity(0.16),
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -10,
            right: -10,
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.black.withOpacity(0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPlaceholderArt extends StatelessWidget {
  const _RecommendationPlaceholderArt({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A4438),
            Color(0xFF1D231C),
          ],
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
