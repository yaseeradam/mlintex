import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_theme.dart';
import '../../core/utils/file_saver.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/pending_sync_tracker.dart';
import '../../core/services/firestore_service.dart';
import '../../core/providers/repository_providers.dart';
import '../products/product_provider.dart';

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
  @HiveField(7) final double? payment;
  @HiveField(8) final DateTime? paymentDate;
  @HiveField(9) final String? description;

  ReceiveEntry({
    required this.id,
    required this.date,
    required this.productName,
    required this.companyName,
    required this.price,
    required this.quantity,
    required this.totalAmount,
    this.payment = 0.0,
    this.paymentDate,
    this.description = '',
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
      productName: f[2] as String, companyName: f[3] as String? ?? '',
      price: f[4] as double, quantity: f[5] as int, totalAmount: f[6] as double,
      payment: (f[7] as num?)?.toDouble() ?? 0.0,
      paymentDate: f[8] as DateTime?,
      description: f[9] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ReceiveEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.date)
      ..writeByte(2)..write(obj.productName)
      ..writeByte(3)..write(obj.companyName)
      ..writeByte(4)..write(obj.price)
      ..writeByte(5)..write(obj.quantity)
      ..writeByte(6)..write(obj.totalAmount)
      ..writeByte(7)..write(obj.payment ?? 0.0)
      ..writeByte(8)..write(obj.paymentDate)
      ..writeByte(9)..write(obj.description ?? '');
  }

  @override bool operator ==(Object other) => identical(this, other) || other is ReceiveEntryAdapter && typeId == other.typeId;
  @override int get hashCode => typeId.hashCode;
}

// ── Provider ───────────────────────────────────────────────────────────────

ReceiveEntry _fromReceiveMap(Map<String, dynamic> map) {
  final rawPrice = map['price'];
  final price = (rawPrice is num) ? rawPrice.toDouble() : (double.tryParse(rawPrice?.toString() ?? '') ?? 0.0);

  final rawQty = map['quantity'];
  final quantity = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty?.toString() ?? '') ?? 0);

  final rawTotal = map['totalAmount'];
  final totalAmount = (rawTotal is num) ? rawTotal.toDouble() : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0);

  final rawPay = map['payment'];
  final payment = (rawPay is num) ? rawPay.toDouble() : double.tryParse(rawPay?.toString() ?? '');

  return ReceiveEntry(
    id: map['id']?.toString() ?? '',
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    productName: map['productName']?.toString() ?? '',
    companyName: map['companyName']?.toString() ?? '',
    price: price,
    quantity: quantity,
    totalAmount: totalAmount,
    payment: payment,
    paymentDate: map['paymentDate'] != null ? DateTime.tryParse(map['paymentDate'].toString()) : null,
    description: map['description']?.toString(),
  );
}

Map<String, dynamic> _toReceiveMap(ReceiveEntry r, String shopId) {
  return {
    'id': r.id,
    'date': r.date.toIso8601String(),
    'productName': r.productName,
    'companyName': r.companyName,
    'price': r.price,
    'quantity': r.quantity,
    'totalAmount': r.totalAmount,
    'payment': r.payment,
    'paymentDate': r.paymentDate?.toIso8601String(),
    'description': r.description,
    'shopId': shopId,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

final receiveEntriesProvider = StreamProvider<List<ReceiveEntry>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  final col = FirestoreService.userCollection('receive_entries');

  return col.snapshots().map((snapshot) {
    final list = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final sId = data['shopId']?.toString();
          return shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
        })
        .map((doc) => _fromReceiveMap(doc.data()))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  });
});

class ReceiveNotifier extends Notifier<void> {
  @override void build() {}

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreService.userCollection('receive_entries');
  String get _shopId => FirestoreService.activeShopId;

  Future<void> add({
    required String product,
    required double price,
    required int qty,
    double payment = 0.0,
    double? totalAmount,
    DateTime? paymentDate,
    String? description,
  }) async {
    final finalTotal = totalAmount ?? (price * qty);
    final e = ReceiveEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      productName: product,
      companyName: '',
      price: price,
      quantity: qty,
      totalAmount: finalTotal,
      payment: payment,
      paymentDate: paymentDate,
      description: description ?? '',
    );

