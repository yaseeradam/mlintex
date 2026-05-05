import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/datasources/sync_service.dart';
import '../products/product_provider.dart';
import '../customers/customer_provider.dart';
import '../sales/sale_provider.dart';
import 'debt_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_product_sheet.dart';
import '../widgets/quick_add_customer_sheet.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final customersAsync = ref.watch(customersProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final totalDebt = ref.watch(totalOutstandingProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: const _Header(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _SummaryGrid(
                  todayRevenue: todayRevenue.value ?? 0,
                  productCount: productsAsync.value?.length ?? 0,
                  customerCount: customersAsync.value?.length ?? 0,
                  totalDebt: totalDebt.value ?? 0,
                  currency: currency,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _QuickActions(ref: ref),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _RecentActivity(ref: ref),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final isPending = syncStatus.value == SyncStatus.pending ||
        syncStatus.value == SyncStatus.syncing;

    final initial = authState.shopName.isNotEmpty ? authState.shopName[0].toUpperCase() : 'S';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // User Avatar Profile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    authState.shopName.isEmpty ? 'My Shop' : authState.shopName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Sync Status Indicator
          GestureDetector(
            onTap: () => ref.read(syncServiceProvider).syncAll(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (isPending ? AppTheme.errorColor : AppTheme.successColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isPending ? AppTheme.errorColor : AppTheme.successColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isPending ? AppTheme.errorColor : AppTheme.successColor).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    syncStatus.value == SyncStatus.syncing
                        ? 'Syncing'
                        : isPending
                            ? 'Pending'
                            : 'Synced',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPending ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final double todayRevenue;
  final int productCount;
  final int customerCount;
  final double totalDebt;
  final NumberFormat currency;

  const _SummaryGrid({
    required this.todayRevenue,
    required this.productCount,
    required this.customerCount,
    required this.totalDebt,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label: "Today's Sales",
          value: currency.format(todayRevenue),
          icon: Icons.trending_up_rounded,
          colors: const [Color(0xFF10B981), Color(0xFF059669)],
        ),
        _StatCard(
          label: 'Products',
          value: productCount.toString(),
          icon: Icons.inventory_2_rounded,
          colors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        _StatCard(
          label: 'Customers',
          value: customerCount.toString(),
          icon: Icons.people_rounded,
          colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        _StatCard(
          label: 'Total Debts',
          value: currency.format(totalDebt),
          icon: Icons.account_balance_wallet_rounded,
          colors: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final WidgetRef ref;
  const _QuickActions({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Add Product',
                icon: Icons.add_box_rounded,
                color: AppTheme.primaryColor,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const QuickAddProductSheet(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Add Customer',
                icon: Icons.person_add_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const QuickAddCustomerSheet(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'New Debt',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFEF4444),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  final WidgetRef ref;
  const _RecentActivity({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Sales',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (sales) {
            if (sales.isEmpty) {
              return GlassContainer(
                padding: const EdgeInsets.all(24),
                child: const Center(
                  child: Text(
                    'No sales yet. Start selling!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            final recent = sales.take(5).toList();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final sale = recent[i];
                final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
                final timeFmt = DateFormat('h:mm a').format(sale.saleDate);
                return GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_rounded, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.customerName ?? 'Walk-in Customer',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${sale.items.length} item(s) • $timeFmt',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt.format(sale.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
