import 'package:hive_flutter/hive_flutter.dart';
import '../models/debt_model.dart';

class DebtLocalDataSource {
  static const String _boxName = 'debts';

  Future<Box<DebtModel>> get _box async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    return Hive.openBox<DebtModel>('${_boxName}_$shopId');
  }

  Future<List<DebtModel>> getAllDebts() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<List<DebtModel>> getDebtsByCustomer(String customerId) async {
    final box = await _box;
    return box.values.where((d) => d.customerId == customerId).toList();
  }

  Future<void> saveDebt(DebtModel debt) async {
    final box = await _box;
    await box.put(debt.id, debt);
  }

  Future<void> deleteDebt(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Stream<List<DebtModel>> watchDebts() async* {
    final box = await _box;
    yield box.values.toList();
    yield* box.watch().map((_) => box.values.toList());
  }

  Future<List<DebtModel>> getUnsyncedDebts() async {
    final box = await _box;
    return box.values.where((d) => !d.isSynced).toList();
  }
}
