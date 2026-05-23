import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/sale_local_datasource.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  final SaleLocalDataSource _localDataSource;

  SaleRepositoryImpl(this._localDataSource);

  @override
  Future<List<Sale>> getAllSales() async {
    final models = await _localDataSource.getAllSales();
    return models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
  }

  @override
  Future<void> addSale(Sale sale) async {
    final model = SaleModel.fromEntity(sale);
    await _localDataSource.saveSale(model);
  }

  @override
  Future<void> deleteSale(String id) async {
    await _localDataSource.deleteSale(id);
  }

  @override
  Stream<List<Sale>> watchSales() {
    return _localDataSource.watchSales().map(
      (models) => models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => b.saleDate.compareTo(a.saleDate)),
    );
  }

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    final models = await _localDataSource.getSalesByDateRange(start, end);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<double> getTodayRevenue() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final sales = await getSalesByDateRange(startOfDay, endOfDay);
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }
}
