import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../core/providers/auth_provider.dart';

final customerLedgerBoxProvider = Provider<Box<LedgerEntry>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  return Hive.box<LedgerEntry>('ledger_entries_$shopId');
});

final shopLedgerBoxProvider = Provider<Box<LedgerEntry>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  return Hive.box<LedgerEntry>('shop_ledger_entries_$shopId');
});

// --- Customer Ledger ---
final customerLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) async* {
  final box = ref.watch(customerLedgerBoxProvider);
  yield _entriesFor(box, customerId);
  await for (final _ in box.watch()) {
    yield _entriesFor(box, customerId);
  }
});

final customerLedgerBalancesProvider = StreamProvider<Map<String, double>>((ref) async* {
  final box = ref.watch(customerLedgerBoxProvider);

  Map<String, double> calculateBalances() {
    final balances = <String, double>{};
    for (final entry in box.values) {
      final cid = entry.customerId;
      final amount = entry.totalAmount;
      final isSale = entry.type == LedgerEntryType.sale;

      balances[cid] = (balances[cid] ?? 0.0) + (isSale ? amount : -amount);
    }
    return balances;
  }

  yield calculateBalances();

  await for (final _ in box.watch()) {
    yield calculateBalances();
  }
});

// --- Shop Ledger ---
final shopLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) async* {
  final box = ref.watch(shopLedgerBoxProvider);
  yield _entriesFor(box, customerId);
  await for (final _ in box.watch()) {
    yield _entriesFor(box, customerId);
  }
});

final shopLedgerBalancesProvider = StreamProvider<Map<String, double>>((ref) async* {
  final box = ref.watch(shopLedgerBoxProvider);

  Map<String, double> calculateBalances() {
    final balances = <String, double>{};
    for (final entry in box.values) {
      final cid = entry.customerId;
      final amount = entry.totalAmount;
      final isSale = entry.type == LedgerEntryType.sale;

      balances[cid] = (balances[cid] ?? 0.0) + (isSale ? amount : -amount);
    }
    return balances;
  }

  yield calculateBalances();

  await for (final _ in box.watch()) {
    yield calculateBalances();
  }
});

List<LedgerEntry> _entriesFor(Box<LedgerEntry> box, String customerId) {
  final entries = box.values
      .where((e) => e.customerId == customerId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (final e in entries) {
    if (e.type == LedgerEntryType.sale) {
      balance += e.totalAmount;
    } else {
      balance -= e.totalAmount;
    }
    e.runningBalance = balance;
  }
  return entries;
}

class CustomerLedgerNotifier extends Notifier<void> {
  @override
  void build() {}

  Box<LedgerEntry> get _box => ref.read(customerLedgerBoxProvider);
  final _uuid = const Uuid();

  Future<void> addSaleEntry({
    required String customerId,
    required String itemName,
    required double price,
    required int quantity,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: itemName,
      price: price,
      quantity: quantity,
      totalAmount: price * quantity,
      typeIndex: LedgerEntryType.sale.index,
    );
    await _box.put(entry.id, entry);
  }

  Future<void> addPaymentEntry({
    required String customerId,
    required String bankOrCash,
    required double amount,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: null,
      outItem: bankOrCash,
      price: amount,
      quantity: null,
      totalAmount: amount,
      typeIndex: LedgerEntryType.payment.index,
    );
    await _box.put(entry.id, entry);
  }

  Future<void> updateEntry(LedgerEntry updated) async {
    await _box.put(updated.id, updated);
  }

  Future<void> deleteEntry(String id) async {
    await _box.delete(id);
  }
}

final customerLedgerNotifierProvider =
    NotifierProvider<CustomerLedgerNotifier, void>(CustomerLedgerNotifier.new);

class ShopLedgerNotifier extends Notifier<void> {
  @override
  void build() {}

  Box<LedgerEntry> get _box => ref.read(shopLedgerBoxProvider);
  final _uuid = const Uuid();

  Future<void> addSaleEntry({
    required String customerId,
    required String itemName,
    required double price,
    required int quantity,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: itemName,
      price: price,
      quantity: quantity,
      totalAmount: price * quantity,
      typeIndex: LedgerEntryType.sale.index,
    );
    await _box.put(entry.id, entry);
  }

  Future<void> addPaymentEntry({
    required String customerId,
    required String bankOrCash,
    required double amount,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: null,
      outItem: bankOrCash,
      price: amount,
      quantity: null,
      totalAmount: amount,
      typeIndex: LedgerEntryType.payment.index,
    );
    await _box.put(entry.id, entry);
  }

  Future<void> updateEntry(LedgerEntry updated) async {
    await _box.put(updated.id, updated);
  }

  Future<void> deleteEntry(String id) async {
    await _box.delete(id);
  }
}

final shopLedgerNotifierProvider =
    NotifierProvider<ShopLedgerNotifier, void>(ShopLedgerNotifier.new);
