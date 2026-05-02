import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ProcessedAvatar {
  final Uint8List bytes;
  final String mimeType;

  const ProcessedAvatar({
    required this.bytes,
    required this.mimeType,
  });
}

Future<ProcessedAvatar?> compressAvatarBytes(
  Uint8List sourceBytes, {
  int maxDimension = 1200,
  int targetMaxBytes = 420 * 1024,
}) async {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    if (sourceBytes.length > 2 * 1024 * 1024) {
      return null;
    }
    return ProcessedAvatar(bytes: sourceBytes, mimeType: 'image/jpeg');
  }

  final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
  img.Image working = decoded;
  if (longestSide > maxDimension) {
    final scale = maxDimension / longestSide;
    working = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  Uint8List encoded = Uint8List.fromList(img.encodeJpg(working, quality: 88));
  for (final quality in const [82, 76, 70, 64, 58]) {
    if (encoded.length <= targetMaxBytes) {
      break;
    }
    encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
  }

  if (encoded.length > 2 * 1024 * 1024) {
    return null;
  }

  return ProcessedAvatar(
    bytes: encoded,
    mimeType: 'image/jpeg',
  );
}
