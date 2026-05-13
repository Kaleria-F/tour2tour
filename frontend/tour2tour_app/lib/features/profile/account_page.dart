import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repo.dart';
import '../documents/documents_repo.dart';
import '../shared/travel_app_shell.dart';
import '../trips/trips_repo.dart';
import 'avatar_image.dart';
import 'profile_repo.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.profileRepo,
    required this.tripsRepo,
    required this.documentsRepo,
    required this.authRepo,
  });

  final ProfileRepo profileRepo;
  final TripsRepo tripsRepo;
  final DocumentsRepo documentsRepo;
  final AuthRepo authRepo;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  UserMe? _me;
  List<TripSummary> _trips = const [];
  bool _tripsExpanded = false;
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;

  String _formatPremiumExpiry(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

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
        widget.profileRepo.getMe(),
        widget.tripsRepo.listTrips(),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as UserMe;
        _trips = results[1] as List<TripSummary>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await widget.authRepo.logout();
      if (!mounted) return;
      context.go('/login');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _openEditAccount() async {
    await context.push('/edit-account');
    if (!mounted) return;
    await _load();
  }

  Future<void> _openSupport() async {
    await context.push('/support');
  }

  Future<void> _openMyDocumentsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Мои поездки', style: TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 12),
                Expanded(
                  child: _trips.isEmpty
                      ? const Center(child: Text('Пока нет поездок', style: TextStyle(color: Colors.white70)))
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 4),
                          itemCount: _trips.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final trip = _trips[i];
                            return _TripRowCard(
                              trip: trip,
                              formatDate: _formatDate,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go('/trip-workspace', extra: {
                                  'id': trip.id,
                                  'title': trip.title,
                                  'destination_city': trip.destinationCity,
                                  'start_date': trip.startDate,
                                  'end_date': trip.endDate,
                                  'planned_days': trip.plannedDays,
                                  'card_color': trip.cardColor,
                                  'card_background': trip.cardBackground,
                                  'card_icon': trip.cardIcon,
                                });
                              },
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD7E37A),
                      foregroundColor: const Color(0xFF171717),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSharedDocumentsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SharedDocumentsDialog(documentsRepo: widget.documentsRepo),
    );
  }

  String _formatDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = buildAvatarImage(_me?.avatarUrl);
    return TravelAppShell(
      title: 'Профиль',
      subtitle: 'Учетная запись и настройки безопасности',
      currentTab: TravelNavTab.profile,
      hideHeader: true,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Не удалось загрузить профиль',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF2B2B2B),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 28,
                                    color: Color(0xFFD7E37A),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _me?.displayName?.trim().isNotEmpty == true
                                  ? _me!.displayName!
                                  : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TravelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Мои данные'),
                            const SizedBox(height: 10),
                            _infoRow('Имя', _me?.displayName?.trim().isNotEmpty == true ? _me!.displayName! : 'Не указано'),
                            const SizedBox(height: 8),
                            _infoRow('Почта', _me?.email ?? 'Не указана'),
                            const SizedBox(height: 8),
                            _infoRow('Телефон', _me?.phone ?? 'Не указан'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFB6A1FF).withOpacity(0.18),
                              const Color(0xFFB6A1FF).withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFB6A1FF).withOpacity(0.34),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB6A1FF).withOpacity(0.16),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB6A1FF).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Color(0xFFB6A1FF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Тур2Тур Pro',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _me?.isPremium == true
                                            ? 'Активна до ${_formatPremiumExpiry(_me?.premiumExpiresAt)}'
                                            : 'Быстрый ввод и умное заполнение этапов',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.72),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB6A1FF).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFB6A1FF).withOpacity(0.34),
                                    ),
                                  ),
                                  child: Text(
                                    _me?.isPremium == true
                                        ? 'Подключена'
                                        : 'Не подключена',
                                    style: const TextStyle(
                                      color: Color(0xFFB6A1FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/premium'),
                                  icon: const Icon(Icons.workspace_premium_rounded),
                                  label: const Text('Оплата и подписка'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB6A1FF),
                                    foregroundColor: const Color(0xFF1C1627),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TravelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Настройки'),
                            const SizedBox(height: 4),
                            Text(
                              'Конфиденциальность и безопасность',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _settingsTile(
                              icon: Icons.manage_accounts_outlined,
                              title: 'Редактировать профиль',
                              subtitle: 'Имя, фото, почта и телефон',
                              onTap: _openEditAccount,
                            ),
                            _settingsTile(
                              icon: Icons.lock_outline_rounded,
                              title: 'Смена пароля',
                              subtitle: 'Обновить пароль аккаунта',
                              onTap: () => context.push('/change-password'),
                            ),
                            _settingsTile(
                              icon: Icons.verified_user_outlined,
                              title: 'Двухфакторная аутентификация',
                              subtitle: _me?.is2faEnabled == true
                                  ? 'Включена'
                                  : 'Не включена',
                              onTap: () => context.push('/security-setup'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Документы'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassFolderTile(
                              title: 'Общие\nдокументы',
                              onTap: _openSharedDocumentsDialog,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlassFolderTile(
                              title: 'Мои\nпоездки',
                              onTap: _openMyDocumentsDialog,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loggingOut ? null : _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(_loggingOut ? 'Выходим...' : 'Выйти'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD7E37A),
                            foregroundColor: const Color(0xFF171717),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openSupport,
                          icon: const Icon(Icons.support_agent_rounded),
                          label: const Text('Связаться с командой приложения'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD7E37A),
                            side: BorderSide(
                              color: const Color(0xFFD7E37A).withOpacity(0.55),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 34,
      leading: Icon(icon, color: const Color(0xFFD7E37A)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.62),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
      onTap: onTap,
    );
  }
}

class _TripRowCard extends StatelessWidget {
  const _TripRowCard({
    required this.trip,
    required this.onTap,
    required this.formatDate,
  });

  final TripSummary trip;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final hasPlannedDays = trip.plannedDays != null && trip.plannedDays! > 0;
    final dateText = hasPlannedDays
        ? '${trip.plannedDays} дн.'
        : '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}';
    final cardIcon = (trip.cardIcon ?? '').trim().toLowerCase();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF242424), Color(0xFF171717)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconByKey(cardIcon),
                color: const Color(0xFFD7E37A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
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

class _GlassFolderTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _GlassFolderTile({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: SizedBox(
        height: 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: 2,
              left: 20,
              child: _FolderPreviewSheet(angle: -0.05),
            ),
            const Positioned(
              top: 8,
              right: 18,
              child: _FolderPreviewSheet(angle: 0.06),
            ),
            Positioned(
              top: 18,
              left: 8,
              right: 8,
              bottom: 14,
              child: _GlassFolderFront(title: title),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderPreviewSheet extends StatelessWidget {
  const _FolderPreviewSheet({required this.angle});
  final double angle;

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
        child: Center(
          child: Icon(
            Icons.description_rounded,
            color: Colors.black.withOpacity(0.28),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _GlassFolderFront extends StatelessWidget {
  const _GlassFolderFront({required this.title});

  final String title;

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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geologica',
                    color: Color(0xFFF4F4F4),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
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

class _SharedDocumentsDialog extends StatefulWidget {
  const _SharedDocumentsDialog({required this.documentsRepo});

  final DocumentsRepo documentsRepo;

  @override
  State<_SharedDocumentsDialog> createState() => _SharedDocumentsDialogState();
}

class _SharedDocumentsDialogState extends State<_SharedDocumentsDialog> {
  List<TripDocument> _docs = const [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.documentsRepo.listSharedDocuments();
      if (!mounted) return;
      setState(() => _docs = items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить общие документы')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;

    final contentType = _resolveContentType(f.name);
    if (contentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Разрешены только PDF, JPG и PNG')),
      );
      return;
    }
    final customName = await _openNameDialog(f.name);
    if (customName == null) return;
    final targetName = _buildTargetFileName(
      customTitle: customName,
      originalFileName: f.name,
    );

    setState(() => _uploading = true);
    try {
      await widget.documentsRepo.uploadSharedBytesDirect(
        fileName: targetName,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ загружен')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки документа')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _rename(TripDocument doc) async {
    final customName = await _openNameDialog(doc.fileName);
    if (customName == null) return;
    final targetName = _buildTargetFileName(
      customTitle: customName,
      originalFileName: doc.fileName,
    );
    try {
      final updated = await widget.documentsRepo.renameSharedObject(
        objectKey: doc.objectKey,
        fileName: targetName,
      );
      if (!mounted) return;
      setState(() {
        _docs = _docs
            .map((e) => e.objectKey == updated.objectKey ? updated : e)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название обновлено')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось переименовать документ')),
      );
    }
  }

  Future<void> _delete(TripDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        title: const Text('Удалить документ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Документ "${doc.fileName}" будет удален без возможности восстановления.',
          style: TextStyle(color: Colors.white.withOpacity(0.84)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7E37A),
              foregroundColor: const Color(0xFF171717),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.documentsRepo.deleteSharedObject(doc.objectKey);
      if (!mounted) return;
      setState(() {
        _docs = _docs.where((e) => e.objectKey != doc.objectKey).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ удален')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить документ')),
      );
    }
  }

  String? _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
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

  String _buildTargetFileName({
    required String customTitle,
    required String originalFileName,
  }) {
    final clean = customTitle.trim();
    final ext = _fileExtension(originalFileName);
    if (ext.isEmpty) return clean;
    if (clean.toLowerCase().endsWith(ext.toLowerCase())) return clean;
    return '$clean$ext';
  }

  Future<String?> _openNameDialog(String sourceName) async {
    final controller = TextEditingController(
      text: _fileNameWithoutExtension(sourceName),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        title: const Text(
          'Название документа',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Введите название',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFD7E37A)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7E37A),
              foregroundColor: const Color(0xFF171717),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1D1D1D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Общие документы', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD7E37A),
                    foregroundColor: const Color(0xFF171717),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_rounded),
                  label: const Text('Загрузить документ'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _docs.isEmpty
                        ? const Center(
                            child: Text('Пока нет общих документов', style: TextStyle(color: Colors.white70)),
                          )
                        : ListView.separated(
                            itemCount: _docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final doc = _docs[i];
                              return ListTile(
                                tileColor: Colors.white.withOpacity(0.06),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: const Icon(Icons.description_outlined, color: Colors.white),
                                title: Text(doc.fileName, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(_fmtBytes(doc.sizeBytes), style: const TextStyle(color: Colors.white70)),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'Переименовать',
                                      onPressed: () => _rename(doc),
                                      color: const Color(0xFFD7E37A),
                                      icon: const Icon(Icons.edit_rounded),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      onPressed: () => _delete(doc),
                                      color: const Color(0xFFD7E37A),
                                      icon: const Icon(Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD7E37A),
                    foregroundColor: const Color(0xFF171717),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
