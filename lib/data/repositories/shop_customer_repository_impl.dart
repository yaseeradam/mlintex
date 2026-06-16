import '../../domain/entities/customer.dart';
import '../../domain/repositories/shop_customer_repository.dart';
import '../datasources/shop_customer_local_datasource.dart';
import '../models/customer_model.dart';

class ShopCustomerRepositoryImpl implements ShopCustomerRepository {
  final ShopCustomerLocalDataSource _localDataSource;

  ShopCustomerRepositoryImpl(this._localDataSource);

  @override
  Future<List<Customer>> getAllCustomers() async {
    final models = await _localDataSource.getAllCustomers();
    return models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    final model = await _localDataSource.getCustomerById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    final model = CustomerModel.fromEntity(customer);
    await _localDataSource.saveCustomer(model);
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final model = CustomerModel.fromEntity(
      customer.copyWith(updatedAt: DateTime.now(), isSynced: false),
    );
    await _localDataSource.saveCustomer(model);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _localDataSource.deleteCustomer(id);
  }

  @override
  Stream<List<Customer>> watchCustomers() {
    return _localDataSource.watchCustomers().map(
      (models) => models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final all = await getAllCustomers();
    final q = query.toLowerCase();
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.phone?.contains(q) ?? false),
        )
        .toList();
  }
}
