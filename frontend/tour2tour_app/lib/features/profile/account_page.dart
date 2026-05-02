import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repo.dart';
import '../shared/travel_app_shell.dart';
import '../trips/trips_repo.dart';
import 'avatar_image.dart';
import 'profile_repo.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.profileRepo,
    required this.tripsRepo,
    required this.authRepo,
  });

  final ProfileRepo profileRepo;
  final TripsRepo tripsRepo;
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

  String _formatDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
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
                            backgroundImage: buildAvatarImage(_me?.avatarUrl),
                            child: buildAvatarImage(_me?.avatarUrl) == null
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
                                  : 'Путешественник',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openEditAccount,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Изменить'),
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
                      TravelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Подписка'),
                            const SizedBox(height: 10),
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
                                    color: const Color(0xFF2B2B2B),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Нет Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.info_outline_rounded),
                                  label: const Text('Оплата и подписка'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2B2B2B),
                                    foregroundColor: Colors.white70,
                                    elevation: 0,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
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
                      Row(
                        children: [
                          Expanded(child: _sectionTitle('Мои поездки')),
                          IconButton(
                            tooltip: _tripsExpanded ? 'Свернуть' : 'Развернуть',
                            onPressed: () {
                              setState(() {
                                _tripsExpanded = !_tripsExpanded;
                              });
                            },
                            icon: AnimatedRotation(
                              turns: _tripsExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 180),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        firstCurve: Curves.easeOut,
                        secondCurve: Curves.easeIn,
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: _tripsExpanded
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: _trips.isEmpty
                            ? TravelCard(
                                child: Text(
                                  'Пока нет путешествий',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : Column(
                                children: _trips
                                    .map(
                                      (trip) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _TripRowCard(
                                          trip: trip,
                                          formatDate: _formatDate,
                                          onTap: () {
                                            context.go(
                                              '/trip-workspace',
                                              extra: {
                                                'id': trip.id,
                                                'title': trip.title,
                                                'destination_city': trip.destinationCity,
                                                'start_date': trip.startDate,
                                                'end_date': trip.endDate,
                                                'planned_days': trip.plannedDays,
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loggingOut ? null : _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(_loggingOut ? 'Выходим...' : 'Выйти'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A3F2E),
                            foregroundColor: Colors.white,
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
    final dateText =
        '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D1D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
              child: const Icon(
                Icons.luggage_rounded,
                color: Color(0xFFD7E37A),
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
                      fontSize: 13,
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
}
