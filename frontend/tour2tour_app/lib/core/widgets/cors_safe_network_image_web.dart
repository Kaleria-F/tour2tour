import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _corsSafeImageCounter = 0;

class CorsSafeNetworkImage extends StatefulWidget {
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
  State<CorsSafeNetworkImage> createState() => _CorsSafeNetworkImageState();
}

class _CorsSafeNetworkImageState extends State<CorsSafeNetworkImage> {
  late final String _viewType;
  late final html.ImageElement _image;
  StreamSubscription<html.Event>? _errorSub;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 't2t-cors-safe-image-${_corsSafeImageCounter++}';
    _image = html.ImageElement()
      ..src = widget.url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _toObjectFit(widget.fit)
      ..style.border = '0'
      ..draggable = false;

    _errorSub = _image.onError.listen((_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _image;
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    if (_failed) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    Widget child = HtmlElementView(viewType: _viewType);
    if (widget.width != null || widget.height != null) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      );
    }
    return child;
  }

  String _toObjectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.cover:
      default:
        return 'cover';
    }
  }
}
