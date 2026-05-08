import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,##0.##', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty
    if (newValue.text.isEmpty) return newValue;

    // Strip everything except digits and one decimal point
    final stripped = newValue.text.replaceAll(',', '');

    // Allow trailing dot (user still typing decimal)
    if (stripped == '.' || stripped.endsWith('.')) {
      return newValue.copyWith(
        text: stripped,
        selection: TextSelection.collapsed(offset: stripped.length),
      );
    }

    final number = double.tryParse(stripped);
    if (number == null) return oldValue;

    final formatted = _fmt.format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parse a formatted string back to a plain double string for saving
  static double parse(String formatted) {
    return double.tryParse(formatted.replaceAll(',', '')) ?? 0;
  }
}
