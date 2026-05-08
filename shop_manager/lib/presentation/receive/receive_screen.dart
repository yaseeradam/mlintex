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
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';

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

  @override bool operator ==(Object o) => identical(this, o) || o is ReceiveEntryAdapter && typeId == o.typeId;
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
  final _tableKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final entriesAsync = ref.watch(receiveEntriesProvider);
    final fmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

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
                  Text('Receive', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1)),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
                      onPressed: () => entriesAsync.whenData((e) => _exportPdf(e, fmt, dateFmt)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                      onPressed: () => _exportImage(),
                    ),
                    GestureDetector(
                      onTap: () => _showAddSheet(context),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.successColor, Color(0xFF059669)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: AppTheme.successColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
                      Icon(Icons.inventory_2_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No received items yet', style: TextStyle(color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600)),
                    ]));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    scrollDirection: Axis.vertical,
                    child: RepaintBoundary(
                      key: _tableKey,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                        headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.surfaceLight : const Color(0xFFE2E8F0)),
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
                        columns: const [
                          DataColumn(label: Text('S/N')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Company')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Qty')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('')),
                        ],
                        rows: entries.asMap().entries.map((e) {
                          final entry = e.value;
                          return DataRow(cells: [
                            DataCell(Text('${e.key + 1}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B)))),
                            DataCell(Text(dateFmt.format(entry.date), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : const Color(0xFF64748B)))),
                            DataCell(Text(entry.productName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
                            DataCell(Text(entry.companyName, style: TextStyle(fontSize: 12, color: AppTheme.primaryColor))),
                            DataCell(Text('₦${fmt.format(entry.price)}', style: TextStyle(fontSize: 12, color: textPrimary))),
                            DataCell(Text('${entry.quantity}', style: TextStyle(fontSize: 12, color: textPrimary))),
                            DataCell(Text('₦${fmt.format(entry.totalAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successColor))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_rounded, size: 16), color: AppTheme.primaryColor,
                                  onPressed: () => _showAddSheet(context, existing: entry), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.delete_rounded, size: 16), color: AppTheme.errorColor,
                                  onPressed: () => ref.read(receiveNotifierProvider.notifier).delete(entry.id), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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

  void _showAddSheet(BuildContext context, {ReceiveEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveEntrySheet(existing: existing),
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
      final file = File('${dir.path}/received_stock.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'Received Stock');
    } catch (e) {
      debugPrint('Image export error: $e');
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
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'received_stock.pdf');
  }

  pw.Widget _cell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));
}

// ── Add/Edit Sheet ─────────────────────────────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _productCtrl.text = e.productName;
      _companyCtrl.text = e.companyName;
      _priceCtrl.text = e.price.toString();
      _qtyCtrl.text = e.quantity.toString();
      _totalCtrl.text = e.totalAmount.toString();
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Received Item' : 'Record Received Item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
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
                decoration: InputDecoration(hintText: '0.00', prefixText: '₦ ',
                    filled: true, fillColor: isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFF1F5F9))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(widget.existing != null ? 'Update' : 'Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
