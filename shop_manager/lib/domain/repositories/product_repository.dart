import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(String id);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Stream<List<Product>> watchProducts();
  Future<List<Product>> searchProducts(String query);
  Future<void> updateQuantity(String id, int quantity);
}
