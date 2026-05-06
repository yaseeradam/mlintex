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
import '../widgets/add_debt_sheet.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _Header(
                  onSyncTap: isSyncing ? null : () => ref.read(syncServiceProvider).syncAll(),
                  isSyncing: isSyncing,
                  syncStatus: syncStatus.value,
                ),
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _QuickActions(ref: ref),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
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
  final VoidCallback? onSyncTap;
  final bool isSyncing;
  final SyncStatus? syncStatus;

  const _Header({
    this.onSyncTap,
    required this.isSyncing,
    this.syncStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final isPending =
        syncStatus == SyncStatus.pending || syncStatus == SyncStatus.syncing;

    final initial = authState.shopName.isNotEmpty
        ? authState.shopName[0].toUpperCase()
        : 'S';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.2),
                    AppTheme.accentColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
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
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  authState.shopName.isEmpty ? 'My Shop' : authState.shopName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: onSyncTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPending ? AppTheme.warningColor : AppTheme.successColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isPending ? AppTheme.warningColor : AppTheme.successColor)
                    .withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  isSyncing ? 'Syncing...' : isPending ? 'Pending' : 'Synced',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      childAspectRatio: 1.3,
      children: [
        StatBadge(
          label: "Today's Sales",
          value: currency.format(todayRevenue),
          icon: PhosphorIconsFill.trendUp,
          iconColor: AppTheme.successColor,
        ),
        StatBadge(
          label: 'Products',
          value: productCount.toString(),
          icon: PhosphorIconsFill.package,
          iconColor: AppTheme.primaryColor,
        ),
        StatBadge(
          label: 'Customers',
          value: customerCount.toString(),
          icon: PhosphorIconsFill.users,
          iconColor: AppTheme.warningColor,
        ),
        StatBadge(
          label: 'Total Debts',
          value: currency.format(totalDebt),
          icon: PhosphorIconsFill.receipt,
          iconColor: AppTheme.errorColor,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final WidgetRef ref;
  const _QuickActions({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Add Product',
                icon: PhosphorIconsFill.package,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                ),
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
                icon: PhosphorIconsFill.userPlus,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.warningColor, const Color(0xFFD97706)],
                ),
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
                icon: PhosphorIconsFill.receipt,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.errorColor, const Color(0xFFE11D48)],
                ),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddDebtSheet(),
                ),
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
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Sales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        salesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
            ),
            child: Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
          ),
          data: (sales) {
            if (sales.isEmpty) {
              return ModernCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(PhosphorIconsRegular.receipt, size: 48, color: textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No sales yet. Start selling!',
                      style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
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
                return ModernCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.2),
                              AppTheme.accentColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Icon(PhosphorIconsFill.receipt, color: AppTheme.primaryLight, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.customerName ?? 'Walk-in Customer',
                              style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${sale.items.length} item(s) • $timeFmt',
                              style: TextStyle(color: textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt.format(sale.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.successColor, fontSize: 16),
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
