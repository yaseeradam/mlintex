import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/providers/repository_providers.dart';

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchProducts();
});

class _SearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String v) => state = v;
}

final productSearchProvider = NotifierProvider<_SearchNotifier, String>(
  _SearchNotifier.new,
);

final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(productSearchProvider);
  final repo = ref.watch(productRepositoryProvider);
  if (query.isEmpty) {
    return repo.getAllProducts();
  }
  return repo.searchProducts(query);
});

class ProductNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ProductRepository get _repo => ref.read(productRepositoryProvider);

  Future<void> addProduct({
    required String name,
    required double price,
    required int quantity,
    String? category,
    String? barcode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final product = Product(
        id: _uuid.v4(),
        name: name,
        price: price,
        quantity: quantity,
        category: category,
        barcode: barcode,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await _repo.addProduct(product);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateProduct(product);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateQuantity(String id, int delta) async {
    final product = await _repo.getProductById(id);
    if (product == null) return;
    final newQty = (product.quantity + delta).clamp(0, 999999);
    await _repo.updateQuantity(id, newQty);
  }

  Future<void> deleteProduct(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteProduct(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final productNotifierProvider = NotifierProvider<ProductNotifier, AsyncValue<void>>(
  ProductNotifier.new,
);
