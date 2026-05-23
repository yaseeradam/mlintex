import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';
import '../../core/utils/file_saver.dart';
import '../../core/providers/auth_provider.dart';

// ── Model ──────────────────────────────────────────────────────────────────

@HiveType(typeId: 7)
class SalesLedgerEntry extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime date;
  @HiveField(2) final String? inItem;
  @HiveField(3) final String? outItem;
  @HiveField(4) final double? price;
  @HiveField(5) final int? quantity;
  @HiveField(6) final double totalAmount;
  @HiveField(7) double runningBalance;
  @HiveField(8) final int typeIndex; // 0=payment, 1=sale

  SalesLedgerEntry({
    required this.id, required this.date,
    this.inItem, this.outItem, this.price, this.quantity,
    required this.totalAmount, this.runningBalance = 0, required this.typeIndex,
  });
}

class SalesLedgerEntryAdapter extends TypeAdapter<SalesLedgerEntry> {
  @override final int typeId = 7;

  @override
  SalesLedgerEntry read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{for (int i = 0; i < n; i++) reader.readByte(): reader.read()};
    return SalesLedgerEntry(
      id: f[0] as String, date: f[1] as DateTime,
      inItem: f[2] as String?, outItem: f[3] as String?,
      price: f[4] as double?, quantity: f[5] as int?,
      totalAmount: f[6] as double, runningBalance: f[7] as double, typeIndex: f[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SalesLedgerEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.date)
      ..writeByte(2)..write(obj.inItem)
      ..writeByte(3)..write(obj.outItem)
      ..writeByte(4)..write(obj.price)
      ..writeByte(5)..write(obj.quantity)
      ..writeByte(6)..write(obj.totalAmount)
      ..writeByte(7)..write(obj.runningBalance)
      ..writeByte(8)..write(obj.typeIndex);
  }

  @override bool operator ==(Object other) => identical(this, other) || other is SalesLedgerEntryAdapter && typeId == other.typeId;
  @override int get hashCode => typeId.hashCode;
}

// ── Provider ───────────────────────────────────────────────────────────────

final salesLedgerBoxProvider = Provider<Box<SalesLedgerEntry>>(
  (ref) => Hive.box<SalesLedgerEntry>('sales_ledger'),
);

final salesLedgerEntriesProvider = StreamProvider<List<SalesLedgerEntry>>((ref) async* {
  final box = ref.watch(salesLedgerBoxProvider);
  yield _compute(box);
  await for (final _ in box.watch()) {
    yield _compute(box);
  }
});

List<SalesLedgerEntry> _compute(Box<SalesLedgerEntry> box) {
  final list = box.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (final e in list) {
    e.typeIndex == 1 ? balance += e.totalAmount : balance -= e.totalAmount;
    e.runningBalance = balance;
  }
  return list;
}

class SalesLedgerNotifier extends Notifier<void> {
  @override void build() {}
  Box<SalesLedgerEntry> get _box => ref.read(salesLedgerBoxProvider);

  Future<void> addSale({required String item, required double price, required int qty}) async {
    final e = SalesLedgerEntry(id: const Uuid().v4(), date: DateTime.now(),
        inItem: item, price: price, quantity: qty, totalAmount: price * qty, typeIndex: 1);
    await _box.put(e.id, e);
  }

  Future<void> addPayment({required String bankOrCash, required double amount}) async {
    final e = SalesLedgerEntry(id: const Uuid().v4(), date: DateTime.now(),
        outItem: bankOrCash, totalAmount: amount, typeIndex: 0);
    await _box.put(e.id, e);
  }

  Future<void> update(SalesLedgerEntry e) async => _box.put(e.id, e);
  Future<void> delete(String id) async => _box.delete(id);
}

final salesLedgerNotifierProvider =
    NotifierProvider<SalesLedgerNotifier, void>(SalesLedgerNotifier.new);

// ── Screen ─────────────────────────────────────────────────────────────────

