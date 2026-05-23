import '../entities/sale.dart';

abstract class SaleRepository {
  Future<List<Sale>> getAllSales();
  Future<void> addSale(Sale sale);
  Future<void> deleteSale(String id);
  Stream<List<Sale>> watchSales();
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end);
  Future<double> getTodayRevenue();
}
