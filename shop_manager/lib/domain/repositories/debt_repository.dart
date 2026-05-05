import '../entities/debt.dart';

abstract class DebtRepository {
  Future<List<Debt>> getAllDebts();
  Future<List<Debt>> getDebtsByCustomer(String customerId);
  Future<void> addDebt(Debt debt);
  Future<void> updateDebt(Debt debt);
  Future<void> markAsPaid(String id);
  Future<void> recordPartialPayment(String id, double amount);
  Stream<List<Debt>> watchDebts();
  Future<double> getTotalOutstanding();
}
