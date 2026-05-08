import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../core/providers/repository_providers.dart';

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchCustomers();
});

class _CustomerSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String v) => state = v;
}

final customerSearchProvider = NotifierProvider<_CustomerSearchNotifier, String>(
  _CustomerSearchNotifier.new,
);

final filteredCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final query = ref.watch(customerSearchProvider);
  final repo = ref.watch(customerRepositoryProvider);
  if (query.isEmpty) {
    return repo.getAllCustomers();
  }
  return repo.searchCustomers(query);
});

class CustomerNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  CustomerRepository get _repo => ref.read(customerRepositoryProvider);

  Future<void> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? shopNumber,
    String? avatarPath,
  }) async {
    state = const AsyncValue.loading();
    try {
      final customer = Customer(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        address: address,
        shopNumber: shopNumber,
        avatarPath: avatarPath,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await _repo.addCustomer(customer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateCustomer(customer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _repo.deleteCustomer(id);
  }
}

final customerNotifierProvider = NotifierProvider<CustomerNotifier, AsyncValue<void>>(
  CustomerNotifier.new,
);
