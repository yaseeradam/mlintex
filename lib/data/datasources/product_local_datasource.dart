import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';

class ProductLocalDataSource {
  static const String _boxName = 'products';

  Future<Box<ProductModel>> get _box async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    return Hive.openBox<ProductModel>('${_boxName}_$shopId');
  }

  Future<List<ProductModel>> getAllProducts() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<void> saveProduct(ProductModel product) async {
    final box = await _box;
    await box.put(product.id, product);
  }

  Future<void> deleteProduct(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Stream<List<ProductModel>> watchProducts() async* {
    final box = await _box;
    yield box.values.toList();
    yield* box.watch().map((_) => box.values.toList());
  }

  Future<List<ProductModel>> getUnsyncedProducts() async {
    final box = await _box;
    return box.values.where((p) => !p.isSynced).toList();
  }

  Future<void> markAsSynced(String id) async {
    final box = await _box;
    final product = box.get(id);
    if (product != null) {
      final synced = ProductModel(
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: product.quantity,
        category: product.category,
        barcode: product.barcode,
        updatedAt: product.updatedAt,
        isSynced: true,
      );
      await box.put(id, synced);
    }
  }
}
