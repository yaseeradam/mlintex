import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfTheme {
  // Use ASCII-safe representation — the Naira glyph is missing from most
  // embedded fonts and causes a silent crash during PDF generation.
  static const naira = 'N';

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> load() async {
    if (_cachedTheme != null) return _cachedTheme!;
    try {
      final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _cachedTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (_) {
      // Fall back to built-in Helvetica if fonts fail to load
      _cachedTheme = pw.ThemeData.base();
    }
    return _cachedTheme!;
  }
}
