import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../analytics/weekly_sales_screen.dart';
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
import '../../core/providers/repository_providers.dart';
import '../../domain/entities/product.dart';
import '../products/product_provider.dart';
import '../../core/services/pending_sync_tracker.dart';
import '../../core/services/firestore_service.dart';

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
  @HiveField(9) final String? personName;
  @HiveField(10) final double? payment;
  @HiveField(11) final DateTime? paymentDate;
  @HiveField(12) final double? costPrice;

  SalesLedgerEntry({
    required this.id, required this.date,
    this.inItem, this.outItem, this.price, this.quantity,
    required this.totalAmount, this.runningBalance = 0, required this.typeIndex,
    this.personName,
    this.payment = 0.0,
    this.paymentDate,
    this.costPrice,
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
      personName: f[9] as String?,
      payment: (f[10] as num?)?.toDouble() ?? 0.0,
      paymentDate: f[11] as DateTime?,
      costPrice: (f[12] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, SalesLedgerEntry obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.date)
      ..writeByte(2)..write(obj.inItem)
      ..writeByte(3)..write(obj.outItem)
      ..writeByte(4)..write(obj.price)
      ..writeByte(5)..write(obj.quantity)
      ..writeByte(6)..write(obj.totalAmount)
      ..writeByte(7)..write(obj.runningBalance)
      ..writeByte(8)..write(obj.typeIndex)
      ..writeByte(9)..write(obj.personName)
      ..writeByte(10)..write(obj.payment)
      ..writeByte(11)..write(obj.paymentDate)
      ..writeByte(12)..write(obj.costPrice);
  }

  @override bool operator ==(Object other) => identical(this, other) || other is SalesLedgerEntryAdapter && typeId == other.typeId;
  @override int get hashCode => typeId.hashCode;
}

// ── Provider ───────────────────────────────────────────────────────────────

SalesLedgerEntry _fromSalesLedgerMap(Map<String, dynamic> map) {
  final rawPrice = map['price'];
  final price = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '');

  final rawQty = map['quantity'];
  final quantity = (rawQty is num) ? rawQty.toInt() : int.tryParse(rawQty?.toString() ?? '');

  final rawTotal = map['totalAmount'];
  final totalAmount = (rawTotal is num) ? rawTotal.toDouble() : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0);

  final rawBal = map['runningBalance'];
  final runningBalance = (rawBal is num) ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '') ?? 0.0);

  final rawType = map['typeIndex'];
  final typeIndex = (rawType is num) ? rawType.toInt() : (int.tryParse(rawType?.toString() ?? '') ?? 1);

  final rawPay = map['payment'];
  final payment = (rawPay is num) ? rawPay.toDouble() : double.tryParse(rawPay?.toString() ?? '');

  final rawCost = map['costPrice'];
  final costPrice = (rawCost is num) ? rawCost.toDouble() : double.tryParse(rawCost?.toString() ?? '');

  return SalesLedgerEntry(
    id: map['id']?.toString() ?? '',
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    inItem: map['inItem']?.toString(),
    outItem: map['outItem']?.toString(),
    price: price,
    quantity: quantity,
    totalAmount: totalAmount,
    runningBalance: runningBalance,
    typeIndex: typeIndex,
    personName: map['personName']?.toString(),
    payment: payment,
    paymentDate: map['paymentDate'] != null ? DateTime.tryParse(map['paymentDate'].toString()) : null,
    costPrice: costPrice,
  );
}

