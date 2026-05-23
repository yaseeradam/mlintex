import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';
import '../../core/utils/file_saver.dart';
import '../../core/providers/auth_provider.dart';

// ── Model ──────────────────────────────────────────────────────────────────

@HiveType(typeId: 6)
class ReceiveEntry extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime date;
  @HiveField(2) final String productName;
  @HiveField(3) final String companyName;
  @HiveField(4) final double price;
  @HiveField(5) final int quantity;
  @HiveField(6) final double totalAmount;

  ReceiveEntry({
    required this.id,
    required this.date,
    required this.productName,
    required this.companyName,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });
}

class ReceiveEntryAdapter extends TypeAdapter<ReceiveEntry> {
  @override final int typeId = 6;

  @override
  ReceiveEntry read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{for (int i = 0; i < n; i++) reader.readByte(): reader.read()};
    return ReceiveEntry(
      id: f[0] as String, date: f[1] as DateTime,
      productName: f[2] as String, companyName: f[3] as String,
      price: f[4] as double, quantity: f[5] as int, totalAmount: f[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ReceiveEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.date)
      ..writeByte(2)..write(obj.productName)
      ..writeByte(3)..write(obj.companyName)
      ..writeByte(4)..write(obj.price)
      ..writeByte(5)..write(obj.quantity)
      ..writeByte(6)..write(obj.totalAmount);
  }

  @override bool operator ==(Object other) => identical(this, other) || other is ReceiveEntryAdapter && typeId == other.typeId;
  @override int get hashCode => typeId.hashCode;
}

// ── Provider ───────────────────────────────────────────────────────────────

final receiveBoxProvider = Provider<Box<ReceiveEntry>>((ref) => Hive.box<ReceiveEntry>('receive_entries'));

final receiveEntriesProvider = StreamProvider<List<ReceiveEntry>>((ref) async* {
  final box = ref.watch(receiveBoxProvider);
  yield _sorted(box);
  await for (final _ in box.watch()) {
    yield _sorted(box);
  }
});

List<ReceiveEntry> _sorted(Box<ReceiveEntry> box) =>
    box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

class ReceiveNotifier extends Notifier<void> {
  @override void build() {}
  Box<ReceiveEntry> get _box => ref.read(receiveBoxProvider);

  Future<void> add({required String product, required String company, required double price, required int qty}) async {
    final e = ReceiveEntry(id: const Uuid().v4(), date: DateTime.now(),
        productName: product, companyName: company, price: price,
        quantity: qty, totalAmount: price * qty);
    await _box.put(e.id, e);
  }

  Future<void> update(ReceiveEntry e) async => _box.put(e.id, e);
  Future<void> delete(String id) async => _box.delete(id);
}

final receiveNotifierProvider = NotifierProvider<ReceiveNotifier, void>(ReceiveNotifier.new);