    await _collection.doc(e.id).set(_toReceiveMap(e, _shopId), SetOptions(merge: true));

    // Increment inventory if matching product exists
    if (qty > 0 && product.trim().isNotEmpty) {
      try {
        final allProds = await ref.read(productRepositoryProvider).getAllProducts();
        final matches = allProds.where((p) => p.name.trim().toLowerCase() == product.trim().toLowerCase());
        if (matches.isNotEmpty) {
          await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, qty);
        }
      } catch (_) {}
    }
  }

  Future<void> update(ReceiveEntry e) async {
    final docRef = _collection.doc(e.id);
    final oldDoc = await docRef.get();
    int delta = 0;
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromReceiveMap(oldDoc.data()!);
      delta = e.quantity - old.quantity;
    }

    await docRef.set(_toReceiveMap(e, _shopId), SetOptions(merge: true));

    if (delta != 0 && e.productName.trim().isNotEmpty) {
      try {
        final allProds = await ref.read(productRepositoryProvider).getAllProducts();
        final matches = allProds.where((p) => p.name.trim().toLowerCase() == e.productName.trim().toLowerCase());
        if (matches.isNotEmpty) {
          await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, delta);
        }
      } catch (_) {}
    }
  }

  Future<void> delete(String id) async {
    final docRef = _collection.doc(id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromReceiveMap(oldDoc.data()!);
      if (old.quantity > 0 && old.productName.trim().isNotEmpty) {
        try {
          final allProds = await ref.read(productRepositoryProvider).getAllProducts();
          final matches = allProds.where((p) => p.name.trim().toLowerCase() == old.productName.trim().toLowerCase());
          if (matches.isNotEmpty) {
            await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, -old.quantity);
          }
        } catch (_) {}
      }
    }
    await docRef.delete();
  }
}

final receiveNotifierProvider = NotifierProvider<ReceiveNotifier, void>(ReceiveNotifier.new);

// ── UI UI Rows Class & Splitter ────────────────────────────────────────────

class ReceiveUiRow {
  final String id;
  final DateTime displayDate;
  final String productName;
  final double payment;
  final double price;
  final int quantity;
  final double totalAmount;
  final ReceiveEntry originalEntry;
  final bool isPaymentRow;

  ReceiveUiRow({
    required this.id,
    required this.displayDate,
    required this.productName,
    required this.payment,
    required this.price,
    required this.quantity,
    required this.totalAmount,
    required this.originalEntry,
    this.isPaymentRow = false,
  });
}

