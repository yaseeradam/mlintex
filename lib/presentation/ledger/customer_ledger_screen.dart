import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../core/providers/auth_provider.dart';
import 'ledger_provider.dart';
import '../../core/utils/file_saver.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerShopNumber;
  final String? customerAvatarPath;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerShopNumber,
    this.customerAvatarPath,
  });

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE2E8F0);
    final authState = ref.watch(authProvider);
    final entriesAsync =
        ref.watch(customerLedgerProvider(widget.customerId));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName,
                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
            if (widget.customerShopNumber != null)
              Text(widget.customerShopNumber!,
                  style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
            tooltip: 'Export PDF',
            onPressed: () => entriesAsync.whenData((e) => _exportPdf(e, authState)),
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
          // Calculate summary metrics
          double totalIn = 0;
          double totalOut = 0;
          for (final entry in entries) {
            if (entry.type == LedgerEntryType.sale) {
              totalIn += entry.totalAmount;
            } else {
              totalOut += entry.totalAmount;
            }
          }
          final double remainingDebt = entries.isEmpty ? 0 : entries.last.runningBalance;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  shopName: authState.shopName,
                  customerName: widget.customerName,
                  phone: widget.customerPhone,
                  address: widget.customerAddress,
                  shopNumber: widget.customerShopNumber,
                  avatarPath: widget.customerAvatarPath,
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
                _LedgerFeed(
                  entries: entries,
                  fmt: _fmt,
                  dateFmt: _dateFmt,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  onEdit: (e) => _showEditSheet(context, e),
                  onDelete: (e) => _confirmDelete(context, e),
                  onExport: (e) => _showRowExportSheet(context, e, authState),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
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
                  color: Colors.grey.withValues(alpha: 0.3),
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
              'Choose whether to record credit given or payment received',
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
              title: const Text('Add Goods / Credit (IN)', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
              subtitle: const Text('Record fabric or goods given to customer on credit', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              subtitle: const Text('Record payment or instalment received from customer', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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

  void _showAddEntrySheet(BuildContext context, {bool isSale = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        customerId: widget.customerId,
        initialIsSale: isSale,
      ),
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

    pw.Widget hCell(String t, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft, pw.Widget? child}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: child ?? pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    double totalIn = 0;
    double totalOut = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.sale) {
        totalIn += entry.totalAmount;
      } else {
        totalOut += entry.totalAmount;
      }
    }
    final double remainingDebt = entries.isEmpty ? 0 : entries.last.runningBalance;

    pw.Widget pdfSummaryBox(String title, double amount, PdfColor color, PdfColor bgColor) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 3),
          pw.Text('${PdfTheme.naira}${fmt.format(amount)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
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
              ]),
              pw.Row(
                children: [
                  pdfSummaryBox('TOTAL IN (CREDIT)', totalIn, PdfColors.blue800, PdfColors.blue50),
                  pw.SizedBox(width: 8),
                  pdfSummaryBox('TOTAL PAID (OUT)', totalOut, PdfColors.green800, PdfColors.green50),
                  pw.SizedBox(width: 8),
                  pdfSummaryBox('REMAINING DEBT', remainingDebt, PdfColors.red800, PdfColors.red50),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),   // Date
              1: const pw.FlexColumnWidth(2.5),  // Item/Desc
              2: const pw.FlexColumnWidth(1.2),  // Price (₦)
              3: const pw.FlexColumnWidth(0.8),  // Qty
              4: const pw.FlexColumnWidth(1.3),  // IN (₦)
              5: const pw.FlexColumnWidth(1.3),  // OUT (₦)
              6: const pw.FlexColumnWidth(1.5),  // Balance (₦)
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Item/Desc'),
                  hCell('Price (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Qty', alignment: pw.Alignment.center),
                  hCell('IN (₦)', alignment: pw.Alignment.centerRight),
                  hCell('OUT (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Balance (₦)', alignment: pw.Alignment.centerRight),
                ],
              ),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final isSale = entry.type == LedgerEntryType.sale;
                final rowColor = i.isOdd ? PdfColors.grey50 : PdfColors.white;
                
                final desc = isSale ? (entry.inItem ?? '') : 'PAYMENT';
                final priceStr = isSale ? fmt.format(entry.price) : '—';
                final qtyStr = isSale ? entry.quantity?.toString() ?? '1' : '—';
                final goodsTotal = isSale ? '${PdfTheme.naira}${fmt.format(entry.totalAmount)}' : '—';
                final paymentReceived = !isSale ? fmt.format(entry.totalAmount) : '—';
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowColor),
                  children: [
                    dCell(dateFmt.format(entry.date)),
                    dCell(desc, bold: true),
                    dCell(priceStr, alignment: pw.Alignment.centerRight),
                    dCell(qtyStr, alignment: pw.Alignment.center),
                    dCell(goodsTotal, bold: isSale, alignment: pw.Alignment.centerRight),
                    dCell(
                      !isSale ? '' : '—',
                      bold: !isSale,
                      alignment: pw.Alignment.centerRight,
                      child: !isSale
                          ? pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  entry.outItem ?? 'PAYMENT',
                                  style: pw.TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  '${PdfTheme.naira}$paymentReceived',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    dCell('${PdfTheme.naira}${fmt.format(entry.runningBalance)}', bold: true, alignment: pw.Alignment.centerRight),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final pdfBytes1 = await pdf.save();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await FileSaver.savePdf(context, '${widget.customerName}_ledger.pdf', pdfBytes1);
  }

  Future<void> _exportImage() async {
    final entries = await ref.read(customerLedgerProvider(widget.customerId).future);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    final fmt = NumberFormat('#,##0', 'en_US');
    const bg = Color(0xFFF8FAFC); // clean slate grey-white background for feed canvas
    const textColor = Color(0xFF0F172A);
    const mutedColor = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    final balancePosColor = const Color(0xFFDC2626);
    final balanceNegColor = const Color(0xFF16A34A);

    double totalIn = 0;
    double totalOut = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.sale) {
        totalIn += entry.totalAmount;
      } else {
        totalOut += entry.totalAmount;
      }
    }
    final double remainingDebt = entries.isEmpty ? 0 : entries.last.runningBalance;



    int totalQty = 0;
    double totalInSum = 0;
    double totalOutSum = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.sale) {
        totalQty += entry.quantity ?? 0;
        totalInSum += entry.totalAmount;
      } else {
        totalOutSum += entry.totalAmount;
      }
    }

    // Scrollable width constants matching UI
    const double dateWidth = 65;
    const double itemWidth = 115;
    const double priceWidth = 80;
    const double qtyWidth = 40;
    const double outWidth = 90;
    const double balWidth = 95;
    const double totalTableWidth = dateWidth + itemWidth + priceWidth + qtyWidth + outWidth + balWidth; // 485

    Widget buildStaticFinancialSummaryCard(double totalIn, double totalOut, double remainingDebt) {
      Widget buildItem(String title, double amount, Color color, Color bgColor, IconData icon, {bool isOutstanding = false}) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
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
                        color: color.withValues(alpha: 0.8),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            buildItem('TOTAL IN', totalIn, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), Icons.add_circle_outline_rounded),
            const SizedBox(width: 8),
            buildItem('TOTAL PAID', totalOut, const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.check_circle_outline_rounded),
            const SizedBox(width: 8),
            buildItem('REMAINING', remainingDebt, const Color(0xFFEF4444), const Color(0xFFFEF2F2), Icons.warning_amber_rounded, isOutstanding: true),
          ],
        ),
      );
    }

    Widget buildStaticHeaderCell(
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
          color: const Color(0xFF0F172A), // Slate-900
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

    Widget buildStaticCell(
      String text, {
      required double width,
      bool bold = false,
      Color? textColor,
      Alignment alignment = Alignment.centerLeft,
      bool showRightDivider = true,
      double fontSize = 11,
      EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      Widget? child,
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
        child: child ?? Text(
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

    final captureKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: captureKey,
          child: Material(
            color: bg,
            child: Container(
              width: 520,
              color: bg,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
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
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.person_rounded, size: 14, color: mutedColor),
                          const SizedBox(width: 6),
                          Text(widget.customerName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                        ]),
                        if (widget.customerPhone != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.phone_rounded, size: 13, color: mutedColor),
                            const SizedBox(width: 6),
                            Text(widget.customerPhone!, style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w500)),
                          ]),
                        ],
                        if (widget.customerShopNumber != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.store_rounded, size: 13, color: mutedColor),
                            const SizedBox(width: 6),
                            Text('Shop: ${widget.customerShopNumber!}', style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w500)),
                          ]),
                        ],
                        if (widget.customerAddress != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on_rounded, size: 13, color: mutedColor),
                            const SizedBox(width: 6),
                            Expanded(child: Text(widget.customerAddress!, style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w500))),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  // Summary Dashboard in Shareable Image
                  buildStaticFinancialSummaryCard(totalIn, totalOut, remainingDebt),
                  const SizedBox(height: 4),
                  // Bookkeeping Grid Table Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'BOOKKEEPING LEDGER TABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Static Grid Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: totalTableWidth + 4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Table Header Row
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F172A),
                                border: Border(
                                  left: BorderSide(color: Color(0xFF0F172A), width: 4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  buildStaticHeaderCell('Date', width: dateWidth),
                                  buildStaticHeaderCell('Item/Desc', width: itemWidth),
                                  buildStaticHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                                  buildStaticHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                                  buildStaticHeaderCell('OUT (₦)', width: outWidth, alignment: Alignment.centerRight),
                                  buildStaticHeaderCell('Balance (₦)', width: balWidth, alignment: Alignment.centerRight, showRightDivider: false),
                                ],
                              ),
                            ),



                            // 3. Data Empty Placeholder
                            if (entries.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.grid_off_rounded, size: 40, color: mutedColor.withValues(alpha: 0.4)),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No ledger entries yet',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // 4. Ledger Data Rows
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(entries.length, (index) {
                                  final entry = entries[index];
                                  final isSale = entry.type == LedgerEntryType.sale;
                                  final accentColor = isSale ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
                                  final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                                  final balStr = '₦${fmt.format(entry.runningBalance)}';
                                  final balColor = entry.runningBalance > 0 ? balancePosColor : balanceNegColor;
                                  
                                  final dateStr = DateFormat('dd/MM/yy').format(entry.date);
                                  final descStr = isSale ? (entry.inItem ?? '') : 'PAYMENT';
                                  final priceStr = isSale ? fmt.format(entry.price) : '—';
                                  final qtyStr = isSale ? entry.quantity?.toString() ?? '1' : '—';
                                  final outStr = !isSale ? fmt.format(entry.totalAmount) : '—';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: rowBgColor,
                                      border: Border(
                                        left: BorderSide(color: accentColor, width: 4),
                                        bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        buildStaticCell(dateStr, width: dateWidth),
                                        buildStaticCell(descStr, width: itemWidth, bold: true),
                                        buildStaticCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                        buildStaticCell(qtyStr, width: qtyWidth, alignment: Alignment.center),
                                        buildStaticCell(
                                          !isSale ? '' : outStr,
                                          width: outWidth,
                                          alignment: Alignment.centerRight,
                                          child: !isSale
                                              ? Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      entry.outItem ?? 'PAYMENT',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '₦$outStr',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF10B981),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : null,
                                        ),
                                        buildStaticCell(
                                          balStr,
                                          width: balWidth,
                                          bold: true,
                                          alignment: Alignment.centerRight,
                                          textColor: balColor,
                                          showRightDivider: false,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),

                            // 5. Bookkeeping Summary Footer Row
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9), // Gray-100
                                border: Border(
                                  left: BorderSide(color: Color(0xFF475569), width: 4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  buildStaticCell('Totals', width: dateWidth, bold: true, textColor: const Color(0xFF475569)),
                                  buildStaticCell('IN: ₦${fmt.format(totalInSum)}', width: itemWidth, bold: true, textColor: const Color(0xFF1E3A8A), fontSize: 9.5),
                                  buildStaticCell('—', width: priceWidth, alignment: Alignment.centerRight, textColor: const Color(0xFF94A3B8)),
                                  buildStaticCell('$totalQty', width: qtyWidth, bold: true, alignment: Alignment.center, textColor: const Color(0xFF0F172A)),
                                  buildStaticCell('₦${fmt.format(totalOutSum)}', width: outWidth, bold: true, alignment: Alignment.centerRight, textColor: const Color(0xFF15803D)),
                                  buildStaticCell(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) { overlay.remove(); return; }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.customerName}_ledger.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await FileSaver.saveImage(context, file);
    } catch (e) {
      debugPrint('Image export error: $e');
    } finally {
      overlay.remove();
    }
  }



  // ── Per-row export ──────────────────────────────────────────────────────

  void _showRowExportSheet(BuildContext context, LedgerEntry entry, AuthState auth) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
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
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Export Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
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
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor, size: 22),
              ),
              title: Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Share a PDF receipt for this entry', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              title: Text('Export as Image', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Share a PNG image of this entry', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
    final pdf = pw.Document(theme: await PdfTheme.load());

    pw.Widget hCell(String t, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft, pw.Widget? child}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: child ?? pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    final desc = isSale ? (entry.inItem ?? '') : 'PAYMENT';
    final priceStr = isSale ? fmt.format(entry.price) : '—';
    final qtyStr = isSale ? entry.quantity?.toString() ?? '1' : '—';
    final goodsTotal = isSale ? '${PdfTheme.naira}${fmt.format(entry.totalAmount)}' : '—';
    final paymentReceived = !isSale ? fmt.format(entry.totalAmount) : '—';

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
          if (widget.customerAddress != null)
            pw.Text('Address: ${widget.customerAddress}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),   // Date
              1: const pw.FlexColumnWidth(2.5),  // Item/Desc
              2: const pw.FlexColumnWidth(1.2),  // Price (₦)
              3: const pw.FlexColumnWidth(0.8),  // Qty
              4: const pw.FlexColumnWidth(1.3),  // IN (₦)
              5: const pw.FlexColumnWidth(1.3),  // OUT (₦)
              6: const pw.FlexColumnWidth(1.5),  // Balance (₦)
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Item/Desc'),
                  hCell('Price (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Qty', alignment: pw.Alignment.center),
                  hCell('IN (₦)', alignment: pw.Alignment.centerRight),
                  hCell('OUT (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Balance (₦)', alignment: pw.Alignment.centerRight),
                ],
              ),
              pw.TableRow(
                children: [
                  dCell(dateFmt.format(entry.date)),
                  dCell(desc, bold: true),
                  dCell(priceStr, alignment: pw.Alignment.centerRight),
                  dCell(qtyStr, alignment: pw.Alignment.center),
                  dCell(goodsTotal, bold: isSale, alignment: pw.Alignment.centerRight),
                  dCell(
                    !isSale ? '' : '—',
                    bold: !isSale,
                    alignment: pw.Alignment.centerRight,
                    child: !isSale
                        ? pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                entry.outItem ?? 'PAYMENT',
                                style: pw.TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                '${PdfTheme.naira}$paymentReceived',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
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
    // ignore: use_build_context_synchronously
    await FileSaver.savePdf(context, '${widget.customerName}_entry_${entry.id.substring(0, 6)}.pdf', rowPdfBytes);
  }

  Future<void> _exportRowImage(
    LedgerEntry entry,
    AuthState auth,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) async {
    final isSale = entry.type == LedgerEntryType.sale;
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
                  // Receipt Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
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
                          Icon(Icons.person_rounded, size: 14, color: mutedColor),
                          const SizedBox(width: 6),
                          Text(widget.customerName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                        ]),
                        if (widget.customerPhone != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.phone_rounded, size: 13, color: mutedColor),
                            const SizedBox(width: 6),
                            Text(widget.customerPhone!, style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Transaction Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
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
                                color: accentColor.withValues(alpha: 0.1),
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
                                    color: (bal > 0 ? balancePosColor : balanceNegColor).withValues(alpha: 0.08),
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
      final file = File('${dir.path}/${widget.customerName}_entry_${entry.id.substring(0, 6)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await FileSaver.saveImage(context, file);
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
  final String? avatarPath;
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
    this.avatarPath,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve display shop name (fall back to app name if not set)
    final displayShop = (shopName.isEmpty || shopName.toLowerCase() == 'admin')
        ? 'M Lin Tex'
        : shopName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Shop name at top (owner's shop)
          Text(
            displayShop,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          // Customer avatar + name
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
              image: (avatarPath != null && avatarPath!.isNotEmpty)
                  ? DecorationImage(
                      image: FileImage(File(avatarPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: (avatarPath == null || avatarPath!.isEmpty)
                ? Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            customerName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          // Customer details: phone, shop number, address
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (phone != null && phone!.isNotEmpty)
                _detail(Icons.phone_rounded, phone!),
              if (shopNumber != null && shopNumber!.isNotEmpty)
                _detail(Icons.store_rounded, 'Shop: $shopNumber'),
              if (address != null && address!.isNotEmpty)
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
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}

class _LedgerFeed extends StatelessWidget {
  final List<LedgerEntry> entries;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final void Function(LedgerEntry) onEdit;
  final void Function(LedgerEntry) onDelete;
  final void Function(LedgerEntry) onExport;

  const _LedgerFeed({
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
        color: const Color(0xFF0F172A), // Slate-900
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
    Widget? child,
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
      child: child ?? Text(
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

  void _showRowActionMenu(BuildContext context, LedgerEntry entry) {
    final isSale = entry.type == LedgerEntryType.sale;
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
            // Grab handle
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
            // Info card inside sheet
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
                      color: accentColor.withValues(alpha: 0.1),
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
                        isSale ? 'CREDIT (IN)' : 'PAYMENT (OUT)',
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
            // Actions
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



    // Calculate footer visible sums
    int totalQty = 0;
    double totalInSum = 0;
    double totalOutSum = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.sale) {
        totalQty += entry.quantity ?? 0;
        totalInSum += entry.totalAmount;
      } else {
        totalOutSum += entry.totalAmount;
      }
    }

    // Scrollable width constants
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
        // Section Header
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

        // Horizontal Scrollable Bookkeeping Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                width: totalTableWidth + 4, // Add left border padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Table Header Row
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



                    // 3. Data Empty Placeholder
                    if (entries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_off_rounded, size: 40, color: textMuted.withValues(alpha: 0.4)),
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
                      // 4. Ledger Data Rows
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSale = entry.type == LedgerEntryType.sale;
                          final accentColor = isSale ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
                          final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                          final balStr = '₦${fmt.format(entry.runningBalance)}';
                          final balColor = entry.runningBalance > 0 ? balancePosColor : balanceNegColor;
                          
                          final dateStr = DateFormat('dd/MM/yy').format(entry.date);
                          final descStr = isSale ? (entry.inItem ?? '') : 'PAYMENT';
                          final priceStr = isSale ? fmt.format(entry.price) : '—';
                          final qtyStr = isSale ? entry.quantity?.toString() ?? '1' : '—';
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
                                    _buildCell(
                                      !isSale ? '' : outStr,
                                      width: outWidth,
                                      alignment: Alignment.centerRight,
                                      child: !isSale
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  entry.outItem ?? 'PAYMENT',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '₦$outStr',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null,
                                    ),
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
                        },
                      ),

                    // 5. Bookkeeping Summary Footer Row
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9), // Gray-100
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

class _AddEntrySheet extends ConsumerStatefulWidget {
  final String customerId;
  final LedgerEntry? existing;
  final bool initialIsSale;

  const _AddEntrySheet({
    required this.customerId,
    this.existing,
    this.initialIsSale = true,
  });

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();

  final _inItemController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _amountController = TextEditingController();
  final _outItemController = TextEditingController();
  final _outAmountController = TextEditingController();

  bool _isSale = true;
  final _numFmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _isSale = e.type == LedgerEntryType.sale;
      if (_isSale) {
        _inItemController.text = e.inItem ?? '';
        _priceController.text = e.price != null ? _numFmt.format(e.price) : '';
        _qtyController.text = e.quantity?.toString() ?? '';
        _amountController.text = _numFmt.format(e.totalAmount);
      } else {
        _outItemController.text = e.outItem ?? '';
        _outAmountController.text = _numFmt.format(e.totalAmount);
      }
    } else {
      _isSale = widget.initialIsSale;
    }
  }

  @override
  void dispose() {
    _inItemController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _amountController.dispose();
    _outItemController.dispose();
    _outAmountController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final price = CurrencyInputFormatter.parse(_priceController.text);
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (price > 0 && qty > 0) {
      _amountController.text =
          NumberFormat('#,##0', 'en_US').format(price * qty);
    } else {
      _amountController.text = '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(ledgerNotifierProvider.notifier);

    if (widget.existing != null) {
      final e = widget.existing!;
      if (_isSale) {
        final price = CurrencyInputFormatter.parse(_priceController.text);
        final qty = int.tryParse(_qtyController.text) ?? 1;
        final total = CurrencyInputFormatter.parse(_amountController.text);
        final updated = LedgerEntry(
          id: e.id,
          customerId: e.customerId,
          date: e.date,
          inItem: _inItemController.text.trim(),
          outItem: null,
          price: price,
          quantity: qty,
          totalAmount: total > 0 ? total : price * qty,
          typeIndex: LedgerEntryType.sale.index,
        );
        await notifier.updateEntry(updated);
      } else {
        final amount = CurrencyInputFormatter.parse(_outAmountController.text);
        final outDesc = _outItemController.text.trim();
        final updated = LedgerEntry(
          id: e.id,
          customerId: e.customerId,
          date: e.date,
          inItem: null,
          outItem: outDesc.isEmpty ? 'PAYMENT' : outDesc,
          price: amount,
          quantity: null,
          totalAmount: amount,
          typeIndex: LedgerEntryType.payment.index,
        );
        await notifier.updateEntry(updated);
      }
    } else {
      if (_isSale) {
        await notifier.addSaleEntry(
          customerId: widget.customerId,
          itemName: _inItemController.text.trim(),
          price: CurrencyInputFormatter.parse(_priceController.text),
          quantity: int.parse(_qtyController.text.trim()),
        );
      } else {
        final amount = CurrencyInputFormatter.parse(_outAmountController.text);
        final outDesc = _outItemController.text.trim();
        await notifier.addPaymentEntry(
          customerId: widget.customerId,
          bankOrCash: outDesc.isEmpty ? 'PAYMENT' : outDesc,
          amount: amount,
        );
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

    final String sheetTitle;
    if (widget.existing != null) {
      sheetTitle = _isSale ? 'Edit Credit (IN)' : 'Edit Payment (OUT)';
    } else {
      sheetTitle = _isSale ? 'New Credit (IN)' : 'New Payment (OUT)';
    }

    final String sheetSubtitle = _isSale
        ? 'Record goods / fabric given to customer on credit'
        : 'Record payment / instalment received from customer';

    final String buttonText;
    if (widget.existing != null) {
      buttonText = _isSale ? 'Update Credit' : 'Update Payment';
    } else {
      buttonText = _isSale ? 'Save Credit' : 'Save Payment';
    }

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                sheetTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                sheetSubtitle,
                style: const TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),
              
              // IN fields
              if (_isSale) ...[
                const Text('Product / Item Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _inItemController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'e.g. LIN ROMAN 150y'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Price (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => _updateTotal(),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => _updateTotal(),
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Required';
                        final q = int.tryParse(v.trim());
                        if (q == null || q <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),
                const Text('Total Amount (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  readOnly: true,
                  decoration: const InputDecoration(hintText: '0', prefixText: '₦ ', filled: true, fillColor: Color(0xFFF1F5F9)),
                ),
              ],
              // OUT fields
              if (!_isSale) ...[
                const Text('Bank / Cash Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _outItemController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'e.g. DIAMOND BANK'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const Text('Amount Paid (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 4),
                Text('Can be partial — customer can pay in instalments',
                    style: TextStyle(fontSize: 11, color: AppTheme.successColor.withValues(alpha: 0.8))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _outAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(hintText: '0', prefixText: '₦ '),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Required';
                    if (CurrencyInputFormatter.parse(v.trim()) <= 0) return 'Amount must be > 0';
                    return null;
                  },
                ),
              ],
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
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildItem(
            title: 'TOTAL IN',
            amount: totalIn,
            color: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            icon: Icons.add_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _buildItem(
            title: 'TOTAL PAID',
            amount: totalOut,
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _buildItem(
            title: 'REMAINING',
            amount: remainingDebt,
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            icon: Icons.warning_amber_rounded,
            isOutstanding: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
    bool isOutstanding = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.8),
                    letterSpacing: 0.2,
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
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onAddSale,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add Goods (IN)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onAddPayment,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add Payment (OUT)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


