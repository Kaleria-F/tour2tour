import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/checkout_redirect.dart';
import '../shared/travel_app_shell.dart';
import '../payments/payments_repo.dart';
import 'profile_repo.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({
    super.key,
    required this.profileRepo,
    required this.paymentsRepo,
  });

  final ProfileRepo profileRepo;
  final PaymentsRepo paymentsRepo;

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> with WidgetsBindingObserver {
  static const _accentColor = Color(0xFFB6A1FF);
  static const _surfaceColor = Color(0xFF1D1D1D);
  static const _premiumOwnerName = 'Фролова Валерия Андреевна';
  static const _pendingPaymentStorageKey = 'pending_premium_payment_id';

  UserMe? _me;
  bool _loading = true;
  bool _openingCheckout = false;
  bool _checkingPendingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayment();
    }
  }

  Future<void> _load() async {
    try {
      final me = await widget.profileRepo.getMe();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {
      // Keep page usable even if profile request fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    try {
      await _checkPendingPayment();
    } catch (_) {
      // Ignore storage/runtime issues in embedded webviews and protected browsers.
    }
  }

  Future<void> _storePendingPaymentId(String paymentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPaymentStorageKey, paymentId);
    } catch (_) {
      // Some protected browsers/webviews block local storage.
    }
  }

  Future<void> _clearPendingPaymentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPaymentStorageKey);
    } catch (_) {
      // Some protected browsers/webviews block local storage.
    }
  }

  Future<String?> _readPendingPaymentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pendingPaymentStorageKey);
    } catch (_) {
      // Some protected browsers/webviews block local storage.
      return null;
    }
  }

  Future<void> _checkPendingPayment() async {
    if (_checkingPendingPayment) return;
    final paymentId = await _readPendingPaymentId();
    if (paymentId == null || paymentId.trim().isEmpty) return;

    _checkingPendingPayment = true;
    try {
      final status = await widget.paymentsRepo.getPaymentStatus(paymentId);
      if (!mounted) return;
      if (status.isPremiumActivated) {
        await _clearPendingPaymentId();
        final me = await widget.profileRepo.getMe();
        if (!mounted) return;
        setState(() => _me = me);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подписка Pro активирована'),
          ),
        );
        return;
      }
      if (status.status == 'canceled') {
        await _clearPendingPaymentId();
      }
    } on DioException {
      // Retry on next open/resume.
    } finally {
      _checkingPendingPayment = false;
    }
  }
  String _paymentReturnUrl() {
    final origin = Uri.base.origin.trim();
    if (origin.isNotEmpty &&
        (origin.startsWith('https://') ||
            origin.startsWith('http://localhost') ||
            origin.startsWith('http://127.0.0.1'))) {
      return '$origin/payment-return';
    }
    return 'https://24tour2tour.ru/payment-return';
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout) return;

    setState(() => _openingCheckout = true);
    try {
      final session = await widget.paymentsRepo.createProCheckout(
        returnUrl: _paymentReturnUrl(),
        source: 'premium_page',
      );
      await _storePendingPaymentId(session.paymentId);
      final uri = Uri.tryParse(session.confirmationUrl);
      if (uri == null) {
        throw Exception('Invalid checkout url');
      }
      final opened = kIsWeb
          ? await openCheckoutRedirect(uri.toString())
          : await launchUrl(
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
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data is Map<String, dynamic>
          ? ((error.response!.data['detail'] ?? '').toString())
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isNotEmpty
                ? detail
                : 'Не удалось создать платеж. Попробуйте позже.',
          ),
        ),
      );
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
    const inn = '773771991088';

    return TravelAppShell(
      title: 'Тур2Тур Pro',
      subtitle: 'Быстрый ввод этапов маршрута и умное заполнение полей',
      currentTab: TravelNavTab.profile,
      hideHeader: true,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accentColor),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1D1D),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Тур2Тур Pro',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _BenefitCard(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Голосовой ввод',
                    subtitle:
                        'Запишите этап голосом, а приложение распознает речь и заполнит поля автоматически.',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Умное заполнение из текста',
                    subtitle:
                        'Введите мысль в свободной форме, а сервис сам распределит данные по полям этапа.',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitCard(
                    icon: Icons.schedule_rounded,
                    title: 'Быстрее, чем вручную',
                    subtitle:
                        'Меньше переключений между полями и меньше шансов упустить важные детали маршрута.',
                  ),
                  const SizedBox(height: 12),
                  _PriceCard(
                    isPremium: isPremium,
                    openingCheckout: _openingCheckout,
                    onCheckout: _openCheckout,
                  ),
                  const SizedBox(height: 12),
                  const _ExpandableInfoCard(
                    icon: Icons.sell_outlined,
                    title: 'Что я получу?',
                    body:
                        'Цифровую подписку Тур2Тур Pro сроком на 1 месяц. Подписка открывает быстрый ввод этапов маршрута голосом и текстом, а также автоматическое заполнение полей этапа.',
                  ),
                  const SizedBox(height: 10),
                  const _ExpandableInfoCard(
                    icon: Icons.download_done_rounded,
                    title: 'Как получить услугу после оплаты?',
                    body:
                        'После успешной оплаты доступ к Тур2Тур Pro на 1 месяц активируется в аккаунте пользователя. Услуга предоставляется в цифровом виде внутри приложения и веб-версии без доставки физического товара.',
                  ),
                  const SizedBox(height: 10),
                  _OfferInfoCard(
                    ownerName: _premiumOwnerName,
                    inn: inn,
                  ),
                ],
              ),
            ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.isPremium,
    required this.openingCheckout,
    required this.onCheckout,
  });

  static const _accentColor = Color(0xFFB6A1FF);

  final bool isPremium;
  final bool openingCheckout;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      '399 ₽',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Color(0xFF8C8C8C),
                        fontSize: 18,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFF8C8C8C),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '299 ₽',
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Подписка на 1 месяц',
                  style: TextStyle(
                    fontFamily: 'Geologica',
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isPremium || openingCheckout ? null : onCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: const Color(0xFF161616),
                disabledBackgroundColor: _accentColor.withOpacity(0.55),
                disabledForegroundColor:
                    const Color(0xFF161616).withOpacity(0.85),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isPremium
                    ? 'Уже подключено'
                    : openingCheckout
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

class _ExpandableInfoCard extends StatelessWidget {
  const _ExpandableInfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  static const _surfaceColor = Color(0xFF1D1D1D);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Geologica',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          children: [
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                height: 1.42,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferInfoCard extends StatelessWidget {
  const _OfferInfoCard({
    required this.ownerName,
    required this.inn,
  });

  static const _surfaceColor = Color(0xFF1D1D1D);
  static const _offerAssetPath = 'assets/legal/tour2tour_public_offer.md';

  final String ownerName;
  final String inn;

  Future<void> _openOffer(BuildContext context) async {
    try {
      final text = await rootBundle.loadString(_offerAssetPath);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 10, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Публичная оферта',
                            style: TextStyle(
                              fontFamily: 'Geologica',
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
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
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: SelectableText(
                        text,
                        style: TextStyle(
                          fontFamily: 'Geologica',
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть файл оферты'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
          title: const Text(
            'Оферта и реквизиты',
            style: TextStyle(
              fontFamily: 'Geologica',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.attach_file_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Публичная оферта Тур2Тур Pro',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Файл загружен в приложение',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openOffer(context),
                    child: const Text('Открыть'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Исполнитель: $ownerName\nИНН: ${inn.isEmpty ? 'укажите ваш ИНН в PREMIUM_INN' : inn}',
              style: TextStyle(
                fontFamily: 'Geologica',
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                height: 1.42,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}







