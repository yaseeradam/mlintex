import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../analytics/weekly_sales_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/datasources/sync_service.dart';
import '../customers/customer_provider.dart';
import '../sales/sale_provider.dart';
import 'debt_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../widgets/add_debt_sheet.dart';
import '../widgets/app_feedback.dart';
import '../../domain/entities/sale.dart';
import '../widgets/app_shell.dart' show currentTabProvider;
import '../sales_ledger/sales_ledger_screen.dart' show salesLedgerEntriesProvider, SalesLedgerEntry;
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final totalProfit = ref.watch(totalProfitProvider);
    final todayProfit = ref.watch(todayProfitProvider);
    final totalDebt = ref.watch(totalOutstandingProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final authState = ref.watch(authProvider);

    final currency = NumberFormat('#,##0', 'en_US');
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    const bg = Color(0xFFF1F5F9);

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
                onSyncTap: isSyncing
                    ? null
                    : () async {
                        final success = await ref.read(syncServiceProvider).syncAll();
                        if (context.mounted) {
                          if (success) {
                            AppFeedback.showSuccess(
                              context,
                              'Sync Successful',
                              'All data synchronized with cloud database.',
                            );
                          } else {
                            final err = ref.read(syncServiceProvider).lastSyncError ?? 'Unknown error';
                            AppFeedback.showError(
                              context,
                              'Sync Failed',
                              err,
                            );
                          }
                        }
                      },
                todayRevenue: todayRevenue,
                todayProfit: todayProfit,
                currency: currency,
              ),
            ),

            // ── Stat Cards ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _StatCard(
                        label: 'Total Profit',
                        value: '₦${currency.format(totalProfit)}',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF10B981),
                        bg: const Color(0xFF10B981).withOpacity(0.1),
                        small: true,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        label: 'Total Debt',
                        value: '₦${currency.format(totalDebt.value ?? 0)}',
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.errorColor,
                        bg: AppTheme.errorColor.withOpacity(0.08),
                        small: true,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _StatCard(
                        label: 'Customers',
                        value: (customersAsync.value?.length ?? 0).toString(),
                        icon: Icons.people_rounded,
                        color: AppTheme.warningColor,
                        bg: AppTheme.warningColor.withOpacity(0.08),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        label: "Today's Profit",
                        value: '₦${currency.format(todayProfit)}',
                        icon: Icons.query_stats_rounded,
                        color: AppTheme.primaryColor,
                        bg: AppTheme.primaryColor.withOpacity(0.08),
                        small: true,
                      )),
                    ]),
                  ],
                ),
              ),
            ),

            // ── Weekly Sales Analytics Banner ────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _WeeklyAnalyticsBanner(),
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
  final double todayProfit;
  final NumberFormat currency;

  const _HeroBanner({
    required this.authState,
    required this.isSyncing,
    required this.syncStatus,
    required this.onSyncTap,
    required this.todayRevenue,
    required this.todayProfit,
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
                            color: syncStatus == SyncStatus.error
                                ? const Color(0xFFEF4444)
                                : isPending
                                    ? AppTheme.warningColor
                                    : const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          )),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing
                          ? 'Syncing'
                          : syncStatus == SyncStatus.error
                              ? 'Sync Failed'
                              : isPending
                                  ? 'Pending'
                                  : 'Synced',
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF6EE7B7)),
                const SizedBox(width: 4),
                Text("Today's Profit: ₦${currency.format(todayProfit)}",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),

          const SizedBox(height: 14),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View Weekly Sales & Profit Charts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
          ),
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
    const cardBg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
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
    const textPrimary = Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionTile(
            label: 'Add Customer',
            icon: Icons.person_add_rounded,
            color: AppTheme.warningColor,
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent, builder: (_) => const QuickAddCustomerSheet()),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionTile(
            label: 'New Debt',
            icon: Icons.receipt_long_rounded,
            color: AppTheme.errorColor,
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent, builder: (_) => const AddDebtSheet()),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionTile(
            label: 'Weekly Sales',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF6366F1),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
            ),
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
    const cardBg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const borderColor = Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
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

class _UnifiedRecentSale {
  final String id;
  final String customerName;
  final String subtitle;
  final double totalAmount;
  final DateTime date;

