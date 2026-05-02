import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object>? buildAvatarImage(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  if (raw.startsWith('data:image/')) {
    final commaIndex = raw.indexOf(',');
    if (commaIndex <= 0 || commaIndex == raw.length - 1) {
      return null;
    }
    try {
      final bytes = base64Decode(raw.substring(commaIndex + 1));
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(raw);
}
