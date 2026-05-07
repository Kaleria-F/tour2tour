import 'dart:ui';

import 'package:flutter/material.dart';

import '../interactions/interactions_repo.dart';
import '../profile/profile_repo.dart';
import '../shared/travel_app_shell.dart';
import '../trips/trips_repo.dart';

class FavoritesPage extends StatefulWidget {
  final InteractionsRepo interactionsRepo;
  final ProfileRepo profileRepo;
  final int? tripId;
  final String? city;
  final String? titleOverride;
  final String? subtitleOverride;
  final TravelNavTab currentTab;
  final TripsRepo? tripsRepo;
  final bool embedded;
  final VoidCallback? onBack;

  const FavoritesPage({
    super.key,
    required this.interactionsRepo,
    required this.profileRepo,
    this.tripId,
    this.city,
    this.titleOverride,
    this.subtitleOverride,
    this.currentTab = TravelNavTab.taste,
    this.tripsRepo,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  List<FavoriteCityGroup> _groups = const [];
  String? _currentUserId;

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
      final me = await widget.profileRepo.getMe();
      final groups = await widget.interactionsRepo.getFavorites(
        userId: me.id.toString(),
        tripId: widget.tripId,
        city: widget.city,
      );
      if (!mounted) return;
      setState(() {
        _currentUserId = me.id.toString();
        _groups = groups;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _metadata(FavoritePlace item) => {
        'title': item.title,
        'city': item.city,
        'address': item.address,
        'image_url': item.imageUrl,
        'category': item.category,
        'subcategory': item.subcategory,
        'rating': item.rating,
        'description': item.description,
        'trip_id': item.tripId ?? widget.tripId,
        'trip_title': item.tripTitle,
      };

  void _removeLocal(String placeId) {
    setState(() {
      _groups = _groups
          .map(
            (group) => FavoriteCityGroup(
              city: group.city,
              items: group.items.where((item) => item.placeId != placeId).toList(),
            ),
          )
          .where((group) => group.items.isNotEmpty)
          .toList();
    });
  }

  Future<void> _removeFavorite(FavoritePlace item) async {
    final userId = _currentUserId;
    if (userId == null) return;
    _removeLocal(item.placeId);
    try {
      await widget.interactionsRepo.trackEvent(
        userId: userId,
        placeId: item.placeId,
        action: 'dismissed',
        weight: -2,
        metadata: _metadata(item),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u0423\u0431\u0440\u0430\u043d\u043e \u0438\u0437 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u043e\u0433\u043e',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0443\u0434\u0430\u043b\u0438\u0442\u044c \u043c\u0435\u0441\u0442\u043e \u0438\u0437 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u043e\u0433\u043e',
          ),
        ),
      );
    }
  }

  Future<void> _addToTrip(FavoritePlace item) async {
    final userId = _currentUserId;
    final tripsRepo = widget.tripsRepo;
    final tripId = widget.tripId ?? item.tripId;
    if (userId == null || tripsRepo == null || tripId == null) return;

    final created = await tripsRepo.createStage(
      tripId: tripId,
      stageType: 'place',
      subtype: (item.subcategory ?? '').isEmpty ? 'attraction' : item.subcategory!,
      title: item.title,
      address: (item.address ?? '').isEmpty ? null : item.address,
      notes: (item.description ?? '').isEmpty ? null : item.description,
      rating: item.rating,
    );

    if (created == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0434\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043c\u0435\u0441\u0442\u043e \u0432 \u043c\u0430\u0440\u0448\u0440\u0443\u0442',
          ),
        ),
      );
      return;
    }

