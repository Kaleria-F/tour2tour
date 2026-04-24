import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _pdfViewCounter = 0;

class PdfMemoryPreview extends StatefulWidget {
  final Uint8List bytes;

  const PdfMemoryPreview({super.key, required this.bytes});

  @override
  State<PdfMemoryPreview> createState() => _PdfMemoryPreviewState();
}

class _PdfMemoryPreviewState extends State<PdfMemoryPreview> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  late final String _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 't2t-pdf-preview-${_pdfViewCounter++}';

    final blob = html.Blob(<dynamic>[widget.bytes], 'application/pdf');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);

    _iframe = html.IFrameElement()
      ..src = _blobUrl
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_blobUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

