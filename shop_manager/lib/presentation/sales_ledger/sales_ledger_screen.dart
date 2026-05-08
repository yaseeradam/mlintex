import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';

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

  @override bool operator ==(Object o) => identical(this, o) || o is SalesLedgerEntryAdapter && typeId == o.typeId;
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
  final _tableKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final headerBg = isDark ? AppTheme.surfaceLight : const Color(0xFFE2E8F0);
    final entriesAsync = ref.watch(salesLedgerEntriesProvider);
    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sales Ledger',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                          color: textPrimary, letterSpacing: -1)),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
                      onPressed: () => entriesAsync.whenData((e) => _exportPdf(e, fmt, dateFmt)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                      onPressed: _exportImage,
                    ),
                    GestureDetector(
                      onTap: () => _showSheet(),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryDark]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No sales recorded yet',
                          style: TextStyle(color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ]));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    child: RepaintBoundary(
                      key: _tableKey,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                        headingRowColor: WidgetStateProperty.all(headerBg),
                        columnSpacing: 14,
                        horizontalMargin: 12,
                        headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
                        columns: const [
                          DataColumn(label: Text('S/N')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('IN')),
                          DataColumn(label: Text('OUT')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Total Amount')),
                          DataColumn(label: Text('Total Balance')),
                          DataColumn(label: Text('')),
                        ],
                        rows: entries.asMap().entries.map((e) {
                          final entry = e.value;
                          final isSale = entry.typeIndex == 1;
                          return DataRow(cells: [
                            DataCell(Text('${e.key + 1}',
                                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B)))),
                            DataCell(Text(dateFmt.format(entry.date),
                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B)))),
                            DataCell(Text(isSale ? (entry.inItem ?? '') : '',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
                            DataCell(Text(!isSale ? (entry.outItem ?? '') : '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.successColor))),
                            DataCell(Text(entry.price != null ? '₦${fmt.format(entry.price)}' : '',
                                style: TextStyle(fontSize: 12, color: textPrimary))),
                            DataCell(Text(entry.quantity != null ? '${entry.quantity}' : '',
                                style: TextStyle(fontSize: 12, color: textPrimary))),
                            DataCell(Text('₦${fmt.format(entry.totalAmount)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor))),
                            DataCell(Text('₦${fmt.format(entry.runningBalance)}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: entry.runningBalance > 0 ? AppTheme.errorColor : AppTheme.successColor))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_rounded, size: 16), color: AppTheme.primaryColor,
                                  onPressed: () => _showSheet(existing: entry),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.delete_rounded, size: 16), color: AppTheme.errorColor,
                                  onPressed: () => ref.read(salesLedgerNotifierProvider.notifier).delete(entry.id),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            ])),
                          ]);
                        }).toList(),
                      ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet({SalesLedgerEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SalesEntrySheet(existing: existing),
    );
  }

  Future<void> _exportImage() async {
    try {
      final boundary = _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sales_ledger.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Ledger');
    } catch (e) {
      debugPrint('Image export error: $e');
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
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'sales_ledger.pdf');
  }

  pw.Widget _c(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));
}

// ── Sheet ──────────────────────────────────────────────────────────────────

class _SalesEntrySheet extends ConsumerStatefulWidget {
  final SalesLedgerEntry? existing;
  const _SalesEntrySheet({this.existing});

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

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _isSale = e.typeIndex == 1;
      _itemCtrl.text = e.inItem ?? e.outItem ?? '';
      _priceCtrl.text = e.price?.toString() ?? '';
      _qtyCtrl.text = e.quantity?.toString() ?? '';
      _amountCtrl.text = e.totalAmount.toString();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Entry' : 'New Sales Entry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            // Toggle
            Container(
              decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
                fillColor: _isSale ? (isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFF1F5F9)) : null,
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
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : (isDark ? AppTheme.textMuted : const Color(0xFF94A3B8)))),
      ),
    );
  }
}
