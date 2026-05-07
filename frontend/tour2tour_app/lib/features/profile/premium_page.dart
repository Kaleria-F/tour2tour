import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../shared/travel_app_shell.dart';
import 'profile_repo.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({
    super.key,
    required this.profileRepo,
  });

  final ProfileRepo profileRepo;

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  static const _accentColor = Color(0xFFB6A1FF);

  UserMe? _me;
  bool _loading = true;
  bool _openingCheckout = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await widget.profileRepo.getMe();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout) return;
    final rawUrl = Config.premiumCheckoutUrl.trim();
    if (rawUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка на оплату пока не настроена'),
        ),
      );
      return;
    }

    setState(() => _openingCheckout = true);
    try {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        throw Exception('Invalid checkout url');
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть страницу оплаты'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть страницу оплаты'),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = _me?.isPremium == true;
    return TravelAppShell(
      title: 'Тур2Тур Pro',
      subtitle: 'Быстрое создание точек маршрута и умное заполнение этапов',
      currentTab: TravelNavTab.profile,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accentColor),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      const Expanded(
                        child: Column(
                          children: [
                            _BenefitCard(
                              icon: Icons.graphic_eq_rounded,
                              title: 'Голосовой быстрый ввод',
                              subtitle:
                                  'Записывайте этап голосом, а приложение распознает речь и заполнит поля автоматически.',
                            ),
                            SizedBox(height: 10),
                            _BenefitCard(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Умное заполнение из текста',
                              subtitle:
                                  'Введите мысль в свободной форме, а поля этапа распределятся по местам без ручного ввода.',
                            ),
                            SizedBox(height: 10),
                            _BenefitCard(
                              icon: Icons.schedule_rounded,
                              title: 'Быстрее, чем вручную',
                              subtitle:
                                  'Меньше переключений между полями и меньше шансов пропустить важные детали маршрута.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D1D),
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Стоимость Pro',
                                    style: TextStyle(
                                      fontFamily: 'Geologica',
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '299 ₽',
                                        style: TextStyle(
                                          fontFamily: 'Geologica',
                                          color: Color(0xFF8C8C8C),
                                          fontSize: 18,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Color(0xFF8C8C8C),
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        '199 ₽',
                                        style: TextStyle(
                                          fontFamily: 'Geologica',
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: isPremium ? null : _openCheckout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentColor,
                                  foregroundColor: const Color(0xFF161616),
                                  disabledBackgroundColor:
                                      _accentColor.withOpacity(0.55),
                                  disabledForegroundColor:
                                      const Color(0xFF161616).withOpacity(0.85),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  isPremium
                                      ? 'Уже подключено'
                                      : _openingCheckout
                                          ? 'Открываем...'
                                          : 'Подключить',
                                  style: const TextStyle(
                                    fontFamily: 'Geologica',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const _accentColor = Color(0xFFB6A1FF);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accentColor.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _accentColor, size: 46),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w300,
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
