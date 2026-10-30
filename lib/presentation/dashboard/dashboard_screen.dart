import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../analytics/weekly_sales_screen.dart';
import '../analytics/weekly_sales_provider.dart';
import '../products/product_provider.dart';
import '../settings/profile_screen.dart';
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
import '../../core/services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final salesAsync = ref.watch(salesProvider);
    final ledgerAsync = ref.watch(salesLedgerEntriesProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final todayProfit = ref.watch(todayProfitProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final authState = ref.watch(authProvider);

    final products = productsAsync.value ?? [];
    final totalProducts = products.length;
    final inventoryValue = products.fold<double>(
      0.0,
      (sum, p) => sum + (p.quantity * (p.costPrice > 0 ? p.costPrice : p.price)),
    );

    final currency = NumberFormat('#,##0', 'en_US');
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    const bg = Color(0xFFF8FAFC);

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final displayName = authState.shopName.isNotEmpty
        ? authState.shopName
        : 'Malan';

    // Rolling last 7 days ending today
    final today = DateTime(now.year, now.month, now.day);
    final rollingDays = List.generate(7, (i) {
      return today.subtract(Duration(days: 6 - i));
    });

    final allPosSales = salesAsync.value ?? [];
    final allLedgerSales = ledgerAsync.value ?? [];

    final rollingDayPoints = rollingDays.map((d) {
      final dStart = DateTime(d.year, d.month, d.day);
      final dEnd = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
      double rev = 0.0;
      double profit = 0.0;
      int orders = 0;

      for (final s in allPosSales) {
        if (s.saleDate.isAfter(dStart.subtract(const Duration(milliseconds: 1))) &&
            s.saleDate.isBefore(dEnd.add(const Duration(milliseconds: 1)))) {
          rev += s.totalAmount;
          orders += 1;
          for (final item in s.items) {
            final cost = (item.costPrice != null && item.costPrice! > 0) ? item.costPrice! : 0.0;
            if (cost > 0) profit += (item.unitPrice - cost) * item.quantity;
          }
        }
      }

      for (final e in allLedgerSales) {
        if (e.typeIndex == 1 &&
            e.date.isAfter(dStart.subtract(const Duration(milliseconds: 1))) &&
            e.date.isBefore(dEnd.add(const Duration(milliseconds: 1)))) {
          rev += e.totalAmount;
          final qty = (e.quantity ?? 1);
          final cost = (e.costPrice != null && e.costPrice! > 0) ? e.costPrice! : 0.0;
          final unitPrice = e.price ?? (qty > 0 ? (e.totalAmount / qty) : e.totalAmount);
          if (cost > 0) {
            profit += (unitPrice - cost) * qty;
          }
          orders += 1;
        }
      }

      return _DailyChartPoint(
        date: d,
        dayLabel: DateFormat('EEE').format(d),
        revenue: rev,
        profit: profit,
        ordersCount: orders,
      );
    }).toList();

    return Container(
      color: bg,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top Bar Header (Dashboard + Notification + Profile) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        // Sync status badge
                        GestureDetector(
                          onTap: isSyncing
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
                                      AppFeedback.showError(context, 'Sync Failed', err);
                                    }
                                  }
                                },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSyncing)
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF2563EB),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: syncStatus.value == SyncStatus.error
                                          ? const Color(0xFFEF4444)
                                          : (syncStatus.value == SyncStatus.pending
                                              ? AppTheme.warningColor
                                              : const Color(0xFF10B981)),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  isSyncing
                                      ? 'Syncing'
                                      : (syncStatus.value == SyncStatus.error
                                          ? 'Failed'
                                          : (syncStatus.value == SyncStatus.pending ? 'Pending' : 'Synced')),
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bell Notification Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 20),
                              Positioned(
                                top: 9,
                                right: 9,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Profile Avatar Icon
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0F172A), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Greeting Section ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $displayName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Here is your business summary for today.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 2x2 Metric Cards Grid ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF16A34A),
                            iconBg: const Color(0xFFDCFCE7),
                            label: "Today's Sales",
                            value: '₦${currency.format(todayRevenue)}',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBg: const Color(0xFFDBEAFE),
                            label: "Today's Profit",
                            value: '₦${currency.format(todayProfit)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.category_rounded,
                            iconColor: const Color(0xFFD97706),
                            iconBg: const Color(0xFFFEF3C7),
                            label: 'Total Products',
                            value: '$totalProducts',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFF9333EA),
                            iconBg: const Color(0xFFF3E8FF),
                            label: 'Inventory Value',
                            value: '₦${currency.format(inventoryValue)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Weekly Sales Line Chart Card ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _WeeklySalesLineChartCard(
                  points: rollingDayPoints,
                  currency: currency,
                  onViewAllTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WeeklySalesScreen()),
                  ),
                ),
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

// ── Metric Card ──────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Daily Chart Point Data Model ─────────────────────────────────────────────

class _DailyChartPoint {
  final DateTime date;
  final String dayLabel;
  final double revenue;
  final double profit;
  final int ordersCount;

  const _DailyChartPoint({
    required this.date,
    required this.dayLabel,
    required this.revenue,
    required this.profit,
    required this.ordersCount,
  });
}

// ── Weekly Sales Line Chart Card ─────────────────────────────────────────────

class _WeeklySalesLineChartCard extends StatefulWidget {
  final List<_DailyChartPoint> points;
  final NumberFormat currency;
  final VoidCallback onViewAllTap;

  const _WeeklySalesLineChartCard({
    required this.points,
    required this.currency,
    required this.onViewAllTap,
  });