Map<String, dynamic> _toSalesLedgerMap(SalesLedgerEntry e, String shopId) {
  return {
    'id': e.id,
    'date': e.date.toIso8601String(),
    'inItem': e.inItem,
    'outItem': e.outItem,
    'price': e.price,
    'quantity': e.quantity,
    'totalAmount': e.totalAmount,
    'runningBalance': e.runningBalance,
    'typeIndex': e.typeIndex,
    'personName': e.personName,
    'payment': e.payment,
    'paymentDate': e.paymentDate?.toIso8601String(),
    'costPrice': e.costPrice,
    'shopId': shopId,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

List<SalesLedgerEntry> computeSalesLedgerBalances(List<SalesLedgerEntry> entries) {
  final list = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (final e in list) {
    if (e.typeIndex == 1) {
      balance += e.totalAmount;
      balance -= (e.payment ?? 0.0);
    } else {
      balance -= e.totalAmount;
    }
    e.runningBalance = balance;
  }
  return list;
}

final salesLedgerEntriesProvider = StreamProvider<List<SalesLedgerEntry>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  ref.watch(firebaseAuthStateProvider);
  final col = FirestoreService.userCollection('sales_ledger');

  return col.snapshots().map((snapshot) {
    final list = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final sId = data['shopId']?.toString();
          return shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
        })
        .map((doc) => _fromSalesLedgerMap(doc.data()))
        .toList();
    return computeSalesLedgerBalances(list);
  });
});

class SalesLedgerNotifier extends Notifier<void> {
  @override void build() {}

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreService.userCollection('sales_ledger');
  String get _shopId => FirestoreService.activeShopId;

  Future<void> addSale({
    required String item,
    required double price,
    required int qty,
    double payment = 0.0,
    String? paymentMethod,
    String? personName,
    String? productId,
    double? costPrice,
  }) async {
    double? resolvedCost = costPrice;
    String? targetId = productId;
    if (resolvedCost == null || targetId == null) {
      final allProds = await ref.read(productRepositoryProvider).getAllProducts();
      Product? match;
      if (targetId != null) {
        match = allProds.where((p) => p.id == targetId).firstOrNull;
      }
      if (match == null) {
        match = allProds.where((p) => p.name.trim().toLowerCase() == item.trim().toLowerCase()).firstOrNull;
        if (match != null) targetId = match.id;
      }
      if (match != null && match.costPrice > 0) {
        resolvedCost ??= match.costPrice;
      }
    }

    final e = SalesLedgerEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      inItem: item,
      outItem: paymentMethod,
      price: price,
      quantity: qty,
      totalAmount: price * qty,
      payment: payment,
      paymentDate: payment > 0 ? DateTime.now() : null,
      typeIndex: 1,
      personName: personName,
      costPrice: resolvedCost,
    );

    await _collection.doc(e.id).set(_toSalesLedgerMap(e, _shopId), SetOptions(merge: true));

