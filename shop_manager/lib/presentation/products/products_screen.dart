import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_product_sheet.dart';
import '../widgets/app_feedback.dart';
import '../../core/utils/product_style_util.dart';
import 'product_provider.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Products',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QuickAddProductSheet(),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    ref.read(productSearchProvider.notifier).update(val),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(productSearchProvider.notifier).update('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (products) {
                  final query = ref.watch(productSearchProvider).toLowerCase();
                  final filtered = query.isEmpty
                      ? products
                      : products.where((p) => p.name.toLowerCase().contains(query)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('No products yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Tap + to add your first product', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final product = filtered[i];
                      return _ProductListItem(
                        product: product,
                        onEdit: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => QuickAddProductSheet(existing: product),
                        ),
                        onDelete: () => _showDeleteDialog(context, product.id, product.name),
                        onIncrease: () => ref.read(productNotifierProvider.notifier).updateQuantity(product.id, 1),
                        onDecrease: () => ref.read(productNotifierProvider.notifier).updateQuantity(product.id, -1),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(productNotifierProvider.notifier).deleteProduct(id);
              Navigator.pop(context);
              AppFeedback.showSuccess(context, 'Deleted', 'Product "$name" has been deleted.');
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final dynamic product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _ProductListItem({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity < 5;
    final style = ProductStyleUtil.getStyle(product.category, product.name);
    
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: style.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: style.colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(style.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '₦${product.price.toStringAsFixed(2)} ${product.category != null ? "• ${product.category}" : ""}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Inline quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityButton(icon: Icons.remove, onTap: onDecrease),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '${product.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isLowStock ? AppTheme.errorColor : AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              _QuantityButton(icon: Icons.add, onTap: onIncrease),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppTheme.errorColor), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.errorColor))])),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppTheme.primaryColor),
      ),
    );
  }
}