  @override
  State<_WeeklySalesLineChartCard> createState() => _WeeklySalesLineChartCardState();
}

class _WeeklySalesLineChartCardState extends State<_WeeklySalesLineChartCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    double maxRevenue = 0.0;
    for (final p in widget.points) {
      if (p.revenue > maxRevenue) maxRevenue = p.revenue;
    }
    // If no sales, use nominal max 1.0 to render clean zero baseline grid
    final chartMax = maxRevenue > 0 ? maxRevenue * 1.15 : 1.0;

    final selectedPoint = (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.points.length)
        ? widget.points[_selectedIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Sales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: widget.onViewAllTap,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Selected Point Details Banner
          if (selectedPoint != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(selectedPoint.date),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  Text(
                    '₦${widget.currency.format(selectedPoint.revenue)} (${selectedPoint.ordersCount} sales)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // The Line Chart
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const leftLabelWidth = 26.0;
                const bottomLabelHeight = 22.0;
                final plotWidth = constraints.maxWidth - leftLabelWidth;
                final stepX = plotWidth / (widget.points.length - 1);

                return GestureDetector(
                  onTapUp: (details) {
                    final dx = details.localPosition.dx;
                    if (dx >= leftLabelWidth) {
                      final relativeX = dx - leftLabelWidth;
                      final index = (relativeX / stepX).round().clamp(0, widget.points.length - 1);
                      setState(() {
                        _selectedIndex = (_selectedIndex == index) ? null : index;
                      });
                    }
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 180),
                    painter: _WeeklyLineChartPainter(
                      points: widget.points,
                      maxVal: chartMax,
                      selectedIndex: _selectedIndex,
                      lineColor: const Color(0xFF2563EB),
                      gridColor: const Color(0xFFE2E8F0),
                      labelColor: const Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Line Chart Custom Painter ─────────────────────────────────────────

class _WeeklyLineChartPainter extends CustomPainter {
  final List<_DailyChartPoint> points;
  final double maxVal;
  final int? selectedIndex;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  _WeeklyLineChartPainter({
    required this.points,
    required this.maxVal,
    required this.selectedIndex,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 26.0;
    const bottomAxisHeight = 22.0;
    const topMargin = 10.0;

    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight - topMargin;
    final originY = topMargin + chartHeight;
    final originX = leftAxisWidth;

    // ── 1. Draw 5 Horizontal Dashed Gridlines & Y-Axis Labels ──
    const gridLinesCount = 4;
    final dashPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridLinesCount; i++) {
      final ratio = i / gridLinesCount;
      final y = originY - (ratio * chartHeight);

      // Draw dashed horizontal line
      _drawDashedLine(canvas, originX, size.width, y, dashPaint);

      // Y-axis label text
      String yLabel;
      if (maxVal <= 1.0) {
        yLabel = (i >= 2) ? '1' : '0';
      } else {
        final val = (ratio * maxVal).round();
        if (val >= 1000000) {
          yLabel = '${(val / 1000000).toStringAsFixed(1)}m';
        } else if (val >= 1000) {
          yLabel = '${(val / 1000).round()}k';
        } else {
          yLabel = '$val';
        }
      }

      final textSpan = TextSpan(
        text: yLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftAxisWidth - tp.width - 6, y - (tp.height / 2)));
    }

    if (points.isEmpty) return;

    // ── 2. Compute Points Coordinates ──
    final stepX = points.length > 1 ? chartWidth / (points.length - 1) : chartWidth;
    final coords = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = originX + (i * stepX);
      final normalizedValue = (points[i].revenue / maxVal).clamp(0.0, 1.0);
      final y = originY - (normalizedValue * chartHeight);
      coords.add(Offset(x, y));
    }

    // ── 3. Draw Connecting Line ──
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(coords[0].dx, coords[0].dy);
    for (int i = 1; i < coords.length; i++) {
      path.lineTo(coords[i].dx, coords[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // ── 4. Draw Circular Dots & Day Labels at Bottom ──
    final dotPaint = Paint()..color = lineColor;
    final whitePaint = Paint()..color = Colors.white;

    for (int i = 0; i < coords.length; i++) {
      final pt = coords[i];
      final isSelected = selectedIndex == i;

      // Outer glow/ring if selected
      if (isSelected) {
        canvas.drawCircle(pt, 8.0, Paint()..color = lineColor.withOpacity(0.2));
        canvas.drawCircle(pt, 5.5, dotPaint);
        canvas.drawCircle(pt, 2.5, whitePaint);
      } else {
        canvas.drawCircle(pt, 4.0, dotPaint);
      }

      // X-Axis Day Label (Tue, Wed, Thu, Fri, Sat, Sun, Mon)
      final dayLabel = points[i].dayLabel;
      final tp = TextPainter(
        text: TextSpan(
          text: dayLabel,
          style: TextStyle(
            color: isSelected ? lineColor : labelColor,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pt.dx - (tp.width / 2), originY + 8));
    }
  }

  void _drawDashedLine(Canvas canvas, double startX, double endX, double y, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double currentX = startX;
    while (currentX < endX) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset(math.min(currentX + dashWidth, endX), y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.maxVal != maxVal;
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Database Reconnecting',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Establishing secure live connection to Firestore.',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await FirestoreService.ensureAuthenticated();
                    ref.invalidate(salesProvider);
                    ref.invalidate(salesLedgerEntriesProvider);
                  },
                  child: const Text('Reconnect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                ),
              ],
            ),
          )
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

