import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/providers/repository_providers.dart';

/// Cart item for active sale
class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity}) => CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );
}

/// Cart state notifier
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addProduct(Product product) {
    final idx = state.indexWhere((c) => c.product.id == product.id);
    if (idx >= 0) {
      final updated = [...state];
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
      state = updated;
    } else {
      state = [...state, CartItem(product: product, quantity: 1)];
    }
  }

  void removeProduct(String productId) {
    state = state.where((c) => c.product.id != productId).toList();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    final idx = state.indexWhere((c) => c.product.id == productId);
    if (idx >= 0) {
      final updated = [...state];
      updated[idx] = updated[idx].copyWith(quantity: quantity);
      state = updated;
    }
  }

  void clear() => state = [];

  double get total => state.fold<double>(0.0, (sum, item) => sum + item.subtotal);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold<double>(0.0, (sum, item) => sum + item.subtotal);
});

/// Sales stream
final salesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(saleRepositoryProvider).watchSales();
});

final todayRevenueProvider = FutureProvider<double>((ref) {
  return ref.watch(saleRepositoryProvider).getTodayRevenue();
});

/// Complete a sale
class SaleNotifier extends Notifier<AsyncValue<void>> {
  final _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> completeSale({Customer? customer}) async {
    state = const AsyncValue.loading();
    try {
      final cart = ref.read(cartProvider);
      if (cart.isEmpty) {
        state = const AsyncValue.data(null);
        return false;
      }

      final saleItems = cart
          .map(
            (c) => SaleItem(
              productId: c.product.id,
              productName: c.product.name,
              unitPrice: c.product.price,
              quantity: c.quantity,
            ),
          )
          .toList();

      final total = cart.fold<double>(0.0, (sum, item) => sum + item.subtotal);

      final sale = Sale(
        id: _uuid.v4(),
        items: saleItems,
        totalAmount: total,
        customerId: customer?.id,
        customerName: customer?.name,
        saleDate: DateTime.now(),
        isSynced: false,
      );

      await ref.read(saleRepositoryProvider).addSale(sale);

      // Deduct stock
      final productRepo = ref.read(productRepositoryProvider);
      for (final item in cart) {
        final product = await productRepo.getProductById(item.product.id);
        if (product != null) {
          await productRepo.updateQuantity(
            product.id,
            (product.quantity - item.quantity).clamp(0, 999999),
          );
        }
      }

      ref.read(cartProvider.notifier).clear();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final saleNotifierProvider = NotifierProvider<SaleNotifier, AsyncValue<void>>(
  SaleNotifier.new,
);
