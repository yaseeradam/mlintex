import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'weekly_sales_provider.dart';
import 'widgets/weekly_sales_chart.dart';

class WeeklySalesScreen extends ConsumerWidget {
  const WeeklySalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySalesProvider);
    final weekOffset = ref.watch(selectedWeekOffsetProvider);
    final selectedDayIndex = ref.watch(selectedDayIndexProvider);

    final currency = NumberFormat('#,##0', 'en_US');
    final dateRangeFmt = DateFormat('MMM d, yyyy');
    final shortDateFmt = DateFormat('EEE, MMM d');

    final startDateStr = dateRangeFmt.format(summary.weekStart);
    final endDateStr = dateRangeFmt.format(summary.weekEnd);

    const bg = Color(0xFFF8FAFC);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Weekly Sales Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (weekOffset != 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(selectedWeekOffsetProvider.notifier).resetToThisWeek();
                  ref.read(selectedDayIndexProvider.notifier).selectDay(null);
                },
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('Current Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Week Navigator ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () {
                        ref.read(selectedWeekOffsetProvider.notifier).prevWeek();
                        ref.read(selectedDayIndexProvider.notifier).selectDay(null);
                      },
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: textPrimary,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.date_range_rounded, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                weekOffset == 0
                                    ? 'This Week'
                                    : (weekOffset == -1 ? 'Last Week' : '${weekOffset.abs()} Weeks Ago'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$startDateStr – $endDateStr',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: weekOffset < 0
                          ? () {
                              ref.read(selectedWeekOffsetProvider.notifier).nextWeek();
                              ref.read(selectedDayIndexProvider.notifier).selectDay(null);
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: textPrimary,
                        disabledBackgroundColor: const Color(0xFFF8FAFC),
                        disabledForegroundColor: const Color(0xFFCBD5E1),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── KPI Metrics Grid ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // Total Revenue & Total Profit
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            label: 'Total Revenue',
                            value: '₦${currency.format(summary.totalRevenue)}',
                            icon: Icons.payments_rounded,
                            color: AppTheme.primaryColor,
                            trendText: summary.revenueGrowthPercent != null
                                ? '${summary.revenueGrowthPercent! >= 0 ? '+' : ''}${summary.revenueGrowthPercent!.toStringAsFixed(1)}%'
                                : null,
                            isPositiveTrend: (summary.revenueGrowthPercent ?? 0) >= 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            label: 'Total Profit',
                            value: '₦${currency.format(summary.totalProfit)}',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF10B981),
                            badgeText: '${summary.profitMarginPercent.toStringAsFixed(1)}% margin',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Orders & Best Day
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            label: 'Total Sales Count',
                            value: '${summary.totalOrders} sales',
                            subValue: '${summary.totalItems} items sold',
                            icon: Icons.shopping_bag_rounded,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            label: 'Best Sales Day',
                            value: summary.bestDay != null
                                ? summary.bestDay!.dayName
                                : '—',
                            subValue: summary.bestDay != null
                                ? '₦${currency.format(summary.bestDay!.revenue)}'
                                : 'No sales yet',
                            icon: Icons.star_rounded,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Interactive Chart Section ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: WeeklySalesChart(summary: summary),
              ),
            ),

            // ── Day-by-Day Activity List ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    if (selectedDayIndex != null)
                      GestureDetector(
                        onTap: () => ref.read(selectedDayIndexProvider.notifier).selectDay(null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.close_rounded, size: 12, color: AppTheme.primaryColor),
                              SizedBox(width: 4),
                              Text('Show All Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final pt = summary.dailyPoints[index];
                    final isHighlighted = selectedDayIndex == index;

                    // If a specific day is selected and user tapped it, show only that or highlight it
                    if (selectedDayIndex != null && !isHighlighted) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isHighlighted
                              ? AppTheme.primaryColor
                              : const Color(0xFFE2E8F0),
                          width: isHighlighted ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  pt.dayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isHighlighted ? Colors.white : textPrimary,
                                  ),
                                ),
                                Text(
                                  DateFormat('d').format(pt.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isHighlighted ? Colors.white70 : textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shortDateFmt.format(pt.date),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${pt.orderCount} transaction${pt.orderCount == 1 ? '' : 's'} • ${pt.itemsCount} items',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₦${currency.format(pt.revenue)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+₦${currency.format(pt.profit)} profit',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: summary.dailyPoints.length,
                ),
              ),
            ),

            // ── Top Products Section ─────────────────────────────────
            if (summary.topProducts.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Text(
                    'Top Selling Items This Week',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = summary.topProducts[index];
                      final isTop1 = index == 0;
                      final isTop2 = index == 1;
                      final isTop3 = index == 2;

                      final badgeColor = isTop1
                          ? const Color(0xFFF59E0B)
                          : (isTop2
                              ? const Color(0xFF94A3B8)
                              : (isTop3
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFE2E8F0)));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isTop1 || isTop2 || isTop3 ? badgeColor : textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} units sold',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₦${currency.format(item.revenue)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                if (item.profit > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '+₦${currency.format(item.profit)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: summary.topProducts.length,
                  ),
                ),
              ),
            ],

            // ── Payment Methods Breakdown ────────────────────────────
            if (summary.paymentMethodsBreakdown.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Text(
                    'Payment Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: summary.paymentMethodsBreakdown.entries.map((entry) {
                      final pct = summary.totalRevenue > 0
                          ? (entry.value / summary.totalRevenue) * 100
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '₦${currency.format(entry.value)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color color;
  final String? trendText;
  final bool isPositiveTrend;
  final String? badgeText;

  const _KpiCard({
    required this.label,
    required this.value,
    this.subValue,
    required this.icon,
    required this.color,
    this.trendText,
    this.isPositiveTrend = true,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (trendText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositiveTrend ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 10,
                        color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trendText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                )
              else if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(
              subValue!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
