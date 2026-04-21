import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _authBackgroundAsset = 'assets/images/russian_landscape_bg.jpg';
const _authDesktopBackgroundAsset = 'assets/images/lanscape_bg_pk.png';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.fromLTRB(12, 16, 12, 18),
  });

  final Widget child;
  final Alignment alignment;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final effectiveMaxWidth = isDesktop && maxWidth > 580 ? 580.0 : maxWidth;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _LandscapeBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : alignment,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
                        child: Padding(
                          padding: isDesktop
                              ? const EdgeInsets.fromLTRB(156, 24, 24, 24)
                              : padding,
                          child: child,
                        ),
                      ),
                    ),
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

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            color: Colors.white.withOpacity(isDesktop ? 0.30 : 0.18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(isDesktop ? 0.52 : 0.34),
                const Color(0xFFF8F1EC).withOpacity(isDesktop ? 0.34 : 0.22),
                const Color(0xFFE9DDD5).withOpacity(isDesktop ? 0.22 : 0.14),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.title = 'Typ2Typ', this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF403734),
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12.5,
              color: const Color(0xFF403734).withOpacity(0.70),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthHeadline extends StatelessWidget {
  const AuthHeadline({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.fontSize = 46,
    this.fontWeight = FontWeight.w600,
    this.titleHeight = 0.92,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final double fontSize;
  final FontWeight fontWeight;
  final double titleHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  height: titleHeight,
                  fontWeight: fontWeight,
                  color: Colors.black,
                  letterSpacing: -1.2,
                ),
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.38,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF2F241F).withOpacity(0.72),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.child,
    required this.icon,
    this.height = 66,
  });

  final Widget child;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(
          color: Colors.white.withOpacity(0.48),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2B2B2B)),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(-12, 0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPillButton extends StatelessWidget {
  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.minimumSize,
    this.fontSize = 13,
    this.iconSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Size? minimumSize;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconWidget = icon == null
        ? null
        : Icon(icon, size: iconSize, color: const Color(0xFF232323));

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF232323),
        side: BorderSide(color: Colors.black.withOpacity(0.28), width: 1),
        backgroundColor: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: minimumSize,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconWidget != null) ...[
            iconWidget,
            const SizedBox(width: 8),
          ],
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class AuthOrganicButton extends StatelessWidget {
  const AuthOrganicButton({
    super.key,
    this.label,
    required this.onTap,
    this.loading = false,
    this.width = 140,
  });

  final String? label;
  final VoidCallback? onTap;
  final bool loading;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Opacity(
        opacity: onTap == null && !loading ? 0.6 : 1,
        child: SizedBox(
          width: width,
          height: 72,
          child: label == null
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD5B09A),
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                  ),
                )
              : Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Positioned(
                      left: 0,
                      right: 20,
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5B09A).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 22, right: 52),
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF8F4F0),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD5B09A),
                        ),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.inputFormatters,
    this.suffix,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return AuthInputField(
      icon: icon,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autofillHints: autofillHints,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              maxLength: maxLength,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F1B19),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ).copyWith(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF2F2A28),
                ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 10),
            suffix!,
          ],
        ],
      ),
    );
  }
}

class AuthInlineLink extends StatelessWidget {
  const AuthInlineLink({
    super.key,
    required this.text,
    required this.linkLabel,
    required this.onTap,
  });

  final String text;
  final String linkLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.88),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              linkLabel,
              style: const TextStyle(
                color: Color(0xFFF8E8DA),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthSectionChip extends StatelessWidget {
  const AuthSectionChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFF2F241F)),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2F241F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHelperText extends StatelessWidget {
  const AuthHelperText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF2F241F).withOpacity(0.78),
        fontSize: 13.5,
        height: 1.45,
      ),
    );
  }
}

class _LandscapeBackground extends StatelessWidget {
  const _LandscapeBackground();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final asset = width >= 900 ? _authDesktopBackgroundAsset : _authBackgroundAsset;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackLandscape(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0x0D0E1012),
                const Color(0x402F241F),
                const Color(0x7F4E3D34),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackLandscape extends StatelessWidget {
  const _FallbackLandscape();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEFCDBA),
            Color(0xFFB3B4A1),
            Color(0xFF78826C),
            Color(0xFF413530),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _LandscapePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mistPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, mistPaint);

    final hill = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.56, size.width * 0.46, size.height * 0.66)
      ..quadraticBezierTo(size.width * 0.72, size.height * 0.76, size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF6D7862).withOpacity(0.68));

    final foreground = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.70, size.width * 0.55, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.84, size.height * 0.92, size.width, size.height * 0.80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foreground, Paint()..color = const Color(0xFF35402F));

    final birchPaint = Paint()
      ..color = const Color(0xFFF0E7DE).withOpacity(0.78)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (final x in [size.width * 0.12, size.width * 0.17, size.width * 0.83]) {
      canvas.drawLine(Offset(x, size.height * 0.48), Offset(x - 6, size.height * 0.86), birchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
