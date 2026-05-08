import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/glass_container.dart';
import 'ledger_provider.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerShopNumber;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerShopNumber,
  });

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  final _tableKey = GlobalKey();
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final cardBg = isDark ? AppTheme.surfaceColor : Colors.white;
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);
    final authState = ref.watch(authProvider);
    final entriesAsync =
        ref.watch(customerLedgerProvider(widget.customerId));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.customerName,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
            tooltip: 'Export PDF',
            onPressed: () => entriesAsync.whenData((e) => _exportPdf(e, authState)),
          ),
          IconButton(
            icon: Icon(Icons.image_rounded, color: AppTheme.primaryColor),
            tooltip: 'Export Image',
            onPressed: () => entriesAsync.whenData((e) => _exportImage()),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppTheme.primaryColor),
            tooltip: 'Add Entry',
            onPressed: () => _showAddEntrySheet(context),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              RepaintBoundary(
                key: _tableKey,
                child: Container(
                  color: bg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(
                        shopName: authState.shopName,
                        customerName: widget.customerName,
                        phone: widget.customerPhone,
                        address: widget.customerAddress,
                        shopNumber: widget.customerShopNumber,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 16),
                      _LedgerTable(
                        entries: entries,
                        fmt: _fmt,
                        dateFmt: _dateFmt,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onEdit: (e) => _showEditSheet(context, e),
                        onDelete: (e) => _confirmDelete(context, e),
                        onExport: (e) => _showRowExportSheet(context, e, authState),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEntrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(customerId: widget.customerId),
    );
  }

  void _showEditSheet(BuildContext context, LedgerEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        customerId: widget.customerId,
        existing: entry,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LedgerEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this ledger entry? This cannot be undone.'),
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
      await ref.read(ledgerNotifierProvider.notifier).deleteEntry(entry.id);
    }
  }

  Future<void> _exportPdf(List<LedgerEntry> entries, AuthState auth) async {
    final pdf = pw.Document(theme: await PdfTheme.load());
    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    pw.Widget hCell(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text('Customer: ${widget.customerName}', style: const pw.TextStyle(fontSize: 11)),
            if (widget.customerPhone != null)
              pw.Text('Phone: ${widget.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
            if (widget.customerShopNumber != null)
              pw.Text('Shop No: ${widget.customerShopNumber}', style: const pw.TextStyle(fontSize: 10)),
            if (widget.customerAddress != null)
              pw.Text('Address: ${widget.customerAddress}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ]),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(95),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FixedColumnWidth(65),
              5: const pw.FixedColumnWidth(42),
              6: const pw.FixedColumnWidth(72),
              7: const pw.FixedColumnWidth(72),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Quantity', 'Total Amount', 'Total Balance']
                    .map(hCell).toList(),
              ),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final isSale = entry.type == LedgerEntryType.sale;
                final priceText = isSale
                    ? (entry.price != null ? '${PdfTheme.naira}${fmt.format(entry.price)}' : '')
                    : '${PdfTheme.naira}${fmt.format(entry.totalAmount)}';
                final rowColor = i.isOdd ? PdfColors.grey50 : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowColor),
                  children: [
                    dCell('${i + 1}'),
                    dCell(dateFmt.format(entry.date)),
                    dCell(isSale ? (entry.inItem ?? '') : ''),
                    dCell(!isSale ? (entry.outItem ?? '') : ''),
                    dCell(priceText),
                    dCell(entry.quantity != null ? '${entry.quantity}' : ''),
                    dCell('${PdfTheme.naira}${fmt.format(entry.totalAmount)}', bold: true),
                    dCell('${PdfTheme.naira}${fmt.format(entry.runningBalance)}', bold: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${widget.customerName}_ledger.pdf',
    );
  }

  pw.Widget _pdfCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 7)),
      );

  Future<void> _exportImage() async {
    try {
      final boundary =
          _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.customerName}_ledger.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.customerName} Ledger',
      );
    } catch (e) {
      debugPrint('Image export error: $e');
    }
  }

  // ── Per-row export ──────────────────────────────────────────────────────

  void _showRowExportSheet(BuildContext context, LedgerEntry entry, AuthState auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isSale = entry.type == LedgerEntryType.sale;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Export Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(
              isSale ? (entry.inItem ?? 'Sale') : (entry.outItem ?? 'Payment'),
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B)),
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
              title: Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Share a PDF receipt for this entry', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowPdf(entry, auth, fmt, dateFmt);
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
              title: Text('Export as Image', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Share a PNG image of this entry', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowImage(entry, auth, fmt, dateFmt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRowPdf(
    LedgerEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final isSale = entry.type == LedgerEntryType.sale;
    final priceText = isSale
        ? (entry.price != null ? '${PdfTheme.naira}${fmt.format(entry.price)}' : '')
        : '${PdfTheme.naira}${fmt.format(entry.totalAmount)}';
    final pdf = pw.Document(theme: await PdfTheme.load());

    pw.Widget hCell(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Customer: ${widget.customerName}', style: const pw.TextStyle(fontSize: 10)),
          if (widget.customerPhone != null)
            pw.Text('Phone: ${widget.customerPhone}', style: const pw.TextStyle(fontSize: 9)),
          if (widget.customerShopNumber != null)
            pw.Text('Shop No: ${widget.customerShopNumber}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(95),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FixedColumnWidth(65),
              5: const pw.FixedColumnWidth(42),
              6: const pw.FixedColumnWidth(72),
              7: const pw.FixedColumnWidth(72),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Quantity', 'Total Amount', 'Total Balance']
                    .map(hCell).toList(),
              ),
              pw.TableRow(
                children: [
                  dCell('1'),
                  dCell(dateFmt.format(entry.date)),
                  dCell(isSale ? (entry.inItem ?? '') : ''),
                  dCell(!isSale ? (entry.outItem ?? '') : ''),
                  dCell(priceText),
                  dCell(entry.quantity != null ? '${entry.quantity}' : ''),
                  dCell('${PdfTheme.naira}${fmt.format(entry.totalAmount)}'),
                  dCell('${PdfTheme.naira}${fmt.format(entry.runningBalance)}'),
                ],
              ),
            ],
          ),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${widget.customerName}_entry_${entry.id.substring(0, 6)}.pdf',
    );
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    ),
  );

  Future<void> _exportRowImage(
    LedgerEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final isSale = entry.type == LedgerEntryType.sale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final divColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final priceText = isSale
        ? (entry.price != null ? '\u20a6${fmt.format(entry.price)}' : '')
        : '\u20a6${fmt.format(entry.totalAmount)}';

    final cols = ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Quantity', 'Total Amount', 'Total Balance'];
    final vals = [
      '1',
      dateFmt.format(entry.date),
      isSale ? (entry.inItem ?? '') : '',
      !isSale ? (entry.outItem ?? '') : '',
      priceText,
      entry.quantity != null ? '${entry.quantity}' : '',
      '\u20a6${fmt.format(entry.totalAmount)}',
      '\u20a6${fmt.format(entry.runningBalance)}',
    ];

    Widget cell(String t, {bool header = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: header ? headerBg : null,
        border: Border.all(color: divColor, width: 0.5),
      ),
      child: Text(t,
        style: TextStyle(
          fontSize: 11,
          fontWeight: header ? FontWeight.w700 : FontWeight.w400,
          color: header ? textColor : textColor,
        ),
      ),
    );

    final receiptKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: receiptKey,
          child: Material(
            color: bg,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(auth.shopName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                  const SizedBox(height: 2),
                  Text('Customer: ${widget.customerName}',
                      style: TextStyle(fontSize: 12, color: textColor)),
                  if (widget.customerPhone != null)
                    Text('Phone: ${widget.customerPhone}',
                        style: TextStyle(fontSize: 11, color: mutedColor)),
                  if (widget.customerShopNumber != null)
                    Text('Shop No: ${widget.customerShopNumber}',
                        style: TextStyle(fontSize: 11, color: mutedColor)),
                  const SizedBox(height: 12),
                  // Table header row
                  Row(children: cols.map((c) => Expanded(child: cell(c, header: true))).toList()),
                  // Table data row
                  Row(children: vals.map((v) => Expanded(child: cell(v))).toList()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      final boundary = receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.customerName}_entry_${entry.id.substring(0, 6)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '${widget.customerName} - Entry');
    } finally {
      overlay.remove();
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final String shopName;
  final String customerName;
  final String? phone;
  final String? address;
  final String? shopNumber;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;

  const _HeaderCard({
    required this.shopName,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.shopNumber,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF0F2A1E)]
              : [const Color(0xFF1E40AF), const Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Avatar + name centered
          Column(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 10),
              Text(customerName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(shopName.isEmpty || shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : shopName,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          // Details row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (phone != null)
                _detail(Icons.phone_rounded, phone!),
              if (shopNumber != null)
                _detail(Icons.store_rounded, shopNumber!),
              if (address != null)
                _detail(Icons.location_on_rounded, address!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}

class _LedgerTable extends StatelessWidget {
  final List<LedgerEntry> entries;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final void Function(LedgerEntry) onEdit;
  final void Function(LedgerEntry) onDelete;
  final void Function(LedgerEntry) onExport;

  const _LedgerTable({
    required this.entries,
    required this.fmt,
    required this.dateFmt,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final headerBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFF1E40AF);
    const headerText = Colors.white;
    final inRowBg = isDark ? const Color(0xFF0F1F35) : const Color(0xFFEFF6FF);
    final outRowBg = isDark ? const Color(0xFF0A1F14) : const Color(0xFFF0FDF4);
    final inItemColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final outItemColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    final priceColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
    final totalColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
    final balancePosColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final balanceNegColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final divider = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE);
    final snColor = isDark ? AppTheme.textMuted : const Color(0xFF94A3B8);
    final dateColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: divider, width: 0.8),
              verticalInside: BorderSide(color: divider, width: 0.8),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  _th('S/N', headerText),
                  _th('Date', headerText),
                  _th('IN', headerText),
                  _th('OUT', headerText),
                  _th('Price', headerText),
                  _th('Quantity', headerText),
                  _th('Total Amount', headerText),
                  _th('Total Balance', headerText),
                  _th('', headerText),
                ],
              ),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final isSale = entry.type == LedgerEntryType.sale;
                final rowBg = isSale ? inRowBg : outRowBg;
                final priceTxt = isSale
                    ? (entry.price != null ? '\u20a6${fmt.format(entry.price)}' : '')
                    : '\u20a6${fmt.format(entry.totalAmount)}';
                final bal = entry.runningBalance;

                return TableRow(
                  decoration: BoxDecoration(color: rowBg),
                  children: [
                    _td('${i + 1}', snColor, center: true),
                    _td(dateFmt.format(entry.date), dateColor),
                    _td(isSale ? (entry.inItem ?? '') : '', inItemColor, bold: isSale),
                    _td(!isSale ? (entry.outItem ?? '') : '', outItemColor, bold: !isSale),
                    _td(priceTxt, priceColor),
                    _td(entry.quantity != null ? '${entry.quantity}' : '', textPrimary, center: true),
                    _td('\u20a6${fmt.format(entry.totalAmount)}', totalColor, bold: true),
                    _td('\u20a6${fmt.format(bal)}', bal > 0 ? balancePosColor : balanceNegColor, bold: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _act(Icons.edit_rounded, AppTheme.primaryColor, () => onEdit(entry)),
                          _act(Icons.ios_share_rounded, AppTheme.successColor, () => onExport(entry)),
                          _act(Icons.delete_rounded, AppTheme.errorColor, () => onDelete(entry)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _th(String t, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _td(String t, Color c, {bool bold = false, bool center = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Text(t,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: c)),
  );

  Widget _act(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}

class _AddEntrySheet extends ConsumerStatefulWidget {
  final String customerId;
  final LedgerEntry? existing;

  const _AddEntrySheet({required this.customerId, this.existing});

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isSale = true; // true = IN (sale), false = OUT (payment)

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _isSale = e.type == LedgerEntryType.sale;
      _itemController.text = e.inItem ?? e.outItem ?? '';
      _priceController.text = e.price?.toString() ?? '';
      _qtyController.text = e.quantity?.toString() ?? '';
      _amountController.text = e.totalAmount.toString();
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    if (_isSale) {
      final price = CurrencyInputFormatter.parse(_priceController.text);
      final qty = int.tryParse(_qtyController.text) ?? 0;
      if (price > 0 && qty > 0) {
        _amountController.text = NumberFormat('#,##0', 'en_US').format(price * qty);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(ledgerNotifierProvider.notifier);

    if (widget.existing != null) {
      final e = widget.existing!;
      final updated = LedgerEntry(
        id: e.id,
        customerId: e.customerId,
        date: e.date,
        inItem: _isSale ? _itemController.text.trim() : null,
        outItem: !_isSale ? _itemController.text.trim() : null,
        price: _isSale ? CurrencyInputFormatter.parse(_priceController.text) : null,
        quantity: _isSale ? int.tryParse(_qtyController.text) : null,
        totalAmount: CurrencyInputFormatter.parse(_amountController.text),
        typeIndex: _isSale ? 1 : 0,
      );
      await notifier.updateEntry(updated);
    } else {
      if (_isSale) {
        await notifier.addSaleEntry(
          customerId: widget.customerId,
          itemName: _itemController.text.trim(),
          price: CurrencyInputFormatter.parse(_priceController.text),
          quantity: int.parse(_qtyController.text.trim()),
        );
      } else {
        await notifier.addPaymentEntry(
          customerId: widget.customerId,
          bankOrCash: _itemController.text.trim(),
          amount: CurrencyInputFormatter.parse(_amountController.text),
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.existing != null ? 'Edit Entry' : 'New Entry',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 16),

              // Type toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _TypeBtn(label: 'Sale (IN)', active: _isSale,
                        color: AppTheme.primaryColor,
                        onTap: () => setState(() => _isSale = true))),
                    Expanded(child: _TypeBtn(label: 'Payment (OUT)', active: !_isSale,
                        color: AppTheme.successColor,
                        onTap: () => setState(() => _isSale = false))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(_isSale ? 'Item Name' : 'Bank / Cash',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _itemController,
                decoration: InputDecoration(
                    hintText: _isSale ? 'e.g. LIN ROMAN 150y' : 'e.g. DIAMOND BANK'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),

              if (_isSale) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Price (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(hintText: '0.00'),
                      onChanged: (_) => setState(_updateTotal),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => setState(_updateTotal),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ])),
                ]),
              ],

              const SizedBox(height: 14),
              Text('Total Amount (₦)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: !_isSale ? [CurrencyInputFormatter()] : [],
                readOnly: _isSale,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '₦ ',
                  filled: _isSale,
                  fillColor: _isSale
                      ? (isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFF1F5F9))
                      : null,
                ),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Required';
                  if (CurrencyInputFormatter.parse(v.trim()) <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSale ? AppTheme.primaryColor : AppTheme.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.existing != null ? 'Update Entry' : 'Save Entry',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppTheme.surfaceColor : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)] : [],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : (isDark ? AppTheme.textMuted : const Color(0xFF94A3B8)))),
      ),
    );
  }
}

