import 'package:flutter/services.dart';

class RussianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    var normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    final local = normalized.substring(1);
    final buffer = StringBuffer('+7');
    if (local.isNotEmpty) {
      buffer.write(' (');
      buffer.write(local.substring(0, local.length.clamp(0, 3)));
    }
    if (local.length >= 3) {
      buffer.write(') ');
      buffer.write(local.substring(3, local.length.clamp(3, 6)));
    }
    if (local.length >= 6) {
      buffer.write('-');
      buffer.write(local.substring(6, local.length.clamp(6, 8)));
    }
    if (local.length >= 8) {
      buffer.write('-');
      buffer.write(local.substring(8, local.length.clamp(8, 10)));
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}


String normalizePhoneForApi(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length == 10) {
    digits = '7$digits';
  }
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+$digits';
  }
  return value.trim();
}