    if (targetId != null) {
      await ref.read(productNotifierProvider.notifier).updateQuantity(targetId, -qty);
    }
  }

  Future<void> addPayment({required String bankOrCash, required double amount, String? personName}) async {
    final e = SalesLedgerEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      outItem: bankOrCash,
      totalAmount: amount,
      payment: amount,
      paymentDate: DateTime.now(),
      typeIndex: 0,
      personName: personName,
    );

    await _collection.doc(e.id).set(_toSalesLedgerMap(e, _shopId), SetOptions(merge: true));
  }

  Future<void> update(SalesLedgerEntry e, {String? productId}) async {
    final docRef = _collection.doc(e.id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final oldEntry = _fromSalesLedgerMap(oldDoc.data()!);
      if (oldEntry.typeIndex == 1) {
        final oldQty = oldEntry.quantity ?? 0;
        final newQty = e.quantity ?? 0;
        final diff = newQty - oldQty;
        if (diff != 0) {
          String? targetId = productId;
          if (targetId == null && e.inItem != null) {
            final allProds = await ref.read(productRepositoryProvider).getAllProducts();
            final matches = allProds.where((p) => p.name.trim().toLowerCase() == e.inItem!.trim().toLowerCase());
            if (matches.isNotEmpty) targetId = matches.first.id;
          }
          if (targetId != null) {
            await ref.read(productNotifierProvider.notifier).updateQuantity(targetId, -diff);
          }
        }
      }
    }

    await docRef.set(_toSalesLedgerMap(e, _shopId), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    final docRef = _collection.doc(id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final entry = _fromSalesLedgerMap(oldDoc.data()!);
      if (entry.typeIndex == 1) {
        final qty = entry.quantity ?? 0;
        if (qty > 0 && entry.inItem != null) {
          final allProds = await ref.read(productRepositoryProvider).getAllProducts();
          final matches = allProds.where((p) => p.name.trim().toLowerCase() == entry.inItem!.trim().toLowerCase());
          if (matches.isNotEmpty) {
            await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, qty);
          }
        }
      }
    }
    await docRef.delete();
  }
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
                icon: const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor),
                tooltip: 'Weekly Sales Analytics',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
                ),
              ),
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
              final products = ref.watch(productsProvider).value ?? [];
              final productCostByName = <String, double>{
                for (final p in products) p.name.trim().toLowerCase(): p.costPrice,
              };

              double totalIn = 0;
              double totalOut = 0;
              double totalProfit = 0;
              for (final entry in entries) {
                if (entry.typeIndex == 1) {
                  totalIn += entry.totalAmount;
                  totalOut += (entry.payment ?? 0.0);

                  final nameKey = (entry.inItem ?? '').trim().toLowerCase();
                  final cost = (entry.costPrice != null && entry.costPrice! > 0)
                      ? entry.costPrice!
                      : (productCostByName[nameKey] ?? 0.0);
                  final unitPrice = entry.price ??
                      (entry.quantity != null && entry.quantity! > 0
                          ? entry.totalAmount / entry.quantity!
                          : entry.totalAmount);
                  final qty = entry.quantity ?? 1;
                  if (cost > 0) {
                    totalProfit += (unitPrice - cost) * qty;
                  }
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
                    _FinancialSummaryCard(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      remainingDebt: remainingDebt,
                      totalProfit: totalProfit,
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
              subtitle: const Text('Record goods sold with optional payment made at purchase', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              subtitle: const Text('Record customer debt repayment without new goods', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
    pw.Widget dCell(String t, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft, pw.Widget? child}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: child ?? pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    final name = entry.personName ?? '—';
    final desc = isSale ? (entry.inItem ?? '') : (entry.outItem ?? 'PAYMENT');
    final priceStr = isSale && entry.price != null ? fmt.format(entry.price) : '—';
    final qtyStr = isSale && entry.quantity != null ? entry.quantity.toString() : '—';
    final goodsTotal = isSale ? '${PdfTheme.naira}${fmt.format(entry.totalAmount)}' : '—';
    final double outVal = isSale ? (entry.payment ?? 0.0) : entry.totalAmount;
    final paymentReceived = outVal > 0 ? fmt.format(outVal) : '—';
    final outDesc = !isSale ? (entry.outItem ?? 'PAYMENT') : (entry.outItem ?? '');

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
              0: const pw.FixedColumnWidth(80),   // Date
              1: const pw.FlexColumnWidth(1.8),  // Buyer Name
              2: const pw.FlexColumnWidth(2.0),  // Item/Desc
              3: const pw.FlexColumnWidth(1.2),  // Price (₦)
              4: const pw.FlexColumnWidth(0.8),  // Qty
              5: const pw.FlexColumnWidth(1.3),  // IN (₦)
              6: const pw.FlexColumnWidth(1.3),  // OUT (₦)
              7: const pw.FlexColumnWidth(1.5),  // Balance (₦)
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Date'),
                  hCell('Buyer Name'),
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
                  dCell(name, bold: true),
                  dCell(desc, bold: true),
                  dCell(priceStr, alignment: pw.Alignment.centerRight),
                  dCell(qtyStr, alignment: pw.Alignment.center),
                  dCell(goodsTotal, bold: isSale, alignment: pw.Alignment.centerRight),
                  dCell(
                    paymentReceived != '—' ? '' : '—',
                    bold: outVal > 0,
                    alignment: pw.Alignment.centerRight,
                    child: outVal > 0
                        ? pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              if (outDesc.isNotEmpty)
                                pw.Text(
                                  outDesc,
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
                                    isSale ? (entry.inItem ?? '') : (entry.outItem ?? 'PAYMENT'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (entry.personName != null && entry.personName!.isNotEmpty) ...[
                                    Text(
                                      'Name: ${entry.personName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (isSale) ...[
                                    Text(
                                      '₦${fmt.format(entry.price)} × ${entry.quantity} Bll',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (entry.payment != null && entry.payment! > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Paid: ₦${fmt.format(entry.payment)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
      if (!mounted) return;
      await FileSaver.saveImageBytes(
        context,
        byteData.buffer.asUint8List(),
        'sales_entry_${entry.id.substring(0, 6)}.png',
      );
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
              children: ['S/N', 'Date', 'Buyer Name', 'IN', 'OUT', 'Price', 'Qty', 'Total Amount', 'Total Balance']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...entries.asMap().entries.map((e) {
              final entry = e.value;
              final isSale = entry.typeIndex == 1;
              final double outVal = isSale ? (entry.payment ?? 0.0) : entry.totalAmount;
              final outDesc = !isSale
                  ? (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                      ? entry.outItem!.trim()
                      : 'PAYMENT')
                  : (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                      ? entry.outItem!.trim()
                      : '');
              return pw.TableRow(children: [
                _c('${e.key + 1}'),
                _c(dateFmt.format(entry.date)),
                _c(entry.personName ?? '—'),
                _c(isSale ? (entry.inItem ?? '') : ''),
                outVal > 0
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            if (outDesc.isNotEmpty)
                              pw.Text(
                                outDesc,
                                style: pw.TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              '${PdfTheme.naira}${fmt.format(outVal)}',
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _c('—'),
                _c(isSale && entry.price != null ? '${PdfTheme.naira}${fmt.format(entry.price)}' : '—'),
                _c(isSale && entry.quantity != null ? '${entry.quantity}' : '—'),
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
                            children: ['S/N', 'Date', 'Buyer Name', 'IN', 'OUT', 'Price', 'Qty', 'Total Amount', 'Total Balance']
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
                            final double outVal = isSale ? (entry.payment ?? 0.0) : entry.totalAmount;
                            final outDesc = !isSale
                                ? (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                                    ? entry.outItem!.trim()
                                    : 'PAYMENT')
                                : (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                                    ? entry.outItem!.trim()
                                    : '');
                            return TableRow(
                              decoration: BoxDecoration(color: rowBg),
                              children: [
                                _tCell('${i + 1}', mutedColor),
                                _tCell(dateFmt.format(entry.date), mutedColor, size: 9),
                                _tCell(entry.personName ?? '—', textColor, bold: true),
                                _tCell(isSale ? (entry.inItem ?? '') : '', textColor, bold: true),
                                outVal > 0
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (outDesc.isNotEmpty)
                                              Text(
                                                outDesc,
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            const SizedBox(height: 1),
                                            Text(
                                              '₦${fmt.format(outVal)}',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.successColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _tCell('—', mutedColor),
                                _tCell(isSale && entry.price != null ? '₦${fmt.format(entry.price)}' : '—', textColor),
                                _tCell(isSale && entry.quantity != null ? '${entry.quantity}' : '—', textColor),
                                _tCell('₦${fmt.format(entry.totalAmount)}', AppTheme.primaryColor, bold: true),
                                _tCell('₦${fmt.format(entry.runningBalance)}',
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
      if (!mounted) return;
      await FileSaver.saveImageBytes(
        context,
        byteData.buffer.asUint8List(),
        'sales_ledger.png',
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
  final double totalProfit;
  final NumberFormat fmt;

  const _FinancialSummaryCard({
    required this.totalIn,
    required this.totalOut,
    required this.remainingDebt,
    required this.totalProfit,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(
      String title,
      double amount,
      Color color,
      Color bgColor,
      IconData icon, {
      bool isOutstanding = false,
      bool isProfit = false,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.18), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 12, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color.withOpacity(0.9),
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isProfit && amount > 0
                      ? '+₦${fmt.format(amount)}'
                      : '₦${fmt.format(amount)}',
                  style: TextStyle(
                    fontSize: isOutstanding ? 15 : 14,
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              buildItem('TOTAL SALES', totalIn, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), Icons.receipt_long_rounded),
              const SizedBox(width: 8),
              buildItem('TOTAL PROFIT', totalProfit, const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.trending_up_rounded, isProfit: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              buildItem('TOTAL PAID', totalOut, const Color(0xFF6366F1), const Color(0xFFEEF2FF), Icons.check_circle_outline_rounded),
              const SizedBox(width: 8),
              buildItem(
                'BALANCE',
                remainingDebt,
                remainingDebt > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                remainingDebt > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                Icons.account_balance_wallet_outlined,
                isOutstanding: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text(
                    'View Weekly Sales & Profit Analytics',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          ),
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
                        if (entry.personName != null && entry.personName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            isSale ? 'Buyer: ${entry.personName!.trim()}' : 'From: ${entry.personName!.trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 1,
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


    const double buyerWidth = 110;
    const double dateWidth = 65;
    const double itemWidth = 140;
    const double qtyWidth = 40;
    const double priceWidth = 90;
    const double totalAmtWidth = 90;
    const double outWidth = 90;
    const double balWidth = 95;
    const double totalTableWidth = buyerWidth + dateWidth + itemWidth + qtyWidth + priceWidth + totalAmtWidth + outWidth + balWidth; // 720

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
                          _buildHeaderCell('Buyer Name', width: buyerWidth),
                          _buildHeaderCell('Item/Desc', width: itemWidth),
                          _buildHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                          _buildHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('OUT (₦)', width: outWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('Total Amt', width: totalAmtWidth, alignment: Alignment.centerRight),
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
                          
                          final buyerStr = entry.personName != null && entry.personName!.trim().isNotEmpty
                              ? entry.personName!.trim()
                              : '—';
                          final dateStr = DateFormat('dd/MM/yy').format(entry.date);
                          final descStr = isSale ? (entry.inItem ?? '') : '';
                          final qtyStr = isSale && entry.quantity != null ? entry.quantity.toString() : '—';
                          final priceStr = isSale && entry.price != null ? fmt.format(entry.price) : '—';
                          final totalAmtStr = fmt.format(entry.totalAmount);
                          final double paidAmount = isSale ? (entry.payment ?? 0.0) : entry.totalAmount;
                          final bool hasPaid = paidAmount > 0;
                          final outStr = hasPaid ? fmt.format(paidAmount) : '—';
                          final outDesc = !isSale
                              ? (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                                  ? entry.outItem!.trim()
                                  : 'Payment')
                              : (entry.outItem != null && entry.outItem!.trim().isNotEmpty
                                  ? entry.outItem!.trim()
                                  : '');

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
                                    _buildCell(buyerStr, width: buyerWidth, bold: true, textColor: const Color(0xFF0F172A)),
                                    _buildCell(descStr, width: itemWidth, bold: isSale),
                                    _buildCell(qtyStr, width: qtyWidth, alignment: Alignment.center),
                                    _buildCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                    _buildCell(
                                      hasPaid ? '₦$outStr' : '—',
                                      width: outWidth,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: hasPaid
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (outDesc.isNotEmpty)
                                                  Text(
                                                    outDesc,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                const SizedBox(height: 1),
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
                                      '₦$totalAmtStr',
                                      width: totalAmtWidth,
                                      bold: true,
                                      alignment: Alignment.centerRight,
                                      textColor: isSale ? const Color(0xFF1E3A8A) : const Color(0xFF10B981),
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
                        }),
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
  final _personCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _outItemCtrl = TextEditingController();
  bool _isSale = true;
  String? _selectedProductId;

  final _numFmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _isSale = e.typeIndex == 1;
      _itemCtrl.text = e.inItem ?? '';
      _outItemCtrl.text = e.outItem ?? '';
      _priceCtrl.text = e.price != null ? _numFmt.format(e.price) : '';
      _qtyCtrl.text = e.quantity?.toString() ?? '';
      _amountCtrl.text = _numFmt.format(e.totalAmount);
      _personCtrl.text = e.personName ?? '';
      final paid = _isSale ? (e.payment ?? 0.0) : e.totalAmount;
      _paymentCtrl.text = _numFmt.format(paid);
      final bal = _isSale ? (e.totalAmount - paid) : 0.0;
      _balanceCtrl.text = _numFmt.format(bal < 0 ? 0.0 : bal);
    } else {
      _isSale = widget.initialIsSale;
      _paymentCtrl.text = '0';
      _balanceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    _personCtrl.dispose();
    _paymentCtrl.dispose();
    _balanceCtrl.dispose();
    _outItemCtrl.dispose();
    super.dispose();
  }

  void _updateTotal() {
    if (_isSale) {
      final p = CurrencyInputFormatter.parse(_priceCtrl.text);
      final q = int.tryParse(_qtyCtrl.text) ?? 0;
      final total = (p > 0 && q > 0) ? (p * q) : 0.0;
      _amountCtrl.text = _numFmt.format(total);
      final paid = CurrencyInputFormatter.parse(_paymentCtrl.text);
      final bal = total - paid;
      _balanceCtrl.text = _numFmt.format(bal < 0 ? 0.0 : bal);
    }
    if (mounted) setState(() {});
  }

  void _updatePayment() {
    if (_isSale) {
      final total = CurrencyInputFormatter.parse(_amountCtrl.text);
      final paid = CurrencyInputFormatter.parse(_paymentCtrl.text);
      final bal = total - paid;
      _balanceCtrl.text = _numFmt.format(bal < 0 ? 0.0 : bal);
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final n = ref.read(salesLedgerNotifierProvider.notifier);
    final pName = _personCtrl.text.trim().isEmpty ? null : _personCtrl.text.trim();
    final paymentVal = CurrencyInputFormatter.parse(_paymentCtrl.text);
    final paymentMethod = _outItemCtrl.text.trim().isEmpty ? null : _outItemCtrl.text.trim();

    if (widget.existing != null) {
      final e = widget.existing!;
      if (_isSale) {
        final price = CurrencyInputFormatter.parse(_priceCtrl.text);
        final qty = int.tryParse(_qtyCtrl.text) ?? 0;
        final total = price * qty;
        final products = ref.read(productsProvider).value ?? [];
        Product? match;
        if (_selectedProductId != null) {
          match = products.where((p) => p.id == _selectedProductId).firstOrNull;
        }
        if (match == null && _itemCtrl.text.isNotEmpty) {
          match = products.where((p) => p.name.trim().toLowerCase() == _itemCtrl.text.trim().toLowerCase()).firstOrNull;
        }
        final cost = (match != null && match.costPrice > 0) ? match.costPrice : e.costPrice;

        await n.update(SalesLedgerEntry(
          id: e.id,
          date: e.date,
          inItem: _itemCtrl.text.trim(),
          outItem: paymentMethod,
          price: price,
          quantity: qty,
          totalAmount: total,
          payment: paymentVal,
          paymentDate: paymentVal > 0 ? (e.paymentDate ?? DateTime.now()) : null,
          typeIndex: 1,
          personName: pName,
          costPrice: cost,
        ), productId: _selectedProductId);
      } else {
        final amount = CurrencyInputFormatter.parse(_amountCtrl.text);
        await n.update(SalesLedgerEntry(
          id: e.id,
          date: e.date,
          inItem: null,
          outItem: _outItemCtrl.text.trim().isNotEmpty ? _outItemCtrl.text.trim() : _itemCtrl.text.trim(),
          price: null,
          quantity: null,
          totalAmount: amount,
          payment: amount,
          paymentDate: e.paymentDate ?? DateTime.now(),
          typeIndex: 0,
          personName: pName,
        ));
      }
    } else {
      if (_isSale) {
        final price = CurrencyInputFormatter.parse(_priceCtrl.text);
        final qty = int.parse(_qtyCtrl.text.trim());
        final products = ref.read(productsProvider).value ?? [];
        Product? match;
        if (_selectedProductId != null) {
          match = products.where((p) => p.id == _selectedProductId).firstOrNull;
        }
        if (match == null && _itemCtrl.text.isNotEmpty) {
          match = products.where((p) => p.name.trim().toLowerCase() == _itemCtrl.text.trim().toLowerCase()).firstOrNull;
        }
        final cost = (match != null && match.costPrice > 0) ? match.costPrice : null;

        await n.addSale(
          item: _itemCtrl.text.trim(),
          price: price,
          qty: qty,
          payment: paymentVal,
          paymentMethod: paymentMethod,
          personName: pName,
          productId: _selectedProductId,
          costPrice: cost,
        );
      } else {
        await n.addPayment(
          bankOrCash: _outItemCtrl.text.trim().isNotEmpty ? _outItemCtrl.text.trim() : _itemCtrl.text.trim(),
          amount: CurrencyInputFormatter.parse(_amountCtrl.text),
          personName: pName,
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
    const accentGreen = Color(0xFF10B981);
    final productsAsync = ref.watch(productsProvider);

    final totalSaleVal = CurrencyInputFormatter.parse(_amountCtrl.text);
    final paidVal = CurrencyInputFormatter.parse(_paymentCtrl.text);
    final isFullyPaid = totalSaleVal > 0 && paidVal >= totalSaleVal;

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

            // Header Row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isSale ? AppTheme.primaryColor : accentGreen).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isSale ? Icons.add_shopping_cart_rounded : Icons.payments_rounded,
                  color: _isSale ? AppTheme.primaryColor : accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existing != null
                        ? (_isSale ? 'Edit Sales Entry' : 'Edit Payment')
                        : (_isSale ? 'New Sales Entry' : 'Record Payment (OUT)'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  Text(
                    _isSale
                        ? 'Enter sale items and customer payment together'
                        : 'Record standalone customer debt repayment',
                    style: const TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            if (_isSale) ...[
              _lbl('Select Product from Store', textMuted),
              productsAsync.when(
                data: (products) {
                  if (_selectedProductId != null && !products.any((p) => p.id == _selectedProductId)) {
                    _selectedProductId = null;
                  }
                  if (_selectedProductId == null && _itemCtrl.text.isNotEmpty) {
                    final matches = products.where(
                      (p) => p.name.trim().toLowerCase() == _itemCtrl.text.trim().toLowerCase(),
                    );
                    if (matches.isNotEmpty) {
                      _selectedProductId = matches.first.id;
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedProductId,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        hint: const Text('Choose a product...', style: TextStyle(fontSize: 14, color: textMuted)),
                        isExpanded: true,
                        items: products.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(
                                  p.price > 0
                                      ? '₦${_numFmt.format(p.price)} (${p.quantity} left)'
                                      : (p.costPrice > 0
                                          ? 'Cost: ₦${_numFmt.format(p.costPrice)} (${p.quantity} left)'
                                          : '(${p.quantity} left)'),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final prod = products.firstWhere((p) => p.id == val);
                          setState(() {
                            _selectedProductId = val;
                            _itemCtrl.text = prod.name;
                            if (prod.price > 0) {
                              _priceCtrl.text = _numFmt.format(prod.price);
                            }
                            _updateTotal();
                          });
                        },
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err', style: const TextStyle(color: AppTheme.errorColor)),
              ),
              _lbl('Item Name *', textMuted),
              TextFormField(
                controller: _itemCtrl,
                decoration: const InputDecoration(hintText: 'e.g. ZENITH 150y'),
                onChanged: (val) {
                  if (_selectedProductId != null) {
                    final products = productsAsync.value ?? [];
                    final matches = products.where((p) => p.id == _selectedProductId);
                    final Product? match = matches.isNotEmpty ? matches.first : null;
                    if (match == null || match.name != val) {
                      setState(() {
                        _selectedProductId = null;
                      });
                    }
                  }
                },
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _lbl('Buyer Name *', textMuted),
              TextFormField(
                controller: _personCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. JOHN DOE'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Selling Price (₦) *', textMuted),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(hintText: '0.00', prefixText: '₦ '),
                    onChanged: (_) => _updateTotal(),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Selling price is required' : null,
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Quantity *', textMuted),
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                    onChanged: (_) => _updateTotal(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final q = int.tryParse(v);
                      if (q == null || q <= 0) return 'Must be > 0';
                      if (_selectedProductId != null) {
                        final products = productsAsync.value ?? [];
                        final matches = products.where((p) => p.id == _selectedProductId);
                        final Product? prod = matches.isNotEmpty ? matches.first : null;
                        if (prod != null) {
                          int allowedQty = prod.quantity;
                          if (widget.existing != null && widget.existing!.typeIndex == 1) {
                            allowedQty += widget.existing!.quantity ?? 0;
                          }
                          if (q > allowedQty) {
                            return 'Only $allowedQty left';
                          }
                        }
                      }
                      return null;
                    },
                  ),
                ])),
              ]),
              const SizedBox(height: 14),
              _lbl('Total Sale Amount (₦)', textMuted),
              TextFormField(
                controller: _amountCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: '0.00', prefixText: '₦ ',
                  filled: true,
                  fillColor: Color(0xFFF1F5F9),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              Builder(
                builder: (_) {
                  final products = productsAsync.value ?? [];
                  final p = CurrencyInputFormatter.parse(_priceCtrl.text);
                  final q = int.tryParse(_qtyCtrl.text) ?? 0;
                  if (p <= 0 || q <= 0) return const SizedBox.shrink();

                  Product? matched;
                  if (_selectedProductId != null) {
                    matched = products.where((item) => item.id == _selectedProductId).firstOrNull;
                  } else if (_itemCtrl.text.isNotEmpty) {
                    matched = products.where((item) => item.name.trim().toLowerCase() == _itemCtrl.text.trim().toLowerCase()).firstOrNull;
                  }

                  final cost = (matched != null && matched.costPrice > 0)
                      ? matched.costPrice
                      : ((widget.existing?.costPrice != null && widget.existing!.costPrice! > 0)
                          ? widget.existing!.costPrice!
                          : 0.0);

                  if (cost <= 0) {
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cost price not set in inventory (profit uncalculated)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final unitProfit = p - cost;
                  final estProfit = unitProfit * q;
                  final isPositive = estProfit >= 0;

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPositive
                            ? const Color(0xFF10B981).withOpacity(0.25)
                            : const Color(0xFFEF4444).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 14,
                            color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPositive
                              ? 'Estimated Profit: +₦${_numFmt.format(estProfit)}'
                              : 'Estimated Loss: -₦${_numFmt.format(estProfit.abs())}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Cost: ₦${_numFmt.format(cost)}/ea',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // ── Payment (OUT) & Balance Card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentGreen.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.payments_rounded, size: 16, color: accentGreen),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Payment (OUT)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFullyPaid
                                ? accentGreen.withOpacity(0.12)
                                : (paidVal > 0
                                    ? const Color(0xFFF59E0B).withOpacity(0.12)
                                    : const Color(0xFFEF4444).withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isFullyPaid
                                ? '✓ Fully Paid'
                                : (paidVal > 0 ? 'Partial Payment' : 'Unpaid / Debt'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isFullyPaid
                                  ? accentGreen
                                  : (paidVal > 0 ? const Color(0xFFD97706) : const Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _lbl('Payment Made (₦)', textMuted),
                              TextFormField(
                                controller: _paymentCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₦ ',
                                  filled: true,
                                  fillColor: accentGreen.withOpacity(0.06),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: accentGreen, width: 1.5),
                                  ),
                                ),
                                onChanged: (_) => _updatePayment(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _lbl('Balance Due (₦)', textMuted),
                              TextFormField(
                                controller: _balanceCtrl,
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₦ ',
                                  filled: true,
                                  fillColor: isFullyPaid
                                      ? accentGreen.withOpacity(0.06)
                                      : const Color(0xFFEF4444).withOpacity(0.06),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isFullyPaid
                                          ? accentGreen.withOpacity(0.3)
                                          : const Color(0xFFEF4444).withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _lbl('Payment Method / Account (optional)', textMuted),
                    TextFormField(
                      controller: _outItemCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Cash, Access Bank, Transfer',
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _lbl('Customer / Buyer Name *', textMuted),
              TextFormField(
                controller: _personCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. JOHN DOE'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _lbl('Bank / Cash (Account) *', textMuted),
              TextFormField(
                controller: _outItemCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. ACCESS BANK or CASH'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _lbl('Payment Amount (₦) *', textMuted),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  hintText: '0.00', prefixText: '₦ ',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSale ? AppTheme.primaryColor : accentGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.existing != null
                      ? (_isSale ? 'Update Sale' : 'Update Payment')
                      : (_isSale ? 'Save Sales Entry' : 'Save Payment'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
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
