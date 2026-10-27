import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_theme.dart';
import '../weekly_sales_provider.dart';

class WeeklySalesChart extends ConsumerWidget {
  final WeeklySalesSummary summary;

  const WeeklySalesChart({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDayIndex = ref.watch(selectedDayIndexProvider);
    final currency = NumberFormat('#,##0', 'en_US');

    // Find maximum value to scale the chart
    double maxVal = 0.0;
    for (final pt in summary.dailyPoints) {
      if (pt.revenue > maxVal) maxVal = pt.revenue;
      if (pt.profit > maxVal) maxVal = pt.profit;
    }
    if (maxVal <= 0) maxVal = 1000.0;
    // Add 15% headroom for aesthetic spacing
    final chartMax = maxVal * 1.15;

    final selectedPoint = (selectedDayIndex != null &&
            selectedDayIndex >= 0 &&
            selectedDayIndex < summary.dailyPoints.length)
        ? summary.dailyPoints[selectedDayIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedPoint == null
                        ? 'Tap any day to inspect details'
                        : '${selectedPoint.fullDayName} Selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selectedPoint == null
                          ? const Color(0xFF64748B)
                          : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _LegendIndicator(
                    color: AppTheme.primaryColor,
                    label: 'Revenue',
                  ),
                  const SizedBox(width: 12),
                  const _LegendIndicator(
                    color: Color(0xFF10B981),
                    label: 'Profit',
                  ),
                ],
              ),
            ],
          ),

          // Selected day details banner if selected
          if (selectedPoint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedPoint.fullDayName} (${DateFormat('MMM d').format(selectedPoint.date)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Sales: ₦${currency.format(selectedPoint.revenue)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Profit: ₦${currency.format(selectedPoint.profit)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // The Custom Canvas Chart
          SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) {
                    final widthPerDay = constraints.maxWidth / 7;
                    final clickedIndex = (details.localPosition.dx / widthPerDay).floor();
                    if (clickedIndex >= 0 && clickedIndex < 7) {
                      ref.read(selectedDayIndexProvider.notifier).toggleDay(clickedIndex);
                    }
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 190),
                    painter: _BarChartPainter(
                      points: summary.dailyPoints,
                      maxVal: chartMax,
                      selectedIndex: selectedDayIndex,
                      primaryColor: AppTheme.primaryColor,
                      profitColor: const Color(0xFF10B981),
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

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailySalesPoint> points;
  final double maxVal;
  final int? selectedIndex;
  final Color primaryColor;
  final Color profitColor;

  _BarChartPainter({
    required this.points,
    required this.maxVal,
    required this.selectedIndex,
    required this.primaryColor,
    required this.profitColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomLabelHeight = 26.0;
    final chartHeight = size.height - bottomLabelHeight;
    final widthPerDay = size.width / points.length;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barWidth = math.min(widthPerDay * 0.32, 16.0);
    final barSpacing = 3.0;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isSelected = selectedIndex == i;
      final dayCenterX = (i * widthPerDay) + (widthPerDay / 2);

      // Selected column background highlight
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = primaryColor.withOpacity(0.08)
          ..style = PaintingStyle.fill;
        final highlightRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(i * widthPerDay + 2, 0, widthPerDay - 4, chartHeight),
          const Radius.circular(8),
        );
        canvas.drawRRect(highlightRRect, highlightPaint);
      }

      // Heights based on proportions
      final revenueHeight = maxVal > 0 ? (pt.revenue / maxVal) * chartHeight : 0.0;
      final profitHeight = maxVal > 0 ? (pt.profit / maxVal) * chartHeight : 0.0;

      // Revenue Bar
      final revLeft = dayCenterX - barWidth - (barSpacing / 2);
      final revTop = chartHeight - math.max(revenueHeight, 3.0);
      final revRect = Rect.fromLTWH(revLeft, revTop, barWidth, math.max(revenueHeight, 3.0));
      final revPaint = Paint()
        ..color = isSelected
            ? primaryColor
            : (pt.revenue > 0 ? primaryColor.withOpacity(0.85) : const Color(0xFFE2E8F0));
      canvas.drawRRect(RRect.fromRectAndRadius(revRect, const Radius.circular(4)), revPaint);

      // Profit Bar
      final profLeft = dayCenterX + (barSpacing / 2);
      final profTop = chartHeight - math.max(profitHeight, 3.0);
      final profRect = Rect.fromLTWH(profLeft, profTop, barWidth, math.max(profitHeight, 3.0));
      final profPaint = Paint()
        ..color = isSelected
            ? profitColor
            : (pt.profit > 0 ? profitColor.withOpacity(0.85) : const Color(0xFFE2E8F0));
      canvas.drawRRect(RRect.fromRectAndRadius(profRect, const Radius.circular(4)), profPaint);

      // Day of week label
      final textSpan = TextSpan(
        text: pt.dayName,
        style: TextStyle(
          color: isSelected
              ? primaryColor
              : const Color(0xFF64748B),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textX = dayCenterX - (textPainter.width / 2);
      final textY = chartHeight + 6;
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.profitColor != profitColor;
  }
}
