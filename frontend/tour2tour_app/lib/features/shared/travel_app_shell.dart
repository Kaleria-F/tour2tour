import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum TravelNavTab { home, planner, taste, profile }

class TravelAppShell extends StatelessWidget {
  const TravelAppShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.currentTab,
    this.headerAction,
    this.maxWidth = 430,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final TravelNavTab currentTab;
  final Widget? headerAction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _TravelShellBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TravelShellHeader(
                        title: title,
                        subtitle: subtitle,
                        action: headerAction,
                      ),
                      const SizedBox(height: 18),
                      Expanded(child: body),
                      const SizedBox(height: 18),
                      TravelBottomNavBar(currentTab: currentTab),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TravelCard extends StatelessWidget {
  const TravelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class TravelSearchBar extends StatelessWidget {
  const TravelSearchBar({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.white.withOpacity(0.66),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class TravelCapsuleButton extends StatelessWidget {
  const TravelCapsuleButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlight = const Color(0xFFD7E37A);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF222715) : const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? highlight.withOpacity(0.75) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: active ? highlight : Colors.white.withOpacity(0.72),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? highlight : Colors.white.withOpacity(0.78),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelShellHeader extends StatelessWidget {
  const _TravelShellHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        action ??
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white),
            ),
      ],
    );
  }
}

class TravelBottomNavBar extends StatelessWidget {
  const TravelBottomNavBar({super.key, required this.currentTab});

  final TravelNavTab currentTab;

  @override
  Widget build(BuildContext context) {
    const items = [
      (TravelNavTab.home, Icons.home_outlined, 'Главная'),
      (TravelNavTab.planner, Icons.explore_outlined, 'Маршрут'),
      (TravelNavTab.taste, Icons.bookmark_border_rounded, 'Избранное'),
      (TravelNavTab.profile, Icons.person_outline_rounded, 'Профиль'),
    ];

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: items.map((item) {
          final selected = item.$1 == currentTab;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _go(context, item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF242424) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$2,
                      size: 22,
                      color: selected
                          ? const Color(0xFFD7E37A)
                          : Colors.white.withOpacity(0.72),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFFD7E37A)
                            : Colors.white.withOpacity(0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _go(BuildContext context, TravelNavTab tab) {
    switch (tab) {
      case TravelNavTab.home:
        context.go('/profile');
        break;
      case TravelNavTab.planner:
        context.go('/create-trip');
        break;
      case TravelNavTab.taste:
        context.go('/favorites');
        break;
      case TravelNavTab.profile:
        context.go('/profile');
        break;
    }
  }
}

class _TravelShellBackground extends StatelessWidget {
  const _TravelShellBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TravelShellPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TravelShellPainter extends CustomPainter {
  final _rng = math.Random(12);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF151515), Color(0xFF0F0F0F)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6D7B33).withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.15, size.height * 0.82),
        radius: size.width * 0.5,
      ));
    canvas.drawRect(rect, glowPaint);

    final dotBright = Paint()..color = Colors.white.withOpacity(0.07);
    final dotDim = Paint()..color = Colors.white.withOpacity(0.03);
    final count = (size.width * size.height / 10000).clamp(40, 90).toInt();
    for (var i = 0; i < count; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height * 0.35;
      final r = _rng.nextDouble() * 1.1 + 0.2;
      canvas.drawCircle(Offset(x, y), r, i.isEven ? dotBright : dotDim);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
