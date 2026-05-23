import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../datasources/debt_local_datasource.dart';
import '../models/debt_model.dart';

class DebtRepositoryImpl implements DebtRepository {
  final DebtLocalDataSource _localDataSource;

  DebtRepositoryImpl(this._localDataSource);

  @override
  Future<List<Debt>> getAllDebts() async {
    final models = await _localDataSource.getAllDebts();
    return models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<List<Debt>> getDebtsByCustomer(String customerId) async {
    final models = await _localDataSource.getDebtsByCustomer(customerId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> addDebt(Debt debt) async {
    await _localDataSource.saveDebt(DebtModel.fromEntity(debt));
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    await _localDataSource.saveDebt(
      DebtModel.fromEntity(
        debt.copyWith(updatedAt: DateTime.now(), isSynced: false),
      ),
    );
  }

  @override
  Future<void> markAsPaid(String id) async {
    final models = await _localDataSource.getAllDebts();
    final debt = models.firstWhere((d) => d.id == id);
    await _localDataSource.saveDebt(
      DebtModel(
        id: debt.id,
        customerId: debt.customerId,
        customerName: debt.customerName,
        amount: debt.amount,
        paidAmount: debt.amount,
        dueDate: debt.dueDate,
        note: debt.note,
        isPaid: true,
        updatedAt: DateTime.now(),
        isSynced: false,
      ),
    );
  }

  @override
  Future<void> recordPartialPayment(String id, double amount) async {
    final models = await _localDataSource.getAllDebts();
    final debt = models.firstWhere((d) => d.id == id);
    final newPaid = debt.paidAmount + amount;
    await _localDataSource.saveDebt(
      DebtModel(
        id: debt.id,
        customerId: debt.customerId,
        customerName: debt.customerName,
        amount: debt.amount,
        paidAmount: newPaid,
        dueDate: debt.dueDate,
        note: debt.note,
        isPaid: newPaid >= debt.amount,
        updatedAt: DateTime.now(),
        isSynced: false,
      ),
    );
  }

  @override
  Stream<List<Debt>> watchDebts() {
    return _localDataSource.watchDebts().map(
      (models) => models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
    );
  }

  @override
  Future<double> getTotalOutstanding() async {
    final debts = await getAllDebts();
    return debts.where((d) => !d.isPaid).fold<double>(0.0, (sum, d) => sum + d.remainingAmount);
  }
}