// ── Screen ─────────────────────────────────────────────────────────────────

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    final entriesAsync = ref.watch(receiveEntriesProvider);
    final authState = ref.watch(authProvider);

    return Container(
      color: bg,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            title: const Text(
              'Receive Stock',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
                tooltip: 'Export PDF',
                onPressed: () => entriesAsync.whenData((e) => _exportPdf(e, _fmt, _dateFmt)),
              ),
              IconButton(
                icon: const Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                tooltip: 'Export Image',
                onPressed: () => _exportImage(),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.successColor),
                tooltip: 'Record Received Stock',
                onPressed: () => _showAddSheet(context),
              ),
            ],
          ),
          body: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              double totalSpent = 0;
              int totalQty = 0;
              final Set<String> suppliers = {};
              for (final entry in entries) {
                totalSpent += entry.totalAmount;
                totalQty += entry.quantity;
                suppliers.add(entry.companyName.toLowerCase().trim());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(
                      shopName: authState.shopName,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    const SizedBox(height: 16),
                    _FinancialSummaryCard(
                      totalSpent: totalSpent,
                      totalQty: totalQty,
                      suppliersCount: suppliers.length,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionButtons(
                      onRecordReceived: () => _showAddSheet(context),
                    ),
                    const SizedBox(height: 16),
                    _ReceiveFeed(
                      entries: entries,
                      fmt: _fmt,
                      dateFmt: _dateFmt,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      onEdit: (e) => _showAddSheet(context, existing: e),
                      onDelete: (e) => _confirmDelete(context, e),
                      onExport: (e) => _showRowExportSheet(context, e, authState),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, {ReceiveEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveEntrySheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReceiveEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Stock Entry'),
        content: const Text('Delete this received stock entry? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(receiveNotifierProvider.notifier).delete(entry.id);
    }
  }

  void _showRowExportSheet(BuildContext context, ReceiveEntry entry, AuthState auth) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Export Stock Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(
              entry.productName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor, size: 22),
              ),
              title: const Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: const Text('Share a PDF document for this received stock', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowPdf(entry, auth, _fmt, _dateFmt);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              title: const Text('Export as Image', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: const Text('Share a PNG image of this stock entry', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowImage(entry, auth, _fmt, _dateFmt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRowPdf(
    ReceiveEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final pdf = pw.Document(theme: await PdfTheme.load());

    pw.Widget hCell(String t, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Stock Inward Receipt', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(110), // Date
              1: const pw.FlexColumnWidth(3),   // Product
              2: const pw.FlexColumnWidth(2),   // Supplier
              3: const pw.FlexColumnWidth(1.5), // Unit Price
              4: const pw.FlexColumnWidth(1.2), // Quantity
              5: const pw.FlexColumnWidth(1.8), // Total Amount
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Product Name'),
                  hCell('Supplier / Company'),
                  hCell('Price (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Qty', alignment: pw.Alignment.center),
                  hCell('Total Value', alignment: pw.Alignment.centerRight),
                ],
              ),
              pw.TableRow(
                children: [
                  dCell(dateFmt.format(entry.date)),
                  dCell(entry.productName, bold: true),
                  dCell(entry.companyName),
                  dCell('${PdfTheme.naira}${fmt.format(entry.price)}', alignment: pw.Alignment.centerRight),
                  dCell('${entry.quantity}', alignment: pw.Alignment.center),
                  dCell('${PdfTheme.naira}${fmt.format(entry.totalAmount)}', bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
            ],
          ),
        ],
      ),
    ));

    final rowPdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'stock_in_${entry.id.substring(0, 6)}.pdf', rowPdfBytes);
  }

  Future<void> _exportRowImage(
    ReceiveEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    const bg = Color(0xFFF8FAFC);
    const textColor = Color(0xFF0F172A);
    const mutedColor = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);
    const accentColor = Color(0xFF10B981);

    final receiptKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: receiptKey,
          child: Material(
            color: bg,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(18),
              color: bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor)),
                        const SizedBox(height: 4),
                        const Text('STOCK INWARD RECEIPT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.inventory_2_rounded, size: 14, color: mutedColor),
                          const SizedBox(width: 6),
                          const Text('Received Stock Entry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: accentColor, width: 5),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_circle_down_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Supplier: ${entry.companyName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₦${fmt.format(entry.price)} × ${entry.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFmt.format(entry.date),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '₦${fmt.format(entry.totalAmount)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final boundary = receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stock_in_${entry.id.substring(0, 6)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await FileSaver.saveImage(context, file);
    } finally {
      overlay.remove();
    }
  }

  Future<void> _exportPdf(List<ReceiveEntry> entries, NumberFormat fmt, DateFormat dateFmt) async {
    final pdf = pw.Document(theme: await PdfTheme.load());
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        pw.Text('Received Stock', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['S/N', 'Date', 'Product', 'Company', 'Price', 'Qty', 'Total']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...entries.asMap().entries.map((e) => pw.TableRow(children: [
              _cell('${e.key + 1}'), _cell(dateFmt.format(e.value.date)),
              _cell(e.value.productName), _cell(e.value.companyName),
              _cell('${PdfTheme.naira}${fmt.format(e.value.price)}'), _cell('${e.value.quantity}'),
              _cell('${PdfTheme.naira}${fmt.format(e.value.totalAmount)}'),
            ])),
          ],
        ),
      ],
    ));
    final pdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'received_stock.pdf', pdfBytes);
  }

  pw.Widget _cell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));

  Future<void> _exportImage() async {
    final overlayState = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final entries = await ref.read(receiveEntriesProvider.future);
    if (!mounted) return;

    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final captureKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: captureKey,
          child: Material(
            color: bg,
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Received Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.successColor)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        border: TableBorder(
                          horizontalInside: BorderSide(color: borderColor, width: 0.5),
                          verticalInside: BorderSide(color: borderColor, width: 0.5),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: headerBg),
                            children: ['S/N', 'Date', 'Product', 'Company', 'Price', 'Qty', 'Total']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
                                    ))
                                .toList(),
                          ),
                          ...entries.asMap().entries.map((e) {
                            final i = e.key;
                            final entry = e.value;
                            final rowBg = i.isEven ? bg : (isDark ? const Color(0xFF1A2535) : const Color(0xFFF8FAFC));
                            return TableRow(
                              decoration: BoxDecoration(color: rowBg),
                              children: [
                                _tCell('${i + 1}', mutedColor),
                                _tCell(dateFmt.format(entry.date), mutedColor, size: 9),
                                _tCell(entry.productName, textColor, bold: true),
                                _tCell(entry.companyName, AppTheme.primaryColor),
                                _tCell('\u20a6${fmt.format(entry.price)}', textColor),
                                _tCell('${entry.quantity}', textColor),
                                _tCell('\u20a6${fmt.format(entry.totalAmount)}', AppTheme.successColor, bold: true),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlay);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/received_stock.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await FileSaver.saveImage(context, file);
    } catch (e) {
      debugPrint('Image export error: $e');
    } finally {
      overlay.remove();
    }
  }

  Widget _tCell(String text, Color color, {bool bold = false, double size = 10}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Text(text, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
  );
}

class _HeaderCard extends StatelessWidget {
  final String shopName;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;

  const _HeaderCard({
    required this.shopName,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final displayShop = (shopName.isEmpty || shopName.toLowerCase() == 'admin')
        ? 'M Lin Tex'
        : shopName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            displayShop,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Supplier Stock Deliveries',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Global bookkeeping of received goods & stock',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final double totalSpent;
  final int totalQty;
  final int suppliersCount;
  final NumberFormat fmt;

  const _FinancialSummaryCard({
    required this.totalSpent,
    required this.totalQty,
    required this.suppliersCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(String title, String value, Color color, Color bgColor, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: color.withOpacity(0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          buildItem('TOTAL SPENT', '₦${fmt.format(totalSpent)}', const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.payment_rounded),
          const SizedBox(width: 8),
          buildItem('TOTAL QTY', '$totalQty', const Color(0xFF4F46E5), const Color(0xFFEEF2FF), Icons.inventory_rounded),
          const SizedBox(width: 8),
          buildItem('SUPPLIERS', '$suppliersCount', const Color(0xFFF59E0B), const Color(0xFFFEF3C7), Icons.business_rounded),
        ],
      ),
    );
  }
}

class _QuickActionButtons extends StatelessWidget {
  final VoidCallback onRecordReceived;

  const _QuickActionButtons({
    required this.onRecordReceived,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onRecordReceived,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Record Received Stock (IN)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiveFeed extends StatelessWidget {
  final List<ReceiveEntry> entries;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final void Function(ReceiveEntry) onEdit;
  final void Function(ReceiveEntry) onDelete;
  final void Function(ReceiveEntry) onExport;

  const _ReceiveFeed({
    required this.entries,
    required this.fmt,
    required this.dateFmt,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  Widget _buildHeaderCell(
    String text, {
    required double width,
    Alignment alignment = Alignment.centerLeft,
    bool showRightDivider = true,
  }) {
    return Container(
      width: width,
      height: 38,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: showRightDivider
            ? const Border(right: BorderSide(color: Colors.white24, width: 0.8))
            : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : (alignment == Alignment.center ? TextAlign.center : TextAlign.left),
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required double width,
    bool bold = false,
    Color? textColor,
    Alignment alignment = Alignment.centerLeft,
    bool showRightDivider = true,
    double fontSize = 11,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        border: showRightDivider
            ? const Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 0.8))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: textColor ?? const Color(0xFF0F172A),
        ),
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : (alignment == Alignment.center ? TextAlign.center : TextAlign.left),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showRowActionMenu(BuildContext context, ReceiveEntry entry) {
    const accentColor = Color(0xFF10B981);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(entry.date);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_circle_down_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Supplier: ${entry.companyName} • $dateStr',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${fmt.format(entry.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'STOCK IN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
              ),
              title: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Modify stock product details, price or quantity', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                onEdit(entry);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.ios_share_rounded, color: Color(0xFF10B981), size: 20),
              ),
              title: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Generate a beautiful PDF or Image document', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                onExport(entry);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              title: const Text('Delete Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444))),
              subtitle: const Text('Permanently remove this stock record', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalQty = 0;
    double totalSpentSum = 0;
    for (final entry in entries) {
      totalQty += entry.quantity;
      totalSpentSum += entry.totalAmount;
    }

    const double dateWidth = 70;
    const double productWidth = 120;
    const double companyWidth = 100;
    const double priceWidth = 80;
    const double qtyWidth = 45;
    const double totalWidth = 90;
    const double totalTableWidth = dateWidth + productWidth + companyWidth + priceWidth + qtyWidth + totalWidth; // 505

    const accentColor = Color(0xFF10B981);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STOCK RECEIVED LEDGER TABLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${entries.length} ${entries.length == 1 ? 'Item' : 'Items'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: totalTableWidth + 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(
                          left: BorderSide(color: Color(0xFF0F172A), width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('Date', width: dateWidth),
                          _buildHeaderCell('Product', width: productWidth),
                          _buildHeaderCell('Supplier', width: companyWidth),
                          _buildHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                          _buildHeaderCell('Total Value (₦)', width: totalWidth, alignment: Alignment.centerRight, showRightDivider: false),
                        ],
                      ),
                    ),
                    if (entries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_off_rounded, size: 40, color: textMuted.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'No received stock yet',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(entries.length, (index) {
                          final entry = entries[index];
                          final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                          
                          final dateStr = DateFormat('dd/MM/yy').format(entry.date);
                          final priceStr = fmt.format(entry.price);
                          final qtyStr = entry.quantity.toString();
                          final totalStr = '₦${fmt.format(entry.totalAmount)}';

                          return Material(
                            color: rowBgColor,
                            child: InkWell(
                              onTap: () => _showRowActionMenu(context, entry),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: accentColor, width: 4),
                                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildCell(dateStr, width: dateWidth),
                                    _buildCell(entry.productName, width: productWidth, bold: true),
                                    _buildCell(entry.companyName, width: companyWidth, textColor: AppTheme.primaryColor),
                                    _buildCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                    _buildCell(qtyStr, width: qtyWidth, alignment: Alignment.center),
                                    _buildCell(
                                      totalStr,
                                      width: totalWidth,
                                      bold: true,
                                      alignment: Alignment.centerRight,
                                      textColor: accentColor,
                                      showRightDivider: false,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          left: BorderSide(color: Color(0xFF475569), width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildCell('Totals', width: dateWidth, bold: true, textColor: const Color(0xFF475569)),
                          _buildCell('', width: productWidth),
                          _buildCell('', width: companyWidth),
                          _buildCell('—', width: priceWidth, alignment: Alignment.centerRight, textColor: const Color(0xFF94A3B8)),
                          _buildCell('$totalQty', width: qtyWidth, bold: true, alignment: Alignment.center, textColor: const Color(0xFF0F172A)),
                          _buildCell(
                            '₦${fmt.format(totalSpentSum)}',
                            width: totalWidth,
                            bold: true,
                            alignment: Alignment.centerRight,
                            textColor: accentColor,
                            showRightDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text(
                '💡 Tip: Tap any row to Edit, Delete or Share Receipt.',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiveEntrySheet extends ConsumerStatefulWidget {
  final ReceiveEntry? existing;
  const _ReceiveEntrySheet({this.existing});

  @override
  ConsumerState<_ReceiveEntrySheet> createState() => _ReceiveEntrySheetState();
}

class _ReceiveEntrySheetState extends ConsumerState<_ReceiveEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _productCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  final _numFmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _productCtrl.text = e.productName;
      _companyCtrl.text = e.companyName;
      _priceCtrl.text = _numFmt.format(e.price);
      _qtyCtrl.text = e.quantity.toString();
      _totalCtrl.text = _numFmt.format(e.totalAmount);
    }
  }

  @override
  void dispose() {
    _productCtrl.dispose(); _companyCtrl.dispose();
    _priceCtrl.dispose(); _qtyCtrl.dispose(); _totalCtrl.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final p = CurrencyInputFormatter.parse(_priceCtrl.text);
    final q = int.tryParse(_qtyCtrl.text) ?? 0;
    if (p > 0 && q > 0) _totalCtrl.text = NumberFormat('#,##0', 'en_US').format(p * q);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(receiveNotifierProvider.notifier);
    if (widget.existing != null) {
      final e = widget.existing!;
      await notifier.update(ReceiveEntry(
        id: e.id, date: e.date,
        productName: _productCtrl.text.trim(), companyName: _companyCtrl.text.trim(),
        price: CurrencyInputFormatter.parse(_priceCtrl.text),
        quantity: int.parse(_qtyCtrl.text.trim()),
        totalAmount: CurrencyInputFormatter.parse(_totalCtrl.text),
      ));
    } else {
      await notifier.add(
        product: _productCtrl.text.trim(), company: _companyCtrl.text.trim(),
        price: CurrencyInputFormatter.parse(_priceCtrl.text),
        qty: int.parse(_qtyCtrl.text.trim()),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      decoration: const BoxDecoration(color: bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Received Item' : 'Record Received Item',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            _label('Product Name', textMuted),
            TextFormField(controller: _productCtrl, decoration: const InputDecoration(hintText: 'e.g. LIN ROMAN 150y'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 14),
            _label('Company / Supplier', textMuted),
            TextFormField(controller: _companyCtrl, decoration: const InputDecoration(hintText: 'e.g. Diamond Textiles'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Price (₦)', textMuted),
                TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(hintText: '0.00'), onChanged: (_) => setState(_updateTotal),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Quantity', textMuted),
                TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'), onChanged: (_) => setState(_updateTotal),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              ])),
            ]),
            const SizedBox(height: 14),
            _label('Total Amount (₦)', textMuted),
            TextFormField(controller: _totalCtrl, readOnly: true,
                decoration: const InputDecoration(hintText: '0.00', prefixText: '₦ ',
                    filled: true, fillColor: Color(0xFFF1F5F9))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(widget.existing != null ? 'Update' : 'Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
  );
}