List<ReceiveUiRow> buildUiRows(List<ReceiveEntry> entries) {
  final List<ReceiveUiRow> rows = [];
  for (final entry in entries) {
    final isEntryPaymentOnly = entry.productName.trim().isEmpty ||
        entry.productName.trim().toLowerCase() == 'payment only' ||
        (entry.price == 0 && entry.quantity == 0 && entry.totalAmount == 0 && (entry.payment ?? 0) > 0);

    if (entry.payment != null && entry.payment! > 0 && entry.paymentDate != null) {
      final isSameDay = entry.date.year == entry.paymentDate!.year &&
          entry.date.month == entry.paymentDate!.month &&
          entry.date.day == entry.paymentDate!.day;
      if (isSameDay) {
        rows.add(ReceiveUiRow(
          id: entry.id,
          displayDate: entry.date,
          productName: isEntryPaymentOnly ? '' : entry.productName,
          payment: entry.payment ?? 0.0,
          price: entry.price,
          quantity: entry.quantity,
          totalAmount: entry.totalAmount,
          originalEntry: entry,
          isPaymentRow: isEntryPaymentOnly,
        ));
      } else {
        if (entry.price > 0 || entry.quantity > 0 || entry.totalAmount > 0) {
          rows.add(ReceiveUiRow(
            id: '${entry.id}_del',
            displayDate: entry.date,
            productName: entry.productName.trim().isEmpty ? 'Fabric Delivery' : entry.productName,
            payment: 0.0,
            price: entry.price,
            quantity: entry.quantity,
            totalAmount: entry.totalAmount,
            originalEntry: entry,
            isPaymentRow: false,
          ));
        }
        rows.add(ReceiveUiRow(
          id: '${entry.id}_pay',
          displayDate: entry.paymentDate!,
          productName: '',
          payment: entry.payment ?? 0.0,
          price: 0.0,
          quantity: 0,
          totalAmount: 0.0,
          originalEntry: entry,
          isPaymentRow: true,
        ));
      }
    } else {
      rows.add(ReceiveUiRow(
        id: entry.id,
        displayDate: entry.date,
        productName: isEntryPaymentOnly ? '' : entry.productName,
        payment: entry.payment ?? 0.0,
        price: entry.price,
        quantity: entry.quantity,
        totalAmount: entry.totalAmount,
        originalEntry: entry,
        isPaymentRow: isEntryPaymentOnly,
      ));
    }
  }
  return rows..sort((a, b) {
    // 1. Compare actual date and time chronologically (new data comes down)
    final timeCmp = a.displayDate.compareTo(b.displayDate);
    if (timeCmp != 0) return timeCmp;

    // 2. If exact same timestamp (e.g. from same entry split into delivery and payment):
    final aIsPayment = a.isPaymentRow;
    final bIsPayment = b.isPaymentRow;
    if (aIsPayment != bIsPayment) {
      return aIsPayment ? 1 : -1;
    }

    return a.id.compareTo(b.id);
  });
}

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
                tooltip: 'Record Stock or Payment',
                onPressed: () => _showAddSelectionSheet(context),
              ),
            ],
          ),
          body: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              double totalSpent = 0;
              int totalQty = 0;
              double totalPaid = 0;
              for (final entry in entries) {
                totalSpent += entry.totalAmount;
                totalQty += entry.quantity;
                totalPaid += entry.payment ?? 0.0;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FinancialSummaryCard(
                      totalSpent: totalSpent,
                      totalQty: totalQty,
                      totalPaid: totalPaid,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionButtons(
                      onAddStock: () => _showAddEntrySheet(context, isStock: true),
                      onAddPayment: () => _showAddEntrySheet(context, isStock: false),
                    ),
                    const SizedBox(height: 16),
                    _ReceiveFeed(
                      rows: buildUiRows(entries),
                      fmt: _fmt,
                      dateFmt: _dateFmt,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      onEdit: (e) {
                        final isPayment = e.productName.trim().isEmpty ||
                            e.productName.trim().toLowerCase() == 'payment only' ||
                            (e.price == 0 && e.quantity == 0 && (e.payment ?? 0) > 0);
                        _showAddEntrySheet(context, existing: e, isStock: !isPayment);
                      },
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
              'Choose whether to record received stock or payment made',
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
              title: const Text('Add Received Stock (IN)', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
              subtitle: const Text('Record fabric or stock received into inventory', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEntrySheet(context, isStock: true);
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
              subtitle: const Text('Record payment made to supplier / vendor', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEntrySheet(context, isStock: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEntrySheet(BuildContext context, {ReceiveEntry? existing, bool isStock = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveEntrySheet(
        existing: existing,
        initialIsStock: isStock,
      ),
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
              entry.productName.trim().isEmpty ? 'Payment Only' : entry.productName,
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
              0: const pw.FixedColumnWidth(100), // Date
              1: const pw.FlexColumnWidth(2.5), // Product
              2: const pw.FlexColumnWidth(1.2), // Unit Price
              3: const pw.FlexColumnWidth(1.0), // Quantity
              4: const pw.FlexColumnWidth(1.5), // Total Amount
              5: const pw.FlexColumnWidth(1.5), // Paid
              6: const pw.FlexColumnWidth(1.5), // Balance
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Product Name'),
                  hCell('Price (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Qty', alignment: pw.Alignment.center),
                  hCell('Total Value', alignment: pw.Alignment.centerRight),
                  hCell('Paid (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Balance (₦)', alignment: pw.Alignment.centerRight),
                ],
              ),
              pw.TableRow(
                children: [
                  dCell(dateFmt.format(entry.date)),
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: pw.Text(
                      entry.productName.trim().isEmpty ? 'Payment Only' : entry.productName,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  dCell(
                    entry.price == 0.0
                        ? (entry.description?.trim().isNotEmpty == true ? entry.description!.trim() : '—')
                        : (entry.description?.trim().isNotEmpty == true
                            ? '${PdfTheme.naira}${fmt.format(entry.price)}\n${entry.description!.trim()}'
                            : '${PdfTheme.naira}${fmt.format(entry.price)}'),
                    alignment: pw.Alignment.centerRight,
                  ),
                  dCell(entry.quantity == 0 ? '—' : '${entry.quantity}', alignment: pw.Alignment.center),
                  dCell('${PdfTheme.naira}${fmt.format(entry.totalAmount)}', bold: true, alignment: pw.Alignment.centerRight),
                  dCell('${PdfTheme.naira}${fmt.format(entry.payment ?? 0.0)}', alignment: pw.Alignment.centerRight),
                  dCell('${PdfTheme.naira}${fmt.format(entry.totalAmount - (entry.payment ?? 0.0))}', alignment: pw.Alignment.centerRight),
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
                                    entry.productName.trim().isEmpty ? 'Payment Only' : entry.productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (entry.description != null && entry.description!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.description!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid: ₦${fmt.format(entry.payment ?? 0.0)} • Bal: ₦${fmt.format(entry.totalAmount - (entry.payment ?? 0.0))}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (entry.price > 0 && entry.quantity > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${fmt.format(entry.price)} × ${entry.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
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
      if (!mounted) return;
      await FileSaver.saveImageBytes(
        context,
        byteData.buffer.asUint8List(),
        'stock_in_${entry.id.substring(0, 6)}.png',
      );
    } finally {
      overlay.remove();
    }
  }

  Future<void> _exportPdf(List<ReceiveEntry> entries, NumberFormat fmt, DateFormat dateFmt) async {
    final pdf = pw.Document(theme: await PdfTheme.load());
    final auth = ref.read(authProvider);
    final shopName = auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName;

    final rows = buildUiRows(entries);

    // Compute running balance: stock IN adds debt, payments OUT reduce it
    double runningBalance = 0;
    final balances = <double>[];
    for (final row in rows) {
      if (row.isPaymentRow) {
        runningBalance -= row.payment;
      } else {
        runningBalance += row.totalAmount;
        runningBalance -= row.payment; // same-day payment
      }
      balances.add(runningBalance);
    }


    pw.Widget hCell(String t, {pw.Alignment alignment = pw.Alignment.center}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );

    pw.Widget dCell(String t, {pw.Alignment alignment = pw.Alignment.centerLeft, bool bold = false, PdfColor? color, pw.Widget? child}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: child ?? pw.Text(t,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Stock Inward Ledger Report', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),  // S/N
            1: const pw.FixedColumnWidth(100), // Date
            2: const pw.FlexColumnWidth(2.5),  // IN (product)
            3: const pw.FlexColumnWidth(1.5),  // OUT (payment)
            4: const pw.FlexColumnWidth(1.2),  // Price
            5: const pw.FixedColumnWidth(40),  // Qty
            6: const pw.FlexColumnWidth(1.5),  // Total Amount
            7: const pw.FlexColumnWidth(1.5),  // Total Balance
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                hCell('S/N', alignment: pw.Alignment.center),
                hCell('Date', alignment: pw.Alignment.centerLeft),
                hCell('IN', alignment: pw.Alignment.centerLeft),
                hCell('OUT', alignment: pw.Alignment.centerRight),
                hCell('Price', alignment: pw.Alignment.centerRight),
                hCell('Qty', alignment: pw.Alignment.center),
                hCell('Total Amount', alignment: pw.Alignment.centerRight),
                hCell('Total Balance', alignment: pw.Alignment.centerRight),
              ],
            ),
            // Data rows
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final row = e.value;
              final bal = balances[i];
              final isEven = i.isEven;
              final rowDecoration = isEven
                  ? null
                  : const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC));

              // Payment-only = either a split payment row OR an entry with empty product name
              final isPaymentOnly = row.originalEntry.productName.trim().isEmpty ||
                  row.originalEntry.productName.trim().toLowerCase() == 'payment only' ||
                  row.productName.trim().toLowerCase() == 'payment only' ||
                  (row.price == 0 && row.quantity == 0);
              final isPayment = row.isPaymentRow || isPaymentOnly;

              // IN column: product name only for stock delivery rows
              final inText = isPayment ? '' : row.productName;

              // OUT column: payment amount for all payment rows
              final outText = row.payment > 0
                  ? '${PdfTheme.naira}${fmt.format(row.payment)}'
                  : '';

              // Price column:
              //   - Payment rows → description (e.g. "DIAMOND BANK")
              //   - Stock rows   → price amount
              final priceText = isPayment
                  ? (row.originalEntry.description?.trim() ?? '')
                  : (row.price == 0.0 ? '' : '${PdfTheme.naira}${fmt.format(row.price)}');

              // Total Amount:
              //   - Payment rows → same as OUT (the payment amount)
              //   - Stock rows   → price × qty
              final totalText = isPayment
                  ? (row.payment > 0 ? '${PdfTheme.naira}${fmt.format(row.payment)}' : '')
                  : (row.totalAmount > 0 ? '${PdfTheme.naira}${fmt.format(row.totalAmount)}' : '');

              return pw.TableRow(
                decoration: rowDecoration,
                children: [
                  dCell('${i + 1}', alignment: pw.Alignment.center),
                  dCell(dateFmt.format(row.displayDate)),
                  // IN cell — product name only (no description here anymore)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (inText.isNotEmpty)
                          pw.Text(inText, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  // OUT column
                  dCell(
                    outText,
                    alignment: pw.Alignment.centerRight,
                    color: outText.isNotEmpty ? PdfColors.blue800 : null,
                    child: isPayment
                        ? pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Payment Only', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                              if (outText.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(outText, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                              ],
                            ],
                          )
                        : null,
                  ),
                  // Price column: description for payments, price amount for stock
                  dCell(priceText,
                    alignment: isPayment ? pw.Alignment.centerLeft : pw.Alignment.centerRight),
                  // Qty column: only for stock rows
                  dCell(isPayment || row.quantity == 0 ? '' : '${row.quantity}',
                    alignment: pw.Alignment.center),
                  // Total Amount
                  dCell(totalText, alignment: pw.Alignment.centerRight, bold: totalText.isNotEmpty),
                  // Total Balance (running)
                  dCell('${PdfTheme.naira}${fmt.format(bal)}',
                    alignment: pw.Alignment.centerRight,
                    bold: true,
                    color: bal <= 0 ? PdfColors.green800 : PdfColors.red800),
                ],
              );
            }),
          ],
        ),
      ],
    ));
    final pdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'received_stock.pdf', pdfBytes);
  }

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

    final rows = buildUiRows(entries);

    // Compute running balance
    double runningBal = 0;
    final List<double> runningBalances = [];
    for (final row in rows) {
      if (row.isPaymentRow) {
        runningBal -= row.payment;
      } else {
        runningBal += row.totalAmount;
        runningBal -= row.payment;
      }
      runningBalances.add(runningBal);
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
                            children: ['S/N', 'Date', 'IN', 'OUT', 'Price', 'Qty', 'Total Amount', 'Total Balance']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
                                    ))
                                .toList(),
                          ),
                          ...rows.asMap().entries.map((e) {
                            final i = e.key;
                            final row = e.value;
                            final bal = runningBalances[i];
                            final rowBg = i.isEven ? bg : (isDark ? const Color(0xFF1A2535) : const Color(0xFFF8FAFC));
                            final isPaymentOnly = row.originalEntry.productName.trim().isEmpty ||
                                row.originalEntry.productName.trim().toLowerCase() == 'payment only' ||
                                row.productName.trim().toLowerCase() == 'payment only' ||
                                (row.price == 0 && row.quantity == 0);
                            final isPayment = row.isPaymentRow || isPaymentOnly;

                            final inText = isPayment ? '' : row.productName;
                            final outStr = row.payment == 0.0 ? '' : '\u20a6${fmt.format(row.payment)}';
                            final balColor = bal <= 0 ? AppTheme.successColor : AppTheme.errorColor;

                            final priceStr = isPayment
                                ? (row.originalEntry.description?.trim() ?? '')
                                : (row.price == 0.0 ? '' : '\u20a6${fmt.format(row.price)}');

                            final totalAmtStr = isPayment
                                ? (row.payment > 0 ? '\u20a6${fmt.format(row.payment)}' : '')
                                : (row.totalAmount > 0 ? '\u20a6${fmt.format(row.totalAmount)}' : '');

                            return TableRow(
                              decoration: BoxDecoration(color: rowBg),
                              children: [
                                _tCell('${i + 1}', mutedColor),
                                _tCell(dateFmt.format(row.displayDate), mutedColor, size: 9),
                                // IN column
                                Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       if (inText.isNotEmpty)
                                         Text(
                                           inText,
                                           style: TextStyle(
                                             fontSize: 10,
                                             fontWeight: FontWeight.bold,
                                             color: textColor,
                                           ),
                                         ),
                                     ],
                                   ),
                                 ),
                                // OUT column
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  child: isPayment
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Payment Only',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            if (outStr.isNotEmpty)
                                              Text(
                                                outStr,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                          ],
                                        )
                                      : Text(
                                          outStr,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w400),
                                        ),
                                ),
                                // Price column
                                _tCell(priceStr, textColor),
                                // Qty column
                                _tCell(isPayment || row.quantity == 0 ? '' : '${row.quantity}', textColor),
                                // Total Amount
                                _tCell(totalAmtStr, AppTheme.successColor, bold: totalAmtStr.isNotEmpty),
                                // Total Balance
                                _tCell('\u20a6${fmt.format(bal)}', balColor, bold: true),
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
      if (!mounted) return;
      await FileSaver.saveImageBytes(
        context,
        byteData.buffer.asUint8List(),
        'received_stock.png',
      );
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
  final double totalPaid;
  final NumberFormat fmt;

  const _FinancialSummaryCard({
    required this.totalSpent,
    required this.totalQty,
    required this.totalPaid,
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
          buildItem('TOTAL PAID', '₦${fmt.format(totalPaid)}', const Color(0xFFF59E0B), const Color(0xFFFEF3C7), Icons.payments_rounded),
        ],
      ),
    );
  }
}