    await widget.interactionsRepo.trackEvent(
      userId: userId,
      placeId: item.placeId,
      action: 'added_to_trip',
      weight: 5,
      metadata: _metadata(item),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u0414\u043e\u0431\u0430\u0432\u043b\u0435\u043d\u043e \u0432 \u043c\u0430\u0440\u0448\u0440\u0443\u0442: ${item.title}',
        ),
      ),
    );
  }

  Future<void> _openFavoriteDetails(FavoritePlace item) async {
    final userId = _currentUserId;
    if (userId != null) {
      try {
        await widget.interactionsRepo.trackEvent(
          userId: userId,
          placeId: item.placeId,
          action: 'opened',
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
                      if ((item.address ?? '').isNotEmpty)
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: item.address!,
                        ),
                      if (item.rating != null)
                        _MetaChip(
                          icon: Icons.star_rounded,
                          label: item.rating!.toStringAsFixed(1),
                        ),
                      if ((item.subcategory ?? '').isNotEmpty)
                        _MetaChip(
                          icon: Icons.auto_awesome_rounded,
                          label: item.subcategory!,
                        )
                      else if ((item.category ?? '').isNotEmpty)
                        _MetaChip(
                          icon: Icons.auto_awesome_rounded,
                          label: item.category!,
                        ),
                    ],
                  ),
                  if ((item.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      item.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (widget.tripsRepo != null &&
                          (widget.tripId ?? item.tripId) != null) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _addToTrip(item);
                            },
                            icon: const Icon(Icons.route_rounded),
                            label: const Text('В маршрут'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _removeFavorite(item);
                          },
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          label: const Text('Убрать'),
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

  @override
  Widget build(BuildContext context) {
    final hasCityFilter = widget.city != null && widget.city!.trim().isNotEmpty;
    final filteredItems = hasCityFilter
        ? _groups.expand((group) => group.items).toList()
        : const <FavoritePlace>[];
    final title = widget.titleOverride ?? '\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435';
    final subtitle = widget.subtitleOverride ??
        (hasCityFilter
            ? '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u044b\u0435 \u043c\u0435\u0441\u0442\u0430 \u0434\u043b\u044f ${widget.city}'
            : '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043d\u044b\u0435 \u043c\u0435\u0441\u0442\u0430 \u0441\u0433\u0440\u0443\u043f\u043f\u0438\u0440\u043e\u0432\u0430\u043d\u044b \u043f\u043e \u0433\u043e\u0440\u043e\u0434\u0430\u043c');
    final content = _buildContent(hasCityFilter, filteredItems);

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onBack != null)
                TextButton.icon(
                  onPressed: widget.onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD7E37A),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('\u041a \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u044f\u043c'),
                ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _load,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B2B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: content),
        ],
      );
    }

    return TravelAppShell(
      title: title,
      subtitle: subtitle,
      currentTab: widget.currentTab,
      headerAction: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _load,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
      body: content,
    );
  }

  Widget _buildContent(bool hasCityFilter, List<FavoritePlace> filteredItems) {
    return _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
            )
          : _error != null
              ? Center(
                  child: TravelCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 34),
                        const SizedBox(height: 10),
                        const Text(
                          'Не удалось загрузить избранное',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.66),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _groups.isEmpty
                  ? const Center(
                      child: TravelCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded,
                                color: Color(0xFFD7E37A), size: 42),
                            SizedBox(height: 10),
                            Text(
                              'Пока нет избранного',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Сохраняйте рекомендации из маршрутов, и здесь появятся папки по городам.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : hasCityFilter
                      ? GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 340,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (_, index) => _FavoritePlaceTile(
                            key: ValueKey(filteredItems[index].placeId),
                            item: filteredItems[index],
                            onTap: () => _openFavoriteDetails(filteredItems[index]),
                            canAddToTrip: widget.tripsRepo != null &&
                                (widget.tripId ?? filteredItems[index].tripId) != null,
                            onAddToTrip: () => _addToTrip(filteredItems[index]),
                            onRemove: () => _removeFavorite(filteredItems[index]),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 22,
                            childAspectRatio: 0.84,
                          ),
                          itemCount: _groups.length,
                          itemBuilder: (context, index) {
                            final group = _groups[index];
                            return _CityFolderCard(
                              group: group,
                              onTap: () => _openFolder(group),
                            );
                          },
                        );
  }

  Future<void> _openFolder(FavoriteCityGroup group) async {
    final visibleItems = List<FavoritePlace>.from(group.items);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (sheetContext, controller) {
            return StatefulBuilder(
              builder: (sheetContext, modalSetState) {
                return ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Container(
                          color: const Color(0xFF1C1C1C).withOpacity(0.92),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                group.city,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${visibleItems.length} сохраненных мест',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.64),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: GridView.builder(
                                  controller: controller,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 340,
                                  ),
                                  itemCount: visibleItems.length,
                                  itemBuilder: (_, index) {
                                    final item = visibleItems[index];
                                    return _FavoritePlaceTile(
                                      key: ValueKey(item.placeId),
                                      item: item,
                                      onTap: () async {
                                        await _openFavoriteDetails(item);
                                        if (!mounted) return;
                                        final latestItems = _groups
                                            .where((entry) => entry.city == group.city)
                                            .expand((entry) => entry.items)
                                            .toList();
                                        modalSetState(() {
                                          visibleItems
                                            ..clear()
                                            ..addAll(latestItems);
                                        });
                                        if (visibleItems.isEmpty) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                      },
                                      canAddToTrip: widget.tripsRepo != null &&
                                          (widget.tripId ?? item.tripId) != null,
                                      onAddToTrip: () => _addToTrip(item),
                                      onRemove: () async {
                                        modalSetState(() {
                                          visibleItems.removeWhere(
                                            (entry) =>
                                                entry.placeId == item.placeId,
                                          );
                                        });
                                        await _removeFavorite(item);
                                        if (!mounted) return;
                                        if (visibleItems.isEmpty) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _openFolderLegacy(FavoriteCityGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (context, controller) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      color: const Color(0xFF1C1C1C).withOpacity(0.92),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        group.city,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.items.length} сохраненных мест',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.64),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: GridView.builder(
                          controller: controller,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 340,
                          ),
                          itemCount: group.items.length,
                          itemBuilder: (_, index) {
                            final item = group.items[index];
                            return _FavoritePlaceTile(
                              key: ValueKey(item.placeId),
                              item: item,
                              onTap: () => _openFavoriteDetails(item),
                              canAddToTrip: widget.tripsRepo != null &&
                                  (widget.tripId ?? item.tripId) != null,
                              onAddToTrip: () => _addToTrip(item),
                              onRemove: () => _removeFavorite(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CityFolderCard extends StatelessWidget {
  const _CityFolderCard({
    required this.group,
    required this.onTap,
  });

  final FavoriteCityGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewItems = group.items.take(3).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 6,
                  left: 24,
                  child: _FolderPreviewSheet(
                    angle: -0.06,
                    item: previewItems.isNotEmpty ? previewItems[0] : null,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 20,
                  child: _FolderPreviewSheet(
                    angle: 0.08,
                    item: previewItems.length > 1 ? previewItems[1] : null,
                  ),
                ),
                Positioned(
                  top: 22,
                  left: 8,
                  right: 8,
                  bottom: 18,
                  child: _GlassFolderFront(
                    city: group.city,
                    count: group.items.length,
                    stickerCount: previewItems.length,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            group.city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${group.items.length} мест',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderPreviewSheet extends StatelessWidget {
  const _FolderPreviewSheet({
    required this.angle,
    required this.item,
  });

  final double angle;
  final FavoritePlace? item;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 72,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
          image: item?.imageUrl != null && item!.imageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(item!.imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: item?.imageUrl == null || item!.imageUrl!.isEmpty
            ? Center(
                child: Icon(
                  Icons.photo_rounded,
                  color: Colors.black.withOpacity(0.28),
                  size: 28,
                ),
              )
            : null,
      ),
    );
  }
}

class _GlassFolderFront extends StatelessWidget {
  const _GlassFolderFront({
    required this.city,
    required this.count,
    required this.stickerCount,
  });

  final String city;
  final int count;
  final int stickerCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.36),
                Colors.white.withOpacity(0.18),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 84,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      bottomRight: Radius.circular(22),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: Wrap(
                  spacing: 8,
                  children: List.generate(
                    stickerCount.clamp(1, 2),
                    (index) => Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      child: Icon(
                        index.isEven
                            ? Icons.place_outlined
                            : Icons.auto_awesome_rounded,
                        size: 15,
                        color: const Color(0xFF3B3B3B),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF4F4F4),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count сохранений',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
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

class _FavoritePlaceTile extends StatelessWidget {
  const _FavoritePlaceTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRemove,
    required this.onAddToTrip,
    required this.canAddToTrip,
  });

  final FavoritePlace item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onAddToTrip;
  final bool canAddToTrip;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('favorite-${item.placeId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE7B0A4).withOpacity(0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7B0A4).withOpacity(0.38)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE7B0A4)),
      ),
      onDismissed: (_) => onRemove(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
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
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _FavoriteThumbFallback(city: item.city),
                              )
                            : _FavoriteThumbFallback(city: item.city),
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
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: IconButton(
                            onPressed: onRemove,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFD7E37A),
                              foregroundColor: const Color(0xFF171717),
                            ),
                            icon: const Icon(Icons.bookmark_remove_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Geologica',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (item.description ?? '').trim().isEmpty
                            ? (item.address ?? item.city)
                            : item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geologica',
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.location_on_outlined,
                            label: item.city,
                          ),
                          if (item.rating != null)
                            _MetaChip(
                              icon: Icons.star_rounded,
                              label: item.rating!.toStringAsFixed(1),
                            ),
                          if ((item.tripTitle ?? '').isNotEmpty)
                            _MetaChip(
                              icon: Icons.route_rounded,
                              label: item.tripTitle!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (canAddToTrip)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: onAddToTrip,
                                icon: const Icon(Icons.route_rounded, size: 16),
                                label: const Text('В маршрут'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD7E37A),
                                  foregroundColor: const Color(0xFF171717),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

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
                fontFamily: 'Geologica',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteThumbFallback extends StatelessWidget {
  const _FavoriteThumbFallback({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5A6653),
            Color(0xFF283126),
          ],
        ),
      ),
      child: Center(
        child: Text(
          city.substring(0, city.isEmpty ? 0 : 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
