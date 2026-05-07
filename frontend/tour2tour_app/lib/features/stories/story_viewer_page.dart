import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interactions/interactions_repo.dart';
import '../profile/profile_repo.dart';
import 'stories_repo.dart';

class StoryViewerPage extends StatefulWidget {
  final StoryItem story;
  final List<StoryItem> stories;
  final int initialIndex;
  final ProfileRepo profileRepo;
  final InteractionsRepo interactionsRepo;

  const StoryViewerPage({
    super.key,
    required this.story,
    required this.stories,
    required this.initialIndex,
    required this.profileRepo,
    required this.interactionsRepo,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  bool _saving = false;
  bool _saved = false;
  late final List<StoryItem> _stories;
  late int _currentIndex;
  String? _userId;
  Set<String> _savedPlaceIds = <String>{};

  StoryItem get _currentStory => _stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _stories = widget.stories.isEmpty ? [widget.story] : List<StoryItem>.from(widget.stories);
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1) as int;
    final currentId = _currentStory.id;
    final exactIndex = _stories.indexWhere((story) => story.id == currentId);
    if (exactIndex >= 0) {
      _currentIndex = exactIndex;
    }
    _primeSavedPlaces();
  }

  String? _effectivePlaceId(StoryItem story) {
    final storyPlaceId = story.placeId?.trim();
    if (storyPlaceId != null && storyPlaceId.isNotEmpty) {
      return storyPlaceId;
    }
    final placeId = story.place?.id.trim();
    if (placeId != null && placeId.isNotEmpty) {
      return placeId;
    }
    return null;
  }

  void _syncSavedFlag() {
    final placeId = _effectivePlaceId(_currentStory);
    final isSaved = placeId != null && _savedPlaceIds.contains(placeId);
    if (mounted) {
      setState(() => _saved = isSaved);
    }
  }

  Future<void> _primeSavedPlaces() async {
    try {
      final me = await widget.profileRepo.getMe();
      final groups = await widget.interactionsRepo.getFavorites(
        userId: me.id.toString(),
      );
      if (!mounted) return;
      _userId = me.id.toString();
      _savedPlaceIds = groups
          .expand((group) => group.items)
          .map((item) => item.placeId.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      _syncSavedFlag();
    } catch (_) {}
  }

  Map<String, dynamic> _metadata(StoryItem story) {
    final place = story.place;
    final resolvedTitle = (place?.name ?? story.title).trim();
    final resolvedCity = (place?.city ?? '').trim();
    final resolvedAddress = (place?.address ?? '').trim();
    final resolvedCategory = (place?.category ?? '').trim();
    final resolvedSubcategory = (place?.subcategory ?? '').trim();
    final resolvedDescription = (place?.description ?? story.bodyText ?? '').trim();
    final resolvedImageUrl = ((place?.imageUrl ?? '').trim().isNotEmpty
            ? place!.imageUrl!
            : story.imageUrl)
        .trim();
    return {
      'title': resolvedTitle,
      'city': resolvedCity,
      'address': resolvedAddress,
      'image_url': resolvedImageUrl,
      'category': resolvedCategory,
      'subcategory': resolvedSubcategory,
      'rating': place?.rating,
      'description': resolvedDescription,
      'source': 'story',
      'story_id': story.id,
    };
  }

  Future<void> _toggleSavedPlace() async {
    final story = _currentStory;
    final place = story.place;
    final placeId = _effectivePlaceId(story);
    if (_saving || place == null || placeId == null || placeId.isEmpty) {
      return;
    }
    final wasSaved = _saved;

    setState(() => _saving = true);
    try {
      final userId = _userId ?? (await widget.profileRepo.getMe()).id.toString();
      _userId = userId;
      await widget.interactionsRepo.setFavorite(
        userId: userId,
        placeId: placeId,
        recommendationId: placeId,
        metadata: _metadata(story),
        saved: !wasSaved,
      );
      if (!mounted) return;
      setState(() {
        _saved = !wasSaved;
        _savedPlaceIds = wasSaved
            ? ({..._savedPlaceIds}..remove(placeId))
            : {..._savedPlaceIds, placeId};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Место сохранено: ${place.name}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить место в избранное')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  void _showPrevious() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex -= 1;
      _saved = _effectivePlaceId(_stories[_currentIndex]) != null &&
          _savedPlaceIds.contains(_effectivePlaceId(_stories[_currentIndex]));
    });
  }

  void _showNext() {
    if (_currentIndex >= _stories.length - 1) return;
    setState(() {
      _currentIndex += 1;
      _saved = _effectivePlaceId(_stories[_currentIndex]) != null &&
          _savedPlaceIds.contains(_effectivePlaceId(_stories[_currentIndex]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;
    final place = story.place;
    final body = (story.bodyText ?? '').trim();
    final placeDescription = (place?.description ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewer = Stack(
            fit: StackFit.expand,
            children: [
          story.imageUrl.trim().isEmpty
              ? _StoryViewerPlaceholder(title: story.title)
              : Image.network(
                  story.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _StoryViewerPlaceholder(title: story.title),
                ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.28),
                  Colors.transparent,
                  Colors.black.withOpacity(0.74),
                ],
                stops: const [0, 0.38, 1],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showPrevious,
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showNext,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Column(
                children: [
                  if (_stories.length > 1) ...[
                    Row(
                      children: List.generate(_stories.length, (index) {
                        final isActive = index == _currentIndex;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: EdgeInsets.only(
                              right: index == _stories.length - 1 ? 0 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      _OverlayIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      if (place != null)
                        _OverlayIconButton(
                          icon: _saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_outlined,
                          onTap: _saving ? null : _toggleSavedPlace,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.16,
            maxChildSize: 0.74,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111).withOpacity(0.94),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    if (place != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (place.city.isNotEmpty)
                            _StoryMetaChip(
                              icon: Icons.location_city_rounded,
                              label: place.city,
                            ),
                          if ((place.subcategory ?? '').isNotEmpty)
                            _StoryMetaChip(
                              icon: Icons.auto_awesome_rounded,
                              label: place.subcategory!,
                            )
                          else if (place.category.isNotEmpty)
                            _StoryMetaChip(
                              icon: Icons.auto_awesome_rounded,
                              label: place.category,
                            ),
                          if (place.rating != null)
                            _StoryMetaChip(
                              icon: Icons.star_rounded,
                              label: place.rating!.toStringAsFixed(1),
                            ),
                        ],
                      ),
                    ],
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (place != null) ...[
                      const SizedBox(height: 18),
                      if (place.name.isNotEmpty)
                        Text(
                          place.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if ((place.address ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          place.address!.trim(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (placeDescription.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          placeDescription,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.74),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _toggleSavedPlace,
                          icon: Icon(
                            _saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_add_outlined,
                          ),
                          label: Text(
                            _saved ? 'Уже в избранном' : 'Добавить в избранное',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
            ],
          );
          if (constraints.maxWidth <= 520) {
            return viewer;
          }
          return Center(
            child: SizedBox(
              width: 430,
              height: constraints.maxHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: viewer,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _OverlayIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.34),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _StoryMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StoryMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
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

class _StoryViewerPlaceholder extends StatelessWidget {
  final String title;

  const _StoryViewerPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4D5A35),
            Color(0xFF171B13),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
