import 'dart:ui';

import 'package:flutter/material.dart';

import '../interactions/interactions_repo.dart';
import '../profile/profile_repo.dart';
import '../recommendations/recommendation_labels.dart';
import '../shared/travel_app_shell.dart';
import '../trips/trips_repo.dart';

class FavoritesPage extends StatefulWidget {
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

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const _primaryColor = Color(0xFFD7E37A);
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
      setState(() => _error = e.toString());
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

  void _showFeedback(String message) {
    final width = MediaQuery.of(context).size.width;
    final snackWidth = width > 462 ? 430.0 : width - 32;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: snackWidth,
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Geologica',
            color: Color(0xFF171717),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

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
      _showFeedback('Убрано из сохраненного');
    } catch (_) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _showFeedback('Не удалось удалить место из сохраненного');
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
      _showFeedback('Не удалось добавить место в маршрут');
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
    _showFeedback('Добавлено в маршрут: ${item.title}');
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
    final showCityChip = !((widget.city ?? '').trim().isNotEmpty);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1D),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 290,
                      width: double.infinity,
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
                                  Colors.black.withOpacity(0.42),
                                  Colors.black.withOpacity(0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: IconButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.34),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: IconButton(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _removeFavorite(item);
                              },
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontFamily: 'Geologica',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (showCityChip)
                                _MetaChip(
                                  icon: Icons.location_on_rounded,
                                  label: item.city,
                                ),
                              if ((item.address ?? '').isNotEmpty)
                                _MetaChip(
                                  icon: Icons.place_outlined,
                                  label: item.address!,
                                ),
                              if ((item.subcategory ?? '').isNotEmpty)
                                _MetaChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: recommendationTagLabel(item.subcategory!),
                                )
                              else if ((item.category ?? '').isNotEmpty)
                                _MetaChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: recommendationTagLabel(item.category!),
                                ),
                            ],
                          ),
                          if ((item.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontFamily: 'Geologica',
                                color: Colors.white.withOpacity(0.84),
                                height: 1.45,
                                fontWeight: FontWeight.w300,
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD7E37A),
                                      foregroundColor: const Color(0xFF171717),
                                    ),
                                    onPressed: () async {
                                      Navigator.of(dialogContext).pop();
                                      await _addToTrip(item);
                                    },
                                    icon: const Icon(Icons.route_rounded),
                                    label: const Text('Добавить в маршрут'),
                                  ),
                                ),
                              ],
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
    final title = widget.titleOverride ?? 'Избранное';
    final subtitle = widget.subtitleOverride ?? '';
    final content = _buildContent(hasCityFilter, filteredItems);

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            TextButton.icon(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD7E37A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('К рекомендациям'),
            ),
          if (widget.onBack != null) const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Geologica',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w400,
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
      headerAction: const SizedBox(width: 48, height: 48),
      body: content,
    );
  }

  Widget _buildContent(bool hasCityFilter, List<FavoritePlace> filteredItems) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
      );
    }

    if (_error != null) {
      return Center(
        child: TravelCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                'Не удалось загрузить сохраненные места',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Geologica',
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasCityFilter) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 340,
        ),
        itemCount: filteredItems.length,
        itemBuilder: (_, index) {
          final item = filteredItems[index];
          return _FavoritePlaceTile(
            key: ValueKey(item.placeId),
            item: item,
            showCityChip: false,
            onTap: () => _openFavoriteDetails(item),
            canAddToTrip:
                widget.tripsRepo != null && (widget.tripId ?? item.tripId) != null,
            onAddToTrip: () => _addToTrip(item),
            onRemove: () => _removeFavorite(item),
          );
        },
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 22,
        childAspectRatio: 1.04,
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
                                  fontFamily: 'Geologica',
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${visibleItems.length} мест',
                                style: TextStyle(
                                  fontFamily: 'Geologica',
                                  color: Colors.white.withOpacity(0.64),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
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
                                      showCityChip: false,
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
                                            (entry) => entry.placeId == item.placeId,
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
    final previewItems = group.items.take(2).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 2,
            left: 20,
            child: _FolderPreviewSheet(
              angle: -0.05,
              item: previewItems.isNotEmpty ? previewItems[0] : null,
            ),
          ),
          Positioned(
            top: 8,
            right: 18,
            child: _FolderPreviewSheet(
              angle: 0.06,
              item: previewItems.length > 1 ? previewItems[1] : null,
            ),
          ),
          Positioned(
            top: 18,
            left: 8,
            right: 8,
            bottom: 14,
            child: _GlassFolderFront(
              city: group.city,
              count: group.items.length,
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
        width: 64,
        height: 78,
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
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: item?.imageUrl != null && item!.imageUrl!.isNotEmpty
              ? Image.network(
                  item!.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.photo_rounded,
                      color: Colors.black.withOpacity(0.28),
                      size: 24,
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.photo_rounded,
                    color: Colors.black.withOpacity(0.28),
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlassFolderFront extends StatelessWidget {
  const _GlassFolderFront({
    required this.city,
    required this.count,
  });

  final String city;
  final int count;

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
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geologica',
                    color: Color(0xFFF4F4F4),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count мест',
                  style: TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w300,
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

class _FavoritePlaceTile extends StatelessWidget {
  const _FavoritePlaceTile({
    super.key,
    required this.item,
    required this.showCityChip,
    required this.onTap,
    required this.onRemove,
    required this.onAddToTrip,
    required this.canAddToTrip,
  });

  final FavoritePlace item;
  final bool showCityChip;
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
                  height: 150,
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
                          if ((item.subcategory ?? '').isNotEmpty)
                            _MetaChip(
                              icon: Icons.auto_awesome_rounded,
                              label: recommendationTagLabel(item.subcategory!),
                            )
                          else if ((item.category ?? '').isNotEmpty)
                            _MetaChip(
                              icon: Icons.auto_awesome_rounded,
                              label: recommendationTagLabel(item.category!),
                            ),
                          if (showCityChip)
                            _MetaChip(
                              icon: Icons.location_on_outlined,
                              label: item.city,
                            ),
                          if ((item.tripTitle ?? '').isNotEmpty)
                            _RouteBadge(
                              tooltip: item.tripTitle!,
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

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFD7E37A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD7E37A).withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.route_rounded,
          size: 18,
          color: Color(0xFF171717),
        ),
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
          city.isEmpty ? '' : city.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontFamily: 'Geologica',
            color: Colors.white.withOpacity(0.8),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
