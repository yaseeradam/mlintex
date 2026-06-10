import 'package:hive_flutter/hive_flutter.dart';
import '../models/receive_order_model.dart';

class ReceiveOrderLocalDataSource {
  static const String _boxName = 'receive_orders';

  Future<Box> get _box async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    return Hive.openBox('${_boxName}_$shopId');
  }

  Future<List<ReceiveOrderModel>> getAllOrders() async {
    final box = await _box;
    return box.values
        .map((e) => ReceiveOrderModel.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  Future<void> saveOrder(ReceiveOrderModel order) async {
    final box = await _box;
    await box.put(order.id, order.toMap());
  }

  Future<void> deleteOrder(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Stream<List<ReceiveOrderModel>> watchOrders() async* {
    final box = await _box;
    List<ReceiveOrderModel> parse() => box.values
        .map((e) => ReceiveOrderModel.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    yield parse();
    yield* box.watch().map((_) => parse());
  }
}
