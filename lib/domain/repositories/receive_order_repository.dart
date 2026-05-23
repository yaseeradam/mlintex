import '../entities/receive_order.dart';

abstract class ReceiveOrderRepository {
  Future<List<ReceiveOrder>> getAllOrders();
  Stream<List<ReceiveOrder>> watchOrders();
  Future<void> addOrder(ReceiveOrder order);
  Future<void> updateOrder(ReceiveOrder order);
  Future<void> deleteOrder(String id);
}
