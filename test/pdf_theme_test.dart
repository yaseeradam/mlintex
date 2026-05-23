import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:shop_manager/core/utils/pdf_theme.dart';

void main() {
  test('PdfTheme loads and renders naira', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final theme = await PdfTheme.load();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        build: (_) => pw.Text('${PdfTheme.naira}1,000'),
      ),
    );

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });
}

