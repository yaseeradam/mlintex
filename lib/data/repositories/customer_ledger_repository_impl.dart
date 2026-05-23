import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import '../datasources/customer_ledger_local_datasource.dart';
import '../models/customer_ledger_model.dart';

class CustomerLedgerRepositoryImpl implements CustomerLedgerRepository {
  final CustomerLedgerLocalDataSource _ds;
  CustomerLedgerRepositoryImpl(this._ds);

  @override
  Future<List<CustomerLedgerEntry>> getEntriesForCustomer(
      String customerId) async {
    final models = await _ds.getEntriesForCustomer(customerId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Stream<List<CustomerLedgerEntry>> watchEntriesForCustomer(
      String customerId) {
    return _ds
        .watchEntriesForCustomer(customerId)
        .map((list) => list.map((m) => m.toEntity()).toList());
  }

  @override
  Future<void> addEntry(CustomerLedgerEntry entry) async {
    await _ds.saveEntry(CustomerLedgerEntryModel.fromEntity(entry));
  }

  @override
  Future<void> updateEntry(CustomerLedgerEntry entry) async {
    await _ds.saveEntry(CustomerLedgerEntryModel.fromEntity(entry));
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _ds.deleteEntry(id);
  }

  @override
  Future<void> deleteAllForCustomer(String customerId) async {
    await _ds.deleteAllForCustomer(customerId);
  }
}
