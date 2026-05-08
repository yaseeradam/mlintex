import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer_ledger_model.dart';

class CustomerLedgerLocalDataSource {
  static const String _boxName = 'customer_ledger';

  Future<Box> get _box async => Hive.openBox(_boxName);

  Future<List<CustomerLedgerEntryModel>> getEntriesForCustomer(
      String customerId) async {
    final box = await _box;
    return box.values
        .map((e) => CustomerLedgerEntryModel.fromMap(e as Map))
        .where((e) => e.customerId == customerId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> saveEntry(CustomerLedgerEntryModel entry) async {
    final box = await _box;
    await box.put(entry.id, entry.toMap());
  }

  Future<void> deleteEntry(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Future<void> deleteAllForCustomer(String customerId) async {
    final box = await _box;
    final keys = box.values
        .map((e) => CustomerLedgerEntryModel.fromMap(e as Map))
        .where((e) => e.customerId == customerId)
        .map((e) => e.id)
        .toList();
    await box.deleteAll(keys);
  }

  Stream<List<CustomerLedgerEntryModel>> watchEntriesForCustomer(
      String customerId) async* {
    final box = await _box;
    List<CustomerLedgerEntryModel> parse() => box.values
        .map((e) => CustomerLedgerEntryModel.fromMap(e as Map))
        .where((e) => e.customerId == customerId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    yield parse();
    yield* box.watch().map((_) => parse());
  }
}
