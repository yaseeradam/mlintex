import '../entities/customer.dart';

abstract class ShopCustomerRepository {
  Future<List<Customer>> getAllCustomers();
  Future<Customer?> getCustomerById(String id);
  Future<void> addCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
  Stream<List<Customer>> watchCustomers();
  Future<List<Customer>> searchCustomers(String query);
}
