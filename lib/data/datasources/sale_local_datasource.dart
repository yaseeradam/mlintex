import 'package:hive_flutter/hive_flutter.dart';
import '../models/sale_model.dart';
import '../../core/services/pending_sync_tracker.dart';

class SaleLocalDataSource {
  static const String _boxName = 'sales';

  Future<Box<SaleModel>> get _box async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    return Hive.openBox<SaleModel>('${_boxName}_$shopId');
  }

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
    PendingSyncTracker.markPendingDelete(box.name, id);
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

  Future<void> markAsSynced(String id) async {
    final box = await _box;
    final sale = box.get(id);
    if (sale != null) {
      await box.put(id, SaleModel(
        id: sale.id,
        items: sale.items,
        totalAmount: sale.totalAmount,
        customerId: sale.customerId,
        customerName: sale.customerName,
        saleDate: sale.saleDate,
        paymentMethod: sale.paymentMethod,
        isSynced: true,
      ));
    }
  }
}
