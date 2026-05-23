import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_feedback.dart';
import '../../core/utils/product_style_util.dart';
import '../products/product_provider.dart';
import '../customers/customer_provider.dart';
import 'sale_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final productsAsync = ref.watch(productsProvider);
    final saleState = ref.watch(saleNotifierProvider);

    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Sale',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  if (cart.isNotEmpty)
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).clear(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.errorColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsRegular.trash,
                              color: AppTheme.errorColor,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clear Cart',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (val) =>
                    ref.read(productSearchProvider.notifier).update(val),
                decoration: InputDecoration(
                  hintText: 'Search products to add…',
                  prefixIcon: const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(productSearchProvider.notifier).update('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Product grid
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (products) {
                  final query = ref.watch(productSearchProvider).toLowerCase();
                  final filtered = query.isEmpty
                      ? products
                      : products
                          .where((p) =>
                              p.name.toLowerCase().contains(query))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.magnifyingGlass,
                            size: 48,
                            color: AppTheme.textMuted.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No products found',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final product = filtered[i];
                      final inCart = cart
                          .where((c) => c.product.id == product.id)
                          .firstOrNull;
                      return _ProductTile(
                        product: product,
                        cartQuantity: inCart?.quantity ?? 0,
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .addProduct(product),
                        onDecrement: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(
                              product.id,
                              (inCart?.quantity ?? 1) - 1,
                            ),
                      );
                    },
                  );
                },
              ),
            ),

            // Cart Summary + Checkout
            if (cart.isNotEmpty)
              _CartSummary(
                cart: cart,
                total: cartTotal,
                onCheckout: () async {
                  AppFeedback.showLoading(context);
                  final success = await ref
                      .read(saleNotifierProvider.notifier)
                      .completeSale();
                  if (mounted) {
                    AppFeedback.hideLoading(context);
                    if (success) {
                      AppFeedback.showSuccess(
                        context,
                        'Sale Completed!',
                        'The sale has been successfully recorded.',
                      );
                    } else {
                      AppFeedback.showError(
                        context,
                        'Error',
                        'Failed to complete the sale.',
                      );
                    }
                  }
                },
              ),
            const SizedBox(height: 80), // nav bar space
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final dynamic product;
  final int cartQuantity;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  const _ProductTile({
    required this.product,
    required this.cartQuantity,
    required this.onTap,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isInCart = cartQuantity > 0;
    final style = ProductStyleUtil.getStyle(product.category, product.name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: ModernCard(
          padding: const EdgeInsets.all(12),
          bgColor: isInCart
              ? AppTheme.primaryColor.withOpacity(0.06)
              : AppTheme.surfaceColor,
          border: isInCart
              ? Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  width: 1.5,
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: style.colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            style.icon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isInCart)
                    GestureDetector(
                      onTap: onDecrement,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.minus,
                          size: 12,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₦${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${product.quantity} in stock',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (isInCart)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$cartQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  final VoidCallback? onCheckout;

  const _CartSummary({
    required this.cart,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ModernCard(
        padding: const EdgeInsets.all(16),
        bgColor: AppTheme.surfaceColor,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cart.length} item(s)',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₦${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onCheckout,
              icon: const Icon(PhosphorIconsFill.checkCircle, size: 18),
              label: const Text('Complete Sale'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: Size.zero,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
