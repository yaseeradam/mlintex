import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/receive_order.dart';
import '../../domain/repositories/receive_order_repository.dart';
import '../../core/providers/repository_providers.dart';

final receiveOrdersProvider = StreamProvider<List<ReceiveOrder>>((ref) {
  return ref.watch(receiveOrderRepositoryProvider).watchOrders();
});

class ReceiveOrderNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ReceiveOrderRepository get _repo =>
      ref.read(receiveOrderRepositoryProvider);

  Future<void> addOrder({
    required String supplierName,
    required List<ReceiveOrderItem> items,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final total = items.fold<double>(0, (s, i) => s + i.subtotal);
      final order = ReceiveOrder(
        id: _uuid.v4(),
        supplierName: supplierName,
        items: items,
        totalAmount: total,
        receivedDate: DateTime.now(),
        note: note,
      );
      await _repo.addOrder(order);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteOrder(String id) async {
    await _repo.deleteOrder(id);
  }
}

final receiveOrderNotifierProvider =
    NotifierProvider<ReceiveOrderNotifier, AsyncValue<void>>(
  ReceiveOrderNotifier.new,
);