class _QuickActionButtons extends StatelessWidget {
  final VoidCallback onAddStock;
  final VoidCallback onAddPayment;

  const _QuickActionButtons({
    required this.onAddStock,
    required this.onAddPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onAddStock,
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
                    'Add Stock (IN)',
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

class _ReceiveFeed extends StatelessWidget {
  final List<ReceiveUiRow> rows;
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
    required this.rows,
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
    Widget? child,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 48),
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
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showRowActionMenu(BuildContext context, ReceiveEntry entry) {
    final isPaymentOnly = entry.productName.trim().isEmpty ||
        entry.productName.trim().toLowerCase() == 'payment only' ||
        (entry.price == 0 && entry.quantity == 0 && (entry.payment ?? 0) > 0);
    final accentColor = isPaymentOnly ? AppTheme.primaryColor : const Color(0xFF10B981);
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
                      isPaymentOnly ? Icons.payment_rounded : Icons.arrow_circle_down_rounded,
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
                          isPaymentOnly ? 'Payment Only' : entry.productName,
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
                          'Paid: ₦${fmt.format(entry.payment ?? 0.0)} • Bal: ₦${fmt.format(entry.totalAmount - (entry.payment ?? 0.0))} • $dateStr',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.description != null && entry.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isPaymentOnly
                            ? '₦${fmt.format(entry.payment ?? 0.0)}'
                            : '₦${fmt.format(entry.totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isPaymentOnly ? AppTheme.primaryColor : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPaymentOnly ? 'PAYMENT (OUT)' : 'STOCK IN',
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

    // Build running balance list
    double runningBal = 0;
    final List<double> runningBalances = [];
    for (final row in rows) {
      if (row.isPaymentRow) {
        runningBal -= row.payment;
      } else {
        runningBal += row.totalAmount;
        runningBal -= row.payment;
      }
      runningBalances.add(runningBal);
    }

    const double dateWidth = 80;
    const double productWidth = 160;
    const double outWidth = 100;   // OUT (payments)
    const double priceWidth = 90;
    const double qtyWidth = 50;
    const double totalWidth = 100; // Total Amount
    const double balWidth = 110;   // Total Balance (running)
    const double totalTableWidth = dateWidth + productWidth + outWidth + priceWidth + qtyWidth + totalWidth + balWidth;

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
                '${rows.length} ${rows.length == 1 ? 'Row' : 'Rows'}',
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
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeaderCell('Date', width: dateWidth),
                            _buildHeaderCell('IN', width: productWidth),
                            _buildHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                            _buildHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                            _buildHeaderCell('OUT (₦)', width: outWidth, alignment: Alignment.centerRight),
                            _buildHeaderCell('Total Amount (₦)', width: totalWidth, alignment: Alignment.centerRight),
                            _buildHeaderCell('Total Balance (₦)', width: balWidth, alignment: Alignment.centerRight, showRightDivider: false),
                          ],
                        ),
                      ),
                    ),
                    if (rows.isEmpty)
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
                        children: List.generate(rows.length, (index) {
                          final row = rows[index];
                          final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                          final bal = runningBalances[index];

                          final dateStr = DateFormat('dd/MM/yy HH:mm').format(row.displayDate);
                          final isPayment = row.isPaymentRow ||
                              row.originalEntry.productName.trim().isEmpty ||
                              row.originalEntry.productName.trim().toLowerCase() == 'payment only' ||
                              row.productName.trim().toLowerCase() == 'payment only' ||
                              (row.price == 0 && row.quantity == 0);

                          // IN: product name for delivery rows; blank for payment-only rows
                          final inText = isPayment ? '' : row.productName;
                          final hasDesc = row.originalEntry.description != null &&
                              row.originalEntry.description!.trim().isNotEmpty;
                          final descStr = hasDesc ? row.originalEntry.description!.trim() : '';
                          final priceStr = isPayment
                              ? descStr
                              : (row.price == 0.0
                                  ? descStr
                                  : (hasDesc ? '${fmt.format(row.price)}\n$descStr' : fmt.format(row.price)));
                          final qtyStr = isPayment || row.quantity == 0 ? '' : row.quantity.toString();
                          final totalStr = isPayment || row.totalAmount == 0.0 ? '' : '₦${fmt.format(row.totalAmount)}';
                          // OUT: payment made
                          final outStr = row.payment == 0.0 ? '' : '₦${fmt.format(row.payment)}';
                          final balStr = '₦${fmt.format(bal)}';
                          final balColor = bal <= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626);

                          return Material(
                            color: rowBgColor,
                            child: InkWell(
                              onTap: () => _showRowActionMenu(context, row.originalEntry),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: accentColor, width: 4),
                                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildCell(dateStr, width: dateWidth, fontSize: 9),
                                      Container(
                                        width: productWidth,
                                        constraints: const BoxConstraints(minHeight: 48),
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (inText.isNotEmpty)
                                              Text(
                                                inText,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      _buildCell(qtyStr, width: qtyWidth, alignment: Alignment.center),
                                      _buildCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                      _buildCell(
                                        outStr,
                                        width: outWidth,
                                        alignment: Alignment.centerRight,
                                        textColor: outStr.isNotEmpty ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                                        child: isPayment
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'Payment Only',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                  if (outStr.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      outStr,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppTheme.primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              )
                                            : null,
                                      ),
                                      _buildCell(
                                        totalStr,
                                        width: totalWidth,
                                        bold: totalStr.isNotEmpty,
                                        alignment: Alignment.centerRight,
                                        textColor: accentColor,
                                      ),
                                      // Running balance column
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
                            ),
                          );
                        }),
                      ),
                    // end of rows
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
  final bool initialIsStock;

  const _ReceiveEntrySheet({
    this.existing,
    this.initialIsStock = true,
  });

  @override
  ConsumerState<_ReceiveEntrySheet> createState() => _ReceiveEntrySheetState();
}

