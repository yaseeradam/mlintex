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
    final authState = ref.watch(authProvider);

    final currency = NumberFormat('#,##0', 'en_US');
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);

    return Container(
      color: bg,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero Banner ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroBanner(
                authState: authState,
                isSyncing: isSyncing,
                syncStatus: syncStatus.value,
                onSyncTap: isSyncing ? null : () => ref.read(syncServiceProvider).syncAll(),
                todayRevenue: todayRevenue.value ?? 0,
                currency: currency,
              ),
            ),

            // ── Stat Cards ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Products',
                    value: (productsAsync.value?.length ?? 0).toString(),
                    icon: PhosphorIconsFill.package,
                    color: AppTheme.primaryColor,
                    bg: AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Customers',
                    value: (customersAsync.value?.length ?? 0).toString(),
                    icon: PhosphorIconsFill.users,
                    color: AppTheme.warningColor,
                    bg: AppTheme.warningColor.withOpacity(isDark ? 0.15 : 0.08),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Total Debt',
                    value: '₦${currency.format(totalDebt.value ?? 0)}',
                    icon: PhosphorIconsFill.receipt,
                    color: AppTheme.errorColor,
                    bg: AppTheme.errorColor.withOpacity(isDark ? 0.15 : 0.08),
                    small: true,
                  )),
                ]),
              ),
            ),

            // ── Quick Actions ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _QuickActions(ref: ref),
              ),
            ),

            // ── Recent Sales ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _RecentActivity(ref: ref),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final AuthState authState;
  final bool isSyncing;
  final SyncStatus? syncStatus;
  final VoidCallback? onSyncTap;
  final double todayRevenue;
  final NumberFormat currency;

  const _HeroBanner({
    required this.authState,
    required this.isSyncing,
    required this.syncStatus,
    required this.onSyncTap,
    required this.todayRevenue,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final isPending = syncStatus == SyncStatus.pending || syncStatus == SyncStatus.syncing;
    final initial = authState.shopName.isNotEmpty ? authState.shopName[0].toUpperCase() : 'M';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + greeting + sync
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(
                      authState.shopName.isEmpty ? 'M Lin Tex' : authState.shopName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSyncTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isSyncing)
                      const SizedBox(width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                    else
                      Container(width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: isPending ? AppTheme.warningColor : const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          )),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing ? 'Syncing' : isPending ? 'Pending' : 'Synced',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),

          // Today's revenue
          Text("Today's Revenue", style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '₦${currency.format(todayRevenue)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded, size: 10, color: Colors.white70),
                const SizedBox(width: 4),
                Text(DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool small;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 14 : 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────

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
        Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionTile(
            label: 'Add Product',
            icon: PhosphorIconsFill.package,
            color: AppTheme.primaryColor,
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent, builder: (_) => const QuickAddProductSheet()),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionTile(
            label: 'Add Customer',
            icon: PhosphorIconsFill.userPlus,
            color: AppTheme.warningColor,
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent, builder: (_) => const QuickAddCustomerSheet()),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionTile(
            label: 'New Debt',
            icon: PhosphorIconsFill.receipt,
            color: AppTheme.errorColor,
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent, builder: (_) => const AddDebtSheet()),
          )),
        ]),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.12 : 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
        ]),
      ),
    );
  }
}

// ── Recent Activity ──────────────────────────────────────────────────────────

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
            Text('Recent Sales', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
            TextButton(
              onPressed: () {},
              child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        salesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
          data: (sales) {
            if (sales.isEmpty) {
              return ModernCard(
                padding: const EdgeInsets.all(28),
                child: Column(children: [
                  Icon(PhosphorIconsRegular.receipt, size: 44, color: textMuted.withOpacity(0.4)),
                  const SizedBox(height: 10),
                  Text('No sales yet. Start selling!', style: TextStyle(color: textMuted, fontSize: 14)),
                ]),
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
                final fmt = NumberFormat('#,##0', 'en_US');
                final timeFmt = DateFormat('h:mm a').format(sale.saleDate);
                return ModernCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(PhosphorIconsFill.receipt, color: AppTheme.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.customerName ?? 'Walk-in Customer',
                            style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${sale.items.length} item(s) • $timeFmt',
                            style: TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    )),
                    Text('₦${fmt.format(sale.totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.successColor, fontSize: 15)),
                  ]),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
