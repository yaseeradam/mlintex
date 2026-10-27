import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/presentation/analytics/weekly_sales_provider.dart';
import 'package:shop_manager/presentation/sales_ledger/sales_ledger_screen.dart';
import 'package:shop_manager/domain/entities/sale.dart';

void main() {
  group('Weekly Sales Date Boundary Calculations', () {
    test('computeWeekStart returns Monday 00:00:00 for any day in the week', () {
      // Wednesday, Oct 22, 2025
      final wednesday = DateTime(2025, 10, 22, 14, 30, 45);
      final start = computeWeekStart(wednesday);

      expect(start.year, 2025);
      expect(start.month, 10);
      expect(start.day, 20); // Monday was Oct 20
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.weekday, DateTime.monday);
    });

    test('computeWeekEnd returns Sunday 23:59:59 for any day in the week', () {
      // Wednesday, Oct 22, 2025
      final wednesday = DateTime(2025, 10, 22, 14, 30, 45);
      final start = computeWeekStart(wednesday);
      final end = computeWeekEnd(start);

      expect(end.year, 2025);
      expect(end.month, 10);
      expect(end.day, 26); // Sunday was Oct 26
      expect(end.hour, 23);
      expect(end.minute, 59);
      expect(end.second, 59);
      expect(end.weekday, DateTime.sunday);
    });

    test('Sunday correctly resolves to current week Monday rather than prior week', () {
      // Sunday, Oct 26, 2025
      final sunday = DateTime(2025, 10, 26, 18, 0, 0);
      final start = computeWeekStart(sunday);
      final end = computeWeekEnd(start);

      expect(start.day, 20); // Oct 20 (Monday)
      expect(end.day, 26);   // Oct 26 (Sunday)
    });
  });

  group('Weekly Sales Aggregation Calculations', () {
    test('Aggregates POS sales and ledger sales correctly within the active week', () {
      // Reference Monday: Oct 20, 2025
      final baseMonday = DateTime(2025, 10, 20);
      final weekStart = computeWeekStart(baseMonday);
      final weekEnd = computeWeekEnd(weekStart);

      // Sale on Tuesday (Oct 21) - POS Sale
      final posSales = [
        Sale(
          id: 'pos-1',
          customerName: 'Amina',
          items: const [
            SaleItem(
              productId: 'p1',
              productName: 'Silk Fabric',
              quantity: 2,
              unitPrice: 5000,
              costPrice: 3000,
            ),
          ],
          totalAmount: 10000,
          paymentMethod: 'Transfer',
          saleDate: DateTime(2025, 10, 21, 10, 0),
        ),
        // Sale outside this week (Oct 15 - prior week)
        Sale(
          id: 'pos-old',
          customerName: 'Fatima',
          items: const [
            SaleItem(
              productId: 'p1',
              productName: 'Silk Fabric',
              quantity: 1,
              unitPrice: 5000,
              costPrice: 3000,
            ),
          ],
          totalAmount: 5000,
          paymentMethod: 'Cash',
          saleDate: DateTime(2025, 10, 15, 10, 0),
        ),
      ];

      // Ledger Sale on Friday (Oct 24)
      final ledgerEntries = [
        SalesLedgerEntry(
          id: 'led-1',
          date: DateTime(2025, 10, 24, 15, 30),
          inItem: 'Cotton Brocade',
          price: 4000,
          quantity: 3,
          totalAmount: 12000,
          typeIndex: 1, // Sale
          payment: 12000,
          costPrice: 2500,
        ),
        // Payment-only entry (should NOT be counted as revenue or goods sale)
        SalesLedgerEntry(
          id: 'led-pay',
          date: DateTime(2025, 10, 24, 16, 0),
          typeIndex: 0, // Payment
          totalAmount: 5000,
          payment: 5000,
        ),
      ];

      final summary = calculateWeeklySummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        sales: posSales,
        ledgerEntries: ledgerEntries,
        productCostByName: {'silk fabric': 3000, 'cotton brocade': 2500},
        priorWeekRevenue: 20000,
      );

      // Total revenue: 10,000 (POS) + 12,000 (Ledger) = 22,000
      expect(summary.totalRevenue, 22000.0);

      // Profit POS: (5000 - 3000) * 2 = 4000
      // Profit Ledger: (4000 - 2500) * 3 = 4500
      // Total profit = 8500
      expect(summary.totalProfit, 8500.0);

      // Profit margin: 8500 / 22000 * 100 = 38.636%
      expect(summary.profitMarginPercent, closeTo(38.64, 0.05));

      // Total orders = 1 POS + 1 Ledger = 2
      expect(summary.totalOrders, 2);

      // Total items = 2 (Silk) + 3 (Cotton) = 5
      expect(summary.totalItems, 5);

      // Top products ranking
      expect(summary.topProducts.length, 2);
      expect(summary.topProducts[0].productName, 'COTTON BROCADE'); // 12,000 revenue
      expect(summary.topProducts[0].revenue, 12000.0);
      expect(summary.topProducts[0].quantity, 3);
      expect(summary.topProducts[1].productName, 'SILK FABRIC');    // 10,000 revenue
      expect(summary.topProducts[1].revenue, 10000.0);
      expect(summary.topProducts[1].quantity, 2);

      // Daily breakdown
      // Day 0: Mon (0)
      // Day 1: Tue (10,000)
      // Day 2: Wed (0)
      // Day 3: Thu (0)
      // Day 4: Fri (12,000)
      // Day 5: Sat (0)
      // Day 6: Sun (0)
      expect(summary.dailyPoints[1].revenue, 10000.0);
      expect(summary.dailyPoints[1].profit, 4000.0);
      expect(summary.dailyPoints[4].revenue, 12000.0);
      expect(summary.dailyPoints[4].profit, 4500.0);

      // Best day should be Friday (12,000)
      expect(summary.bestDay?.dayName, 'Fri');
      expect(summary.bestDay?.revenue, 12000.0);

      // Revenue growth vs prior week (20,000 -> 22,000 = +10%)
      expect(summary.revenueGrowthPercent, closeTo(10.0, 0.01));
    });
  });
}
