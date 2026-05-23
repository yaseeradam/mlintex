import 'package:hive_flutter/hive_flutter.dart';
import '../models/sale_model.dart';

class SaleLocalDataSource {
  static const String _boxName = 'sales';

  Future<Box<SaleModel>> get _box async => Hive.openBox<SaleModel>(_boxName);

  Future<List<SaleModel>> getAllSales() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<void> saveSale(SaleModel sale) async {
    final box = await _box;
    await box.put(sale.id, sale);
  }

  Future<void> deleteSale(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Stream<List<SaleModel>> watchSales() async* {
    final box = await _box;
    yield box.values.toList();
    yield* box.watch().map((_) => box.values.toList());
  }

  Future<List<SaleModel>> getUnsyncedSales() async {
    final box = await _box;
    return box.values.where((s) => !s.isSynced).toList();
  }

  Future<List<SaleModel>> getSalesByDateRange(DateTime start, DateTime end) async {
    final box = await _box;
    return box.values
        .where((s) => s.saleDate.isAfter(start) && s.saleDate.isBefore(end))
        .toList();
  }
}
