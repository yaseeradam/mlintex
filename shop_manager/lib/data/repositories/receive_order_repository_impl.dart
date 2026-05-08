import '../../domain/entities/receive_order.dart';
import '../../domain/repositories/receive_order_repository.dart';
import '../datasources/receive_order_local_datasource.dart';
import '../models/receive_order_model.dart';

class ReceiveOrderRepositoryImpl implements ReceiveOrderRepository {
  final ReceiveOrderLocalDataSource _ds;
  ReceiveOrderRepositoryImpl(this._ds);

  @override
  Future<List<ReceiveOrder>> getAllOrders() async {
    final models = await _ds.getAllOrders();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Stream<List<ReceiveOrder>> watchOrders() {
    return _ds.watchOrders().map((list) => list.map((m) => m.toEntity()).toList());
  }

  @override
  Future<void> addOrder(ReceiveOrder order) async {
    await _ds.saveOrder(ReceiveOrderModel.fromEntity(order));
  }

  @override
  Future<void> updateOrder(ReceiveOrder order) async {
    await _ds.saveOrder(ReceiveOrderModel.fromEntity(order));
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _ds.deleteOrder(id);
  }
}
