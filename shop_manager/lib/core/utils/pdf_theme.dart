import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfTheme {
  static const naira = '\u20A6';

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> load() async {
    final cached = _cachedTheme;
    if (cached != null) return cached;

    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );

    _cachedTheme = theme;
    return theme;
  }
}

