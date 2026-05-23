import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import '../../core/providers/repository_providers.dart';

List<CustomerLedgerEntry> _computeBalances(List<CustomerLedgerEntry> entries) {
  double balance = 0;
  final result = <CustomerLedgerEntry>[];
  for (final e in entries) {
    // OUT (goods given on credit) → balance increases
    // IN (payment received) → balance decreases
    if (e.outDescription != null && e.outDescription!.isNotEmpty) {
      balance += e.totalAmount;
    } else {
      balance -= e.totalAmount;
    }
    result.add(e.copyWith(totalBalance: balance));
  }
  return result;
}

final customerLedgerProvider =
    StreamProvider.family<List<CustomerLedgerEntry>, String>(
  (ref, customerId) {
    return ref
        .watch(customerLedgerRepositoryProvider)
        .watchEntriesForCustomer(customerId)
        .map(_computeBalances);
  },
);

class CustomerLedgerNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  CustomerLedgerRepository get _repo =>
      ref.read(customerLedgerRepositoryProvider);

  Future<void> addSaleEntry({
    required String customerId,
    required String itemName,
    required double price,
    required int quantity,
  }) async {
    state = const AsyncValue.loading();
    try {
      final entry = CustomerLedgerEntry(
        id: _uuid.v4(),
        customerId: customerId,
        date: DateTime.now(),
        inDescription: null,
        outDescription: itemName,
        price: price.toString(),
        quantity: quantity,
        totalAmount: price * quantity,
        totalBalance: 0, // recomputed by stream
        updatedAt: DateTime.now(),
      );
      await _repo.addEntry(entry);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addPaymentEntry({
    required String customerId,
    required String bankOrCash,
    required double amount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final entry = CustomerLedgerEntry(
        id: _uuid.v4(),
        customerId: customerId,
        date: DateTime.now(),
        inDescription: bankOrCash,
        outDescription: null,
        price: amount.toString(),
        quantity: null,
        totalAmount: amount,
        totalBalance: 0, // recomputed by stream
        updatedAt: DateTime.now(),
      );
      await _repo.addEntry(entry);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateEntry(CustomerLedgerEntry updated) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateEntry(updated.copyWith(updatedAt: DateTime.now()));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEntry(String entryId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteEntry(entryId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerLedgerNotifierProvider =
    NotifierProvider<CustomerLedgerNotifier, AsyncValue<void>>(
  CustomerLedgerNotifier.new,
);
