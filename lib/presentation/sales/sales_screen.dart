import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_feedback.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../../core/utils/product_style_util.dart';
import '../../domain/entities/customer.dart';
import '../products/product_provider.dart';
import '../customers/customer_provider.dart';
import 'sale_provider.dart';

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

  void _openCheckoutSheet(BuildContext context, List<CartItem> cart, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutBottomSheet(cart: cart, total: total),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final productsAsync = ref.watch(productsProvider);

    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context)) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Text(
                        'POS Ring Sale',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  if (cart.isNotEmpty)
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).clear(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.errorColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
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
                  hintText: 'Search products to ring up…',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
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
                            Icons.search_rounded,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.4),
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
                onCheckout: () => _openCheckoutSheet(context, cart, cartTotal),
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
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : AppTheme.surfaceColor,
          border: isInCart
              ? Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
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
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.remove_rounded,
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
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
              child: Builder(
                builder: (context) {
                  double cartProfit = 0.0;
                  for (final item in cart) {
                    final cost = item.product.costPrice;
                    if (cost > 0) {
                      cartProfit += (item.product.price - cost) * item.quantity;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${cart.length} item(s)',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          if (cartProfit > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Profit: +₦${cartProfit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₦${NumberFormat('#,##0.00').format(total)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
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

// ── Interactive Checkout Bottom Sheet ───────────────────────────────────────

class _CheckoutBottomSheet extends ConsumerStatefulWidget {
  final List<CartItem> cart;
  final double total;

  const _CheckoutBottomSheet({required this.cart, required this.total});

  @override
  ConsumerState<_CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends ConsumerState<_CheckoutBottomSheet> {
  Customer? _selectedCustomer;
  String _paymentMethod = 'Cash';
  bool _isSubmitting = false;

  final _paymentOptions = const [
    {'label': 'Cash', 'icon': Icons.payments_rounded},
    {'label': 'Transfer', 'icon': Icons.swap_horiz_rounded},
    {'label': 'POS Card', 'icon': Icons.credit_card_rounded},
    {'label': 'Credit', 'icon': Icons.receipt_long_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##0.00', 'en_US');
    final customers = ref.watch(customersProvider).value ?? [];
    final isCredit = _paymentMethod == 'Credit';

    double profit = 0.0;
    for (final item in widget.cart) {
      final cost = item.product.costPrice;
      if (cost > 0) {
        profit += (item.product.price - cost) * item.quantity;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Complete Sale',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${widget.cart.length} item(s)',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amount Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      '₦${currencyFmt.format(widget.total)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (profit > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Profit: +₦${currencyFmt.format(profit)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Customer Selector
          const Text(
            'Customer',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  _selectedCustomer == null ? Icons.person_outline_rounded : Icons.person_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                _selectedCustomer?.name ?? 'Walk-in Customer',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                _selectedCustomer?.phone ?? 'Standard retail transaction',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: TextButton(
                onPressed: () => _showCustomerPicker(context, customers),
                child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Payment Method Selector
          const Text(
            'Payment Method',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: _paymentOptions.map((opt) {
              final label = opt['label'] as String;
              final icon = opt['icon'] as IconData;
              final isSelected = _paymentMethod == label;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = label),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (isCredit && _selectedCustomer == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select a registered customer to track this credit sale.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSubmitting || (isCredit && _selectedCustomer == null))
                  ? null
                  : _handleCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Confirm & Complete Sale (₦${currencyFmt.format(widget.total)})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerPicker(BuildContext context, List<Customer> customers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = query.isEmpty
                ? customers
                : customers.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Customer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('New'),
                        onPressed: () {
                          Navigator.pop(pickerCtx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const QuickAddCustomerSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setPickerState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search customer name…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                    title: const Text('Walk-in Customer (Default)'),
                    onTap: () {
                      setState(() => _selectedCustomer = null);
                      Navigator.pop(pickerCtx);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(c.phone ?? ''),
                          onTap: () {
                            setState(() => _selectedCustomer = c);
                            Navigator.pop(pickerCtx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCheckout() async {
    setState(() => _isSubmitting = true);
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final success = await ref.read(saleNotifierProvider.notifier).completeSale(
          customer: _selectedCustomer,
          paymentMethod: _paymentMethod,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context); // Close bottom sheet

      if (success) {
        AppFeedback.showSuccess(
          context,
          'Sale Completed!',
          '₦${fmt.format(widget.total)} recorded via $_paymentMethod',
        );
      } else {
        AppFeedback.showError(
          context,
          'Error',
          'Failed to record the sale.',
        );
      }
    }
  }
}
