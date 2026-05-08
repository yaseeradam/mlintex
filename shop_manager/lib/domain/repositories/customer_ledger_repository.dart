import '../entities/customer_ledger_entry.dart';

abstract class CustomerLedgerRepository {
  Future<List<CustomerLedgerEntry>> getEntriesForCustomer(String customerId);
  Stream<List<CustomerLedgerEntry>> watchEntriesForCustomer(String customerId);
  Future<void> addEntry(CustomerLedgerEntry entry);
  Future<void> updateEntry(CustomerLedgerEntry entry);
  Future<void> deleteEntry(String id);
  Future<void> deleteAllForCustomer(String customerId);
}
