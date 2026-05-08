import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import '../../core/providers/repository_providers.dart';

/// Watch all ledger entries for a specific customer
final customerLedgerProvider = StreamProviderFamily<List<CustomerLedgerEntry>, String>(
  (ref, customerId) {
    return ref
        .watch(customerLedgerRepositoryProvider)
        .watchEntriesForCustomer(customerId);
  },
);

class CustomerLedgerNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  CustomerLedgerRepository get _repo =>
      ref.read(customerLedgerRepositoryProvider);

  /// Adds a new entry and recalculates the running balance.
  Future<void> addEntry({
    required String customerId,
    required DateTime date,
    String? inDescription,
    String? outDescription,
    String? price,
    int? quantity,
    required double totalAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Get current entries to compute running balance
      final existing = await _repo.getEntriesForCustomer(customerId);
      final lastBalance =
          existing.isEmpty ? 0.0 : existing.last.totalBalance;

      // Balance increases on OUT (goods given / credit), decreases on IN (payment)
      double newBalance;
      if (inDescription != null && inDescription.isNotEmpty) {
        newBalance = lastBalance - totalAmount;
      } else {
        newBalance = lastBalance + totalAmount;
      }

      final entry = CustomerLedgerEntry(
        id: _uuid.v4(),
        customerId: customerId,
        date: date,
        inDescription: inDescription?.isEmpty == true ? null : inDescription,
        outDescription:
            outDescription?.isEmpty == true ? null : outDescription,
        price: price?.isEmpty == true ? null : price,
        quantity: quantity,
        totalAmount: totalAmount,
        totalBalance: newBalance,
        updatedAt: DateTime.now(),
      );
      await _repo.addEntry(entry);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEntry(String entryId, String customerId) async {
    await _repo.deleteEntry(entryId);
    // Recalculate balances for remaining entries
    await _recalculateBalances(customerId);
  }

  Future<void> _recalculateBalances(String customerId) async {
    final entries = await _repo.getEntriesForCustomer(customerId);
    double running = 0.0;
    for (final e in entries) {
      if (e.inDescription != null && e.inDescription!.isNotEmpty) {
        running -= e.totalAmount;
      } else {
        running += e.totalAmount;
      }
      await _repo.updateEntry(e.copyWith(totalBalance: running));
    }
  }
}

final customerLedgerNotifierProvider =
    NotifierProvider<CustomerLedgerNotifier, AsyncValue<void>>(
  CustomerLedgerNotifier.new,
);
