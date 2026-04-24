import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfMemoryPreview extends StatelessWidget {
  final Uint8List bytes;

  const PdfMemoryPreview({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.memory(bytes);
  }
}

