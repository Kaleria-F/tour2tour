import 'package:flutter/widgets.dart';

class CorsSafeNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget? fallback;
  final double? width;
  final double? height;

  const CorsSafeNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return fallback ?? const SizedBox.shrink();
    }

    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}