  const _UnifiedRecentSale({
    required this.id,
    required this.customerName,
    required this.subtitle,
    required this.totalAmount,
    required this.date,
  });
}

class _RecentActivity extends ConsumerWidget {
  final WidgetRef ref;
  const _RecentActivity({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    final salesAsync = ref.watch(salesProvider);
    final ledgerAsync = ref.watch(salesLedgerEntriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Sales', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
            TextButton(
              onPressed: () {
                ref.read(currentTabProvider.notifier).setTab(1);
              },
              child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (salesAsync.isLoading && ledgerAsync.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (salesAsync.hasError && ledgerAsync.hasError)
          Text('Error: ${salesAsync.error ?? ledgerAsync.error}', style: const TextStyle(color: AppTheme.errorColor))
        else ...[
          _buildSalesList(salesAsync.value ?? [], ledgerAsync.value ?? [], textPrimary, textMuted),
        ],
      ],
    );
  }

  Widget _buildSalesList(List<Sale> posSalesRaw, List<SalesLedgerEntry> ledgerEntriesRaw, Color textPrimary, Color textMuted) {
    final now = DateTime.now();

    final posSales = posSalesRaw.map((s) {
      final name = (s.customerName != null && s.customerName!.trim().isNotEmpty)
          ? s.customerName!.trim()
          : 'Walk-in Customer';
      final timeFmt = DateFormat('h:mm a').format(s.saleDate);
      final isToday = s.saleDate.year == now.year && s.saleDate.month == now.month && s.saleDate.day == now.day;
      final displayTime = isToday ? timeFmt : '${DateFormat('MMM d').format(s.saleDate)}, $timeFmt';
      return _UnifiedRecentSale(
        id: s.id,
        customerName: name,
        subtitle: '${s.items.length} item(s) • $displayTime',
        totalAmount: s.totalAmount,
        date: s.saleDate,
      );
    });

    final ledgerSales = ledgerEntriesRaw.where((e) => e.typeIndex == 1).map((e) {
      final name = (e.personName != null && e.personName!.trim().isNotEmpty)
          ? e.personName!.trim()
          : 'Walk-in Customer';
      final itemStr = (e.inItem != null && e.inItem!.trim().isNotEmpty) ? e.inItem!.trim() : 'Sale';
      final qtyStr = (e.quantity != null && e.quantity! > 0) ? '${e.quantity} pcs • ' : '';
      final timeFmt = DateFormat('h:mm a').format(e.date);
      final isToday = e.date.year == now.year && e.date.month == now.month && e.date.day == now.day;
      final displayTime = isToday ? timeFmt : '${DateFormat('MMM d').format(e.date)}, $timeFmt';
      return _UnifiedRecentSale(
        id: e.id,
        customerName: name,
        subtitle: '$itemStr • $qtyStr$displayTime',
        totalAmount: e.totalAmount,
        date: e.date,
      );
    });

    final allRecent = [...ledgerSales, ...posSales]..sort((a, b) => b.date.compareTo(a.date));
    final recent = allRecent.take(5).toList();

    if (recent.isEmpty) {
      return ModernCard(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          Icon(Icons.receipt_long_rounded, size: 44, color: textMuted.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text('No sales yet. Start selling!', style: TextStyle(color: textMuted, fontSize: 14)),
        ]),
      );
    }

    final fmt = NumberFormat('#,##0', 'en_US');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final sale = recent[i];
        return InkWell(
          onTap: () {
            ref.read(currentTabProvider.notifier).setTab(1);
          },
          borderRadius: BorderRadius.circular(16),
          child: ModernCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.customerName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sale.subtitle,
                      style: TextStyle(color: textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              const SizedBox(width: 8),
              Text('₦${fmt.format(sale.totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.successColor, fontSize: 15)),
            ]),
          ),
        );
      },
    );
  }
}

// ── Weekly Analytics Banner ──────────────────────────────────────────────────

class _WeeklyAnalyticsBanner extends StatelessWidget {
  const _WeeklyAnalyticsBanner();

  @override
  Widget build(BuildContext context) {
    const cardBg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Sales & Profit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Charts, daily breakdown & top products',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

