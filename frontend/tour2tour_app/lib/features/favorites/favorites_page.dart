import 'dart:ui';

import 'package:flutter/material.dart';

import '../interactions/interactions_repo.dart';
import '../profile/profile_repo.dart';
import '../shared/travel_app_shell.dart';

class FavoritesPage extends StatefulWidget {
  final InteractionsRepo interactionsRepo;
  final ProfileRepo profileRepo;

  const FavoritesPage({
    super.key,
    required this.interactionsRepo,
    required this.profileRepo,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  List<FavoriteCityGroup> _groups = const [];

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
      );
      if (!mounted) return;
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    return TravelAppShell(
      title: 'Избранное',
      subtitle: 'Сохраненные места сгруппированы по городам',
      currentTab: TravelNavTab.taste,
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
      body: _loading
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
                    ),
    );
  }

  Future<void> _openFolder(FavoriteCityGroup group) async {
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
                        child: ListView.separated(
                          controller: controller,
                          itemCount: group.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final item = group.items[index];
                            return _FavoritePlaceTile(item: item);
                          },
                        ),
                      ),
                    ],
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
  const _FavoritePlaceTile({required this.item});

  final FavoritePlace item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _FavoriteThumbFallback(city: item.city),
                    )
                  : _FavoriteThumbFallback(city: item.city),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if ((item.address ?? '').isNotEmpty)
                  Text(
                    item.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 12.5,
                    ),
                  ),
                if ((item.tripTitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E37A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.tripTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD7E37A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.rating != null)
            Column(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFD7E37A), size: 18),
                const SizedBox(height: 4),
                Text(
                  item.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
