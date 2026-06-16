import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer_model.dart';

class ShopCustomerLocalDataSource {
  static const String _boxName = 'shop_customers';

  Future<Box<CustomerModel>> get _box async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    return Hive.openBox<CustomerModel>('${_boxName}_$shopId');
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    final box = await _box;
    await box.put(customer.id, customer);
  }

  Future<void> deleteCustomer(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Stream<List<CustomerModel>> watchCustomers() async* {
    final box = await _box;
    yield box.values.toList();
    yield* box.watch().map((_) => box.values.toList());
  }

  Future<List<CustomerModel>> getUnsyncedCustomers() async {
    final box = await _box;
    return box.values.where((c) => !c.isSynced).toList();
  }

  Future<void> markAsSynced(String id) async {
    final box = await _box;
    final c = box.get(id);
    if (c != null) {
      await box.put(
        id,
        CustomerModel(
          id: c.id,
          name: c.name,
          phone: c.phone,
          address: c.address,
          updatedAt: c.updatedAt,
          isSynced: true,
          avatarPath: c.avatarPath,
          shopNumber: c.shopNumber,
        ),
      );
    }
  }
}
