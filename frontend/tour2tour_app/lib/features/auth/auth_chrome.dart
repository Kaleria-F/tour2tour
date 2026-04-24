import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _authBackgroundAsset = 'assets/images/russian_landscape_bg.jpg';
const _authDesktopBackgroundAsset = 'assets/images/lanscape_bg_pk.jpg';
const _authText = Color(0xFFF3F6EE);
const _authMuted = Color(0xFFAEB7A4);
const _authSurface = Color(0xFF2C332B);
const _authSurfaceSoft = Color(0xFF3A4438);
const _authStroke = Color(0x335A6555);
const _authAccent = Color(0xFFD7E37A);
const _authAccentDeep = Color(0xFF222715);
const _authAccentSoft = Color(0xFF6D7B33);

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
            color: const Color(0xFF1D1F1B).withOpacity(isDesktop ? 0.74 : 0.68),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF364032).withOpacity(isDesktop ? 0.92 : 0.86),
                const Color(0xFF262C25).withOpacity(isDesktop ? 0.88 : 0.82),
                const Color(0xFF1A1D19).withOpacity(isDesktop ? 0.92 : 0.86),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 34,
                offset: const Offset(0, 20),
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
            fontWeight: FontWeight.w500,
            color: _authAccent,
            letterSpacing: -0.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12.5,
              color: _authMuted.withOpacity(0.9),
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
    this.maxLines,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final double fontSize;
  final FontWeight fontWeight;
  final double titleHeight;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final titleStyle = TextStyle(
      fontSize: fontSize,
      height: titleHeight,
      fontWeight: fontWeight,
      color: _authText,
      letterSpacing: -1.2,
    );

    Widget buildScaledTitle(double maxWidth) {
      return SizedBox(
        width: maxWidth,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: titleStyle,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleSection = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildScaledTitle(constraints.maxWidth),
                  if (trailing != null) ...[
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: trailing!),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      title,
                      maxLines: maxLines,
                      overflow: maxLines == null ? null : TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing!,
                  ],
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleSection,
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.38,
                  fontWeight: FontWeight.w400,
                  color: _authMuted.withOpacity(0.92),
                ),
              ),
            ],
          ],
        );
      },
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
        color: _authSurface.withOpacity(0.86),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
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
              color: _authAccent.withOpacity(0.94),
            ),
            child: Icon(icon, size: 20, color: _authAccentDeep),
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
        : Icon(icon, size: iconSize, color: _authAccent);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _authText,
        side: BorderSide(color: Colors.white.withOpacity(0.10), width: 1),
        backgroundColor: _authSurface.withOpacity(0.82),
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
                      color: _authAccent,
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: _authAccentDeep,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: _authAccentDeep,
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
                          color: _authAccentSoft,
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
                            fontWeight: FontWeight.w600,
                            color: _authText,
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
                          color: _authAccent,
                        ),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _authAccentDeep,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                size: 24,
                                color: _authAccentDeep,
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
                color: _authText,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ).copyWith(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: _authMuted,
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
            color: _authMuted.withOpacity(0.95),
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
                color: _authAccent,
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
        color: _authSurfaceSoft.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _authAccent),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _authText,
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
        color: _authMuted.withOpacity(0.92),
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
                Colors.black.withOpacity(0.06),
                const Color(0x661B2119),
                const Color(0xCC111411),
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
            Color(0xFF6F826A),
            Color(0xFF3A4438),
            Color(0xFF1D231C),
            Color(0xFF111411),
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
    canvas.drawPath(hill, Paint()..color = const Color(0xFF5E6A56).withOpacity(0.72));

    final foreground = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.70, size.width * 0.55, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.84, size.height * 0.92, size.width, size.height * 0.80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foreground, Paint()..color = const Color(0xFF24301F));

    final birchPaint = Paint()
      ..color = const Color(0xFFDDE6D6).withOpacity(0.52)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (final x in [size.width * 0.12, size.width * 0.17, size.width * 0.83]) {
      canvas.drawLine(Offset(x, size.height * 0.48), Offset(x - 6, size.height * 0.86), birchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
