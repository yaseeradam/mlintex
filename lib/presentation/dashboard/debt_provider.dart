import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../core/providers/repository_providers.dart';

final debtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(debtRepositoryProvider).watchDebts();
});

final totalOutstandingProvider = FutureProvider<double>((ref) {
  return ref.watch(debtRepositoryProvider).getTotalOutstanding();
});

final overdueDebtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(debtRepositoryProvider).watchDebts().map(
        (debts) => debts.where((d) => d.isOverdue && !d.isPaid).toList(),
      );
});

class DebtNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  DebtRepository get _repo => ref.read(debtRepositoryProvider);

  Future<void> addDebt({
    required String customerId,
    required String customerName,
    required double amount,
    required DateTime dueDate,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final debt = Debt(
        id: _uuid.v4(),
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        dueDate: dueDate,
        note: note,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await _repo.addDebt(debt);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsPaid(String id) async {
    await _repo.markAsPaid(id);
  }

  Future<void> recordPayment(String id, double amount) async {
    await _repo.recordPartialPayment(id, amount);
  }
}

final debtNotifierProvider = NotifierProvider<DebtNotifier, AsyncValue<void>>(
  DebtNotifier.new,
);