class _ReceiveEntrySheetState extends ConsumerState<_ReceiveEntrySheet> {
  final _formKey = GlobalKey<FormState>();

  final _productController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _amountController = TextEditingController();
  final _outItemController = TextEditingController();
  final _outAmountController = TextEditingController();

  bool _isStock = true;
  final _numFmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      final isPayment = e.productName.trim().isEmpty ||
          e.productName.trim().toLowerCase() == 'payment only' ||
          (e.price == 0 && e.quantity == 0 && (e.payment ?? 0) > 0);
      _isStock = !isPayment;
      if (_isStock) {
        _productController.text = e.productName;
        _priceController.text = e.price > 0 ? _numFmt.format(e.price) : '';
        _qtyController.text = e.quantity > 0 ? e.quantity.toString() : '';
        _amountController.text = _numFmt.format(e.totalAmount);
      } else {
        _outItemController.text = (e.description != null && e.description!.trim().isNotEmpty && e.description != 'PAYMENT')
            ? e.description!
            : (e.productName.isNotEmpty && e.productName.toLowerCase() != 'payment only' ? e.productName : '');
        _outAmountController.text = _numFmt.format(e.payment ?? 0.0);
      }
    } else {
      _isStock = widget.initialIsStock;
    }
  }

  @override
  void dispose() {
    _productController.dispose();
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
    final notifier = ref.read(receiveNotifierProvider.notifier);

    if (widget.existing != null) {
      final e = widget.existing!;
      if (_isStock) {
        final price = CurrencyInputFormatter.parse(_priceController.text);
        final qty = int.tryParse(_qtyController.text) ?? 1;
        final total = CurrencyInputFormatter.parse(_amountController.text);
        final updated = ReceiveEntry(
          id: e.id,
          date: e.date,
          productName: _productController.text.trim(),
          companyName: e.companyName,
          price: price,
          quantity: qty,
          totalAmount: total > 0 ? total : price * qty,
          payment: e.payment ?? 0.0,
          paymentDate: e.paymentDate,
          description: e.description ?? '',
        );
        await notifier.update(updated);
      } else {
        final amount = CurrencyInputFormatter.parse(_outAmountController.text);
        final outDesc = _outItemController.text.trim();
        final updated = ReceiveEntry(
          id: e.id,
          date: e.date,
          productName: '',
          companyName: e.companyName,
          price: 0.0,
          quantity: 0,
          totalAmount: 0.0,
          payment: amount,
          paymentDate: e.paymentDate ?? DateTime.now(),
          description: outDesc.isEmpty ? 'PAYMENT' : outDesc,
        );
        await notifier.update(updated);
      }
    } else {
      if (_isStock) {
        final price = CurrencyInputFormatter.parse(_priceController.text);
        final qty = int.parse(_qtyController.text.trim());
        final total = CurrencyInputFormatter.parse(_amountController.text);
        await notifier.add(
          product: _productController.text.trim(),
          price: price,
          qty: qty,
          totalAmount: total > 0 ? total : price * qty,
          payment: 0.0,
          paymentDate: null,
          description: '',
        );
      } else {
        final amount = CurrencyInputFormatter.parse(_outAmountController.text);
        final outDesc = _outItemController.text.trim();
        await notifier.add(
          product: '',
          price: 0.0,
          qty: 0,
          totalAmount: 0.0,
          payment: amount,
          paymentDate: DateTime.now(),
          description: outDesc.isEmpty ? 'PAYMENT' : outDesc,
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
      sheetTitle = _isStock ? 'Edit Stock (IN)' : 'Edit Payment (OUT)';
    } else {
      sheetTitle = _isStock ? 'New Stock (IN)' : 'New Payment (OUT)';
    }

    final String sheetSubtitle = _isStock
        ? 'Record goods / fabric received into inventory'
        : 'Record payment made to supplier / vendor';

    final String buttonText;
    if (widget.existing != null) {
      buttonText = _isStock ? 'Update Stock' : 'Update Payment';
    } else {
      buttonText = _isStock ? 'Save Stock' : 'Save Payment';
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                sheetTitle,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                sheetSubtitle,
                style: const TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),

              // IN fields
              if (_isStock) ...[
                const Text('Product / Item Name',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _productController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(hintText: 'e.g. LIN ROMAN 150y'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selling Price (₦) *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMuted)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: const InputDecoration(hintText: '0'),
                          onChanged: (_) => _updateTotal(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Selling price is required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantity',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMuted)),
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
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                const Text('Total Amount (₦)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixText: '₦ ',
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                  ),
                ),
              ],

              // OUT fields
              if (!_isStock) ...[
                const Text('Bank / Cash Description',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _outItemController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(hintText: 'e.g. DIAMOND BANK'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const Text('Amount Paid (₦)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted)),
                const SizedBox(height: 4),
                Text('Can be partial — supplier can be paid in instalments',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.successColor.withValues(alpha: 0.8))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _outAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration:
                      const InputDecoration(hintText: '0', prefixText: '₦ '),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Required';
                    if (CurrencyInputFormatter.parse(v.trim()) <= 0) {
                      return 'Amount must be > 0';
                    }
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
                    backgroundColor: _isStock
                        ? AppTheme.primaryColor
                        : AppTheme.successColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
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
