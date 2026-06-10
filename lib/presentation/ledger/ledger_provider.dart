import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../core/providers/auth_provider.dart';

const _boxName = 'ledger_entries';

final ledgerBoxProvider = Provider<Box<LedgerEntry>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  return Hive.box<LedgerEntry>('${_boxName}_$shopId');
});

final customerLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) async* {
  final box = ref.watch(ledgerBoxProvider);
  yield _entriesFor(box, customerId);
  await for (final _ in box.watch()) {
    yield _entriesFor(box, customerId);
  }
});

List<LedgerEntry> _entriesFor(Box<LedgerEntry> box, String customerId) {
  final entries = box.values
      .where((e) => e.customerId == customerId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (final e in entries) {
    // IN (sale) = customer owes more → balance increases
    // OUT (payment) = customer paid → balance decreases
    if (e.type == LedgerEntryType.sale) {
      balance += e.totalAmount;
    } else {
      balance -= e.totalAmount;
    }
    e.runningBalance = balance;
  }
  return entries;
}

class LedgerNotifier extends Notifier<void> {
  @override
  void build() {}

  Box<LedgerEntry> get _box => ref.read(ledgerBoxProvider);
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

final ledgerNotifierProvider =
    NotifierProvider<LedgerNotifier, void>(LedgerNotifier.new);
