import 'package:uuid/uuid.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource _localDataSource;
  final _uuid = const Uuid();

  ProductRepositoryImpl(this._localDataSource);

  @override
  Future<List<Product>> getAllProducts() async {
    final models = await _localDataSource.getAllProducts();
    return models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Product?> getProductById(String id) async {
    final model = await _localDataSource.getProductById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addProduct(Product product) async {
    final model = ProductModel.fromEntity(product);
    await _localDataSource.saveProduct(model);
  }

  @override
  Future<void> updateProduct(Product product) async {
    final model = ProductModel.fromEntity(
      product.copyWith(updatedAt: DateTime.now(), isSynced: false),
    );
    await _localDataSource.saveProduct(model);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _localDataSource.deleteProduct(id);
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _localDataSource.watchProducts().map(
      (models) => models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final all = await getAllProducts();
    final q = query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> updateQuantity(String id, int quantity) async {
    final product = await getProductById(id);
    if (product != null) {
      await updateProduct(product.copyWith(quantity: quantity));
    }
  }

  String generateId() => _uuid.v4();
}