class SalesLedgerScreen extends ConsumerStatefulWidget {
  const SalesLedgerScreen({super.key});

  @override
  ConsumerState<SalesLedgerScreen> createState() => _SalesLedgerScreenState();
}

class _SalesLedgerScreenState extends ConsumerState<SalesLedgerScreen> {
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    final entriesAsync = ref.watch(salesLedgerEntriesProvider);
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
              'Sales Ledger',
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
                onPressed: () => entriesAsync.whenData((_) => _exportImage()),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                tooltip: 'Add Entry',
                onPressed: () => _showAddSelectionSheet(context),
              ),
            ],
          ),
          body: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              double totalIn = 0;
              double totalOut = 0;
              for (final entry in entries) {
                if (entry.typeIndex == 1) {
                  totalIn += entry.totalAmount;
                } else {
                  totalOut += entry.totalAmount;
                }
              }
              final double remainingDebt = entries.isEmpty ? 0 : entries.last.runningBalance;

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
                      totalIn: totalIn,
                      totalOut: totalOut,
                      remainingDebt: remainingDebt,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionButtons(
                      onAddSale: () => _showAddEntrySheet(context, isSale: true),
                      onAddPayment: () => _showAddEntrySheet(context, isSale: false),
                    ),
                    const SizedBox(height: 16),
                    _SalesLedgerFeed(
                      entries: entries,
                      fmt: _fmt,
                      dateFmt: _dateFmt,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      onEdit: (e) => _showAddEntrySheet(context, existing: e),
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

  void _showAddSelectionSheet(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Transaction Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose whether to record goods sold or payment received',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 22),
              ),
              title: const Text('Add Sale (IN)', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
              subtitle: const Text('Record goods sold to customers on credit', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEntrySheet(context, isSale: true);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
              ),
              title: const Text('Add Payment (OUT)', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
              subtitle: const Text('Record cash or bank payment received from customer', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEntrySheet(context, isSale: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEntrySheet(BuildContext context, {bool isSale = true, SalesLedgerEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SalesEntrySheet(
        existing: existing,
        initialIsSale: existing != null ? existing.typeIndex == 1 : isSale,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SalesLedgerEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this sales ledger entry? This cannot be undone.'),
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
      await ref.read(salesLedgerNotifierProvider.notifier).delete(entry.id);
    }
  }

  void _showRowExportSheet(BuildContext context, SalesLedgerEntry entry, AuthState auth) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    final isSale = entry.typeIndex == 1;

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
            const Text('Export Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(
              isSale ? (entry.inItem ?? 'Sale') : (entry.outItem ?? 'Payment'),
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
              subtitle: const Text('Share a PDF receipt for this entry', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              subtitle: const Text('Share a PNG image of this entry', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
    SalesLedgerEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final isSale = entry.typeIndex == 1;
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

    final desc = isSale 
        ? '${entry.inItem ?? 'Sale'} (${PdfTheme.naira}${fmt.format(entry.price)} x ${entry.quantity} Bll)'
        : (entry.outItem ?? 'PAYMENT');
    
    final goodsTotal = isSale ? '${PdfTheme.naira}${fmt.format(entry.totalAmount)}' : '';
    final paymentReceived = !isSale ? '${PdfTheme.naira}${fmt.format(entry.totalAmount)}' : '';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Sales Ledger Entry', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(110), // Date
              1: const pw.FlexColumnWidth(3),   // Description
              2: const pw.FlexColumnWidth(1.5), // Goods Total
              3: const pw.FlexColumnWidth(1.5), // Payment Received
              4: const pw.FlexColumnWidth(1.8), // Running Balance
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Description'),
                  hCell('Goods Total (IN)', alignment: pw.Alignment.centerRight),
                  hCell('Payment Out (OUT)', alignment: pw.Alignment.centerRight),
                  hCell('Running Balance', alignment: pw.Alignment.centerRight),
                ],
              ),
              pw.TableRow(
                children: [
                  dCell(dateFmt.format(entry.date)),
                  dCell(desc, bold: true),
                  dCell(goodsTotal, bold: isSale, alignment: pw.Alignment.centerRight),
                  dCell(paymentReceived, bold: !isSale, alignment: pw.Alignment.centerRight),
                  dCell('${PdfTheme.naira}${fmt.format(entry.runningBalance)}', bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
            ],
          ),
        ],
      ),
    ));

    final rowPdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'sales_entry_${entry.id.substring(0, 6)}.pdf', rowPdfBytes);
  }

  Future<void> _exportRowImage(
    SalesLedgerEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final isSale = entry.typeIndex == 1;
    const bg = Color(0xFFF8FAFC);
    const textColor = Color(0xFF0F172A);
    const mutedColor = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    final balancePosColor = const Color(0xFFDC2626);
    final balanceNegColor = const Color(0xFF16A34A);
    final totalColor = isSale ? const Color(0xFF1E3A8A) : const Color(0xFF15803D);
    final accentColor = isSale ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final bal = entry.runningBalance;

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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        const Text('TRANSACTION RECEIPT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.receipt_rounded, size: 14, color: mutedColor),
                          const SizedBox(width: 6),
                          const Text('Sales Ledger Entry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
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
                        decoration: BoxDecoration(
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
                              child: Icon(
                                isSale ? Icons.shopping_bag_rounded : Icons.check_circle_rounded,
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
                                    isSale
                                        ? (entry.inItem ?? '')
                                        : (entry.outItem ?? 'PAYMENT'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (isSale) ...[
                                    Text(
                                      '₦${fmt.format(entry.price)} × ${entry.quantity} Bll',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ] else ...[
                                    const Text(
                                      'Payment Received',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
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
                                  isSale
                                      ? '₦${fmt.format(entry.totalAmount)}'
                                      : '-₦${fmt.format(entry.totalAmount)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: totalColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (bal > 0 ? balancePosColor : balanceNegColor).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Bal: ₦${fmt.format(bal)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: bal > 0 ? balancePosColor : balanceNegColor,
                                    ),
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
      final file = File('${dir.path}/sales_entry_${entry.id.substring(0, 6)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await FileSaver.saveImage(context, file);
    } finally {
      overlay.remove();
    }
  }

  Future<void> _exportPdf(List<SalesLedgerEntry> entries, NumberFormat fmt, DateFormat dateFmt) async {
    final pdf = pw.Document(theme: await PdfTheme.load());
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        pw.Text('Sales Ledger', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Qty', 'Total Amount', 'Total Balance']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...entries.asMap().entries.map((e) {
              final entry = e.value;
              final isSale = entry.typeIndex == 1;
              return pw.TableRow(children: [
                _c('${e.key + 1}'), _c(dateFmt.format(entry.date)),
                _c(isSale ? (entry.inItem ?? '') : ''),
                _c(!isSale ? (entry.outItem ?? '') : ''),
                _c(entry.price != null ? '${PdfTheme.naira}${fmt.format(entry.price)}' : ''),
                _c(entry.quantity != null ? '${entry.quantity}' : ''),
                _c('${PdfTheme.naira}${fmt.format(entry.totalAmount)}'),
                _c('${PdfTheme.naira}${fmt.format(entry.runningBalance)}'),
              ]);
            }),
          ],
        ),
      ],
    ));
    final pdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'sales_ledger.pdf', pdfBytes);
  }

  pw.Widget _c(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));

  Future<void> _exportImage() async {
    final overlayState = Overlay.of(context);

    final entries = await ref.read(salesLedgerEntriesProvider.future);
    if (!mounted) return;

    final auth = ref.read(authProvider);
    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    const bg = Colors.white;
    const textColor = Color(0xFF0F172A);
    const mutedColor = Color(0xFF64748B);
    const headerBg = Color(0xFFE2E8F0);
    const borderColor = Color(0xFFE2E8F0);

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
                  Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                  const SizedBox(height: 4),
                  const Text('Sales Ledger', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
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
                            children: ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Qty', 'Total Amount', 'Total Balance']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
                                    ))
                                .toList(),
                          ),
                          ...entries.asMap().entries.map((e) {
                            final i = e.key;
                            final entry = e.value;
                            final isSale = entry.typeIndex == 1;
                            final rowBg = i.isEven ? bg : const Color(0xFFF8FAFC);
                            return TableRow(
                              decoration: BoxDecoration(color: rowBg),
                              children: [
                                _tCell('${i + 1}', mutedColor),
                                _tCell(dateFmt.format(entry.date), mutedColor, size: 9),
                                _tCell(isSale ? (entry.inItem ?? '') : '', textColor, bold: true),
                                _tCell(!isSale ? (entry.outItem ?? '') : '', AppTheme.successColor, bold: true),
                                _tCell(entry.price != null ? '\u20a6${fmt.format(entry.price)}' : '', textColor),
                                _tCell(entry.quantity != null ? '${entry.quantity}' : '', textColor),
                                _tCell('\u20a6${fmt.format(entry.totalAmount)}', AppTheme.primaryColor, bold: true),
                                _tCell('\u20a6${fmt.format(entry.runningBalance)}',
                                    entry.runningBalance > 0 ? AppTheme.errorColor : AppTheme.successColor, bold: true),
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
      final file = File('${dir.path}/sales_ledger.png');
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
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
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
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sales & Payments Ledger',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Global bookkeeping of shop transactions',
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
  final double totalIn;
  final double totalOut;
  final double remainingDebt;
  final NumberFormat fmt;

  const _FinancialSummaryCard({
    required this.totalIn,
    required this.totalOut,
    required this.remainingDebt,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(String title, double amount, Color color, Color bgColor, IconData icon, {bool isOutstanding = false}) {
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
                  '₦${fmt.format(amount)}',
                  style: TextStyle(
                    fontSize: isOutstanding ? 14 : 12,
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
          buildItem('TOTAL SALES', totalIn, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), Icons.add_circle_outline_rounded),
          const SizedBox(width: 8),
          buildItem('TOTAL PAID', totalOut, const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.check_circle_outline_rounded),
          const SizedBox(width: 8),
          buildItem('BALANCE', remainingDebt, remainingDebt > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), remainingDebt > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5), Icons.warning_amber_rounded, isOutstanding: true),
        ],
      ),
    );
  }
}

