import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PriceHelper {
  static String getLabel(String? range) {
    switch (range) {
      case r'$':
        return '< Rp25rb';
      case r'$$':
        return 'Rp25–75rb';
      case r'$$$':
        return 'Rp75–150rb';
      case r'$$$$':
        return '> Rp150rb';
      default:
        return range ?? '';
    }
  }

  // Alias for backward compatibility if any
  static String getFullLabel(String? range) => getLabel(range);
  static String getShortLabel(String? range) => getLabel(range);

  static const List<String> availableRanges = [r'$', r'$$', r'$$$', r'$$$$'];
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Only allow digits
    String numericOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final number = int.parse(numericOnly);
    final formatted = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LocationHelper {
  static String formatLocation(String? area, String? city) {
    final a = (area ?? '').trim();
    final c = (city ?? '').trim();
    
    final parts = <String>[];
    if (a.isNotEmpty && a.toLowerCase() != 'unknown area') parts.add(a);
    if (c.isNotEmpty && c.toLowerCase() != 'unknown city') parts.add(c);
    
    if (parts.isEmpty) return 'Lokasi tidak diketahui';
    return parts.join(', ');
  }
}