class _QuickActionButtons extends StatelessWidget {
  final VoidCallback onAddSale;
  final VoidCallback onAddPayment;

  const _QuickActionButtons({
    required this.onAddSale,
    required this.onAddPayment,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildBtn(String label, IconData icon, Color color, Color bgColor, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildBtn('Record Sale (IN)', Icons.add_circle_outline_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), onAddSale),
        const SizedBox(width: 10),
        buildBtn('Record Payment (OUT)', Icons.check_circle_outline_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), onAddPayment),
      ],
    );
  }
}

class _SalesLedgerFeed extends StatelessWidget {
  final List<SalesLedgerEntry> entries;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final void Function(SalesLedgerEntry) onEdit;
  final void Function(SalesLedgerEntry) onDelete;
  final void Function(SalesLedgerEntry) onExport;

  const _SalesLedgerFeed({
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

  void _showRowActionMenu(BuildContext context, SalesLedgerEntry entry) {
    final isSale = entry.typeIndex == 1;
    final accentColor = isSale ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
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
                    child: Icon(
                      isSale ? Icons.shopping_bag_rounded : Icons.check_circle_rounded,
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
                          isSale ? (entry.inItem ?? 'Sale') : (entry.outItem ?? 'PAYMENT'),
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
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${fmt.format(entry.totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isSale ? const Color(0xFF1E3A8A) : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSale ? 'SALE (IN)' : 'PAYMENT (OUT)',
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
              subtitle: const Text('Modify item details, price or quantity', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              subtitle: const Text('Generate a beautiful PDF or Image receipt', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              subtitle: const Text('Permanently remove this transaction', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
    final balancePosColor = const Color(0xFFDC2626);
    final balanceNegColor = const Color(0xFF16A34A);

    int totalQty = 0;
    double totalInSum = 0;
    double totalOutSum = 0;
    for (final entry in entries) {
      if (entry.typeIndex == 1) {
        totalQty += entry.quantity ?? 0;
        totalInSum += entry.totalAmount;
      } else {
        totalOutSum += entry.totalAmount;
      }
    }

    const double dateWidth = 65;
    const double itemWidth = 115;
    const double priceWidth = 80;
    const double qtyWidth = 40;
    const double outWidth = 90;
    const double balWidth = 95;
    const double totalTableWidth = dateWidth + itemWidth + priceWidth + qtyWidth + outWidth + balWidth; // 485

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRANSACTION LEDGER TABLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${entries.length} ${entries.length == 1 ? 'Entry' : 'Entries'}',
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
                          _buildHeaderCell('Item/Desc', width: itemWidth),
                          _buildHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                          _buildHeaderCell('OUT (₦)', width: outWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('Balance (₦)', width: balWidth, alignment: Alignment.centerRight, showRightDivider: false),
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
                              'No ledger entries yet',
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
                          final isSale = entry.typeIndex == 1;
                          final accentColor = isSale ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
                          final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                          final balStr = '₦${fmt.format(entry.runningBalance)}';
                          final balColor = entry.runningBalance > 0 ? balancePosColor : balanceNegColor;
                          
                          final dateStr = DateFormat('dd/MM/yy').format(entry.date);
                          final descStr = isSale ? (entry.inItem ?? '') : (entry.outItem ?? 'PAYMENT');
                          final priceStr = isSale && entry.price != null ? fmt.format(entry.price) : '—';
                          final qtyStr = isSale && entry.quantity != null ? entry.quantity.toString() : '—';
                          final outStr = !isSale ? fmt.format(entry.totalAmount) : '—';

                          return Material(
                            color: rowBgColor,
                            child: InkWell(
                              onTap: () => _showRowActionMenu(context, entry),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: accentColor, width: 4),
                                    bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildCell(dateStr, width: dateWidth),
                                    _buildCell(descStr, width: itemWidth, bold: true),
                                    _buildCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                    _buildCell(qtyStr, width: qtyWidth, alignment: Alignment.center),
                                    _buildCell(outStr, width: outWidth, alignment: Alignment.centerRight),
                                    _buildCell(
                                      balStr,
                                      width: balWidth,
                                      bold: true,
                                      alignment: Alignment.centerRight,
                                      textColor: balColor,
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
                          _buildCell('IN: ₦${fmt.format(totalInSum)}', width: itemWidth, bold: true, textColor: const Color(0xFF1E3A8A), fontSize: 9.5),
                          _buildCell('—', width: priceWidth, alignment: Alignment.centerRight, textColor: const Color(0xFF94A3B8)),
                          _buildCell('$totalQty', width: qtyWidth, bold: true, alignment: Alignment.center, textColor: const Color(0xFF0F172A)),
                          _buildCell('₦${fmt.format(totalOutSum)}', width: outWidth, bold: true, alignment: Alignment.centerRight, textColor: const Color(0xFF15803D)),
                          _buildCell(
                            '₦${fmt.format(entries.isEmpty ? 0 : entries.last.runningBalance)}',
                            width: balWidth,
                            bold: true,
                            alignment: Alignment.centerRight,
                            textColor: (entries.isEmpty ? 0 : entries.last.runningBalance) > 0 ? balancePosColor : balanceNegColor,
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

class _SalesEntrySheet extends ConsumerStatefulWidget {
  final SalesLedgerEntry? existing;
  final bool initialIsSale;

  const _SalesEntrySheet({
    this.existing,
    this.initialIsSale = true,
  });

  @override
  ConsumerState<_SalesEntrySheet> createState() => _SalesEntrySheetState();
}

class _SalesEntrySheetState extends ConsumerState<_SalesEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isSale = true;

  final _numFmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _isSale = e.typeIndex == 1;
      _itemCtrl.text = e.inItem ?? e.outItem ?? '';
      _priceCtrl.text = e.price != null ? _numFmt.format(e.price) : '';
      _qtyCtrl.text = e.quantity?.toString() ?? '';
      _amountCtrl.text = _numFmt.format(e.totalAmount);
    } else {
      _isSale = widget.initialIsSale;
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose(); _priceCtrl.dispose();
    _qtyCtrl.dispose(); _amountCtrl.dispose();
    super.dispose();
  }

  void _updateTotal() {
    if (_isSale) {
      final p = CurrencyInputFormatter.parse(_priceCtrl.text);
      final q = int.tryParse(_qtyCtrl.text) ?? 0;
      if (p > 0 && q > 0) _amountCtrl.text = NumberFormat('#,##0', 'en_US').format(p * q);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final n = ref.read(salesLedgerNotifierProvider.notifier);
    if (widget.existing != null) {
      final e = widget.existing!;
      await n.update(SalesLedgerEntry(
        id: e.id, date: e.date,
        inItem: _isSale ? _itemCtrl.text.trim() : null,
        outItem: !_isSale ? _itemCtrl.text.trim() : null,
        price: _isSale ? CurrencyInputFormatter.parse(_priceCtrl.text) : null,
        quantity: _isSale ? int.tryParse(_qtyCtrl.text) : null,
        totalAmount: CurrencyInputFormatter.parse(_amountCtrl.text),
        typeIndex: _isSale ? 1 : 0,
      ));
    } else {
      if (_isSale) {
        await n.addSale(item: _itemCtrl.text.trim(),
            price: CurrencyInputFormatter.parse(_priceCtrl.text),
            qty: int.parse(_qtyCtrl.text.trim()));
      } else {
        await n.addPayment(bankOrCash: _itemCtrl.text.trim(),
            amount: CurrencyInputFormatter.parse(_amountCtrl.text));
      }
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
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Sales Entry' : 'New Sales Entry',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Expanded(child: _Btn(label: 'Sale (IN)', active: _isSale, color: AppTheme.primaryColor,
                    onTap: () => setState(() => _isSale = true))),
                Expanded(child: _Btn(label: 'Payment (OUT)', active: !_isSale, color: AppTheme.successColor,
                    onTap: () => setState(() => _isSale = false))),
              ]),
            ),
            const SizedBox(height: 16),
            _lbl(_isSale ? 'Item Name' : 'Bank / Cash', textMuted),
            TextFormField(
              controller: _itemCtrl,
              decoration: InputDecoration(hintText: _isSale ? 'e.g. ZENITH 150y' : 'e.g. ACCESS BANK'),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            if (_isSale) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Price (₦)', textMuted),
                  TextFormField(controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(hintText: '0.00'),
                      onChanged: (_) => setState(_updateTotal),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Quantity', textMuted),
                  TextFormField(controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => setState(_updateTotal),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                ])),
              ]),
            ],
            const SizedBox(height: 14),
            _lbl('Total Amount (₦)', textMuted),
            TextFormField(
              controller: _amountCtrl,
              readOnly: _isSale,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: !_isSale ? [CurrencyInputFormatter()] : [],
              decoration: InputDecoration(
                hintText: '0.00', prefixText: '₦ ',
                filled: _isSale,
                fillColor: _isSale ? const Color(0xFFF1F5F9) : null,
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSale ? AppTheme.primaryColor : AppTheme.successColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(widget.existing != null ? 'Update' : 'Save Entry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _lbl(String t, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)));
}

class _Btn extends StatelessWidget {
  final String label; final bool active; final Color color; final VoidCallback onTap;
  const _Btn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)] : [],
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : const Color(0xFF94A3B8))),
      ),
    );
  }
}
