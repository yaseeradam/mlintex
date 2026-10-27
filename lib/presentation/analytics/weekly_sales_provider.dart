import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/sale.dart';
import '../sales/sale_provider.dart';
import '../products/product_provider.dart';
import '../sales_ledger/sales_ledger_screen.dart' show salesLedgerEntriesProvider, SalesLedgerEntry;

class DailySalesPoint {
  final DateTime date;
  final String dayName;
  final String fullDayName;
  final double revenue;
  final double profit;
  final int orderCount;
  final int itemsCount;

  const DailySalesPoint({
    required this.date,
    required this.dayName,
    required this.fullDayName,
    required this.revenue,
    required this.profit,
    required this.orderCount,
    required this.itemsCount,
  });
}

class ProductSalesRank {
  final String productName;
  final int quantity;
  final double revenue;
  final double profit;

  const ProductSalesRank({
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.profit,
  });
}

class WeeklySalesSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int weekOffset;
  final double totalRevenue;
  final double totalProfit;
  final double profitMarginPercent;
  final int totalOrders;
  final int totalItems;
  final double averageDailyRevenue;
  final DailySalesPoint? bestDay;
  final double? prevWeekRevenue;
  final double? revenueGrowthPercent;
  final List<DailySalesPoint> dailyPoints;
  final List<ProductSalesRank> topProducts;
  final Map<String, double> paymentMethodsBreakdown;

  const WeeklySalesSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.weekOffset,
    required this.totalRevenue,
    required this.totalProfit,
    required this.profitMarginPercent,
    required this.totalOrders,
    required this.totalItems,
    required this.averageDailyRevenue,
    this.bestDay,
    this.prevWeekRevenue,
    this.revenueGrowthPercent,
    required this.dailyPoints,
    required this.topProducts,
    required this.paymentMethodsBreakdown,
  });
}

class WeekOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void nextWeek() => state = state + 1;
  void prevWeek() => state = state - 1;
  void resetToThisWeek() => state = 0;
  void setOffset(int offset) => state = offset;
}

final selectedWeekOffsetProvider = NotifierProvider<WeekOffsetNotifier, int>(
  WeekOffsetNotifier.new,
);

class SelectedDayIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectDay(int? index) => state = index;
  void toggleDay(int index) => state = state == index ? null : index;
}

final selectedDayIndexProvider = NotifierProvider<SelectedDayIndexNotifier, int?>(
  SelectedDayIndexNotifier.new,
);

DateTime computeWeekStart(DateTime date, [int weekOffset = 0]) {
  final normalized = DateTime(date.year, date.month, date.day);
  final monday = normalized.subtract(Duration(days: normalized.weekday - 1));
  final target = monday.add(Duration(days: weekOffset * 7));
  return DateTime(target.year, target.month, target.day);
}

DateTime computeWeekEnd(DateTime weekStart) {
  return DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59, 999);
}

WeeklySalesSummary calculateWeeklySummary({
  required DateTime weekStart,
  required DateTime weekEnd,
  int weekOffset = 0,
  required List<Sale> sales,
  required List<SalesLedgerEntry> ledgerEntries,
  Map<String, double> productCostById = const {},
  Map<String, double> productCostByName = const {},
  double? priorWeekRevenue,
  DateTime? prevWeekStart,
  DateTime? prevWeekEnd,
}) {
  final pWeekStart = prevWeekStart ?? weekStart.subtract(const Duration(days: 7));
  final pWeekEnd = prevWeekEnd ?? computeWeekEnd(pWeekStart);

  const dayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const dayFullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final dailyRevenues = List<double>.filled(7, 0.0);
  final dailyProfits = List<double>.filled(7, 0.0);
  final dailyOrderCounts = List<int>.filled(7, 0);
  final dailyItemCounts = List<int>.filled(7, 0);

  final productQtyMap = <String, int>{};
  final productRevenueMap = <String, double>{};
  final productProfitMap = <String, double>{};
  final paymentBreakdown = <String, double>{};

  double totalRevenue = 0.0;
  double totalProfit = 0.0;
  int totalOrders = 0;
  int totalItems = 0;

  double calculatedPrevRevenue = priorWeekRevenue ?? 0.0;
  final bool shouldComputePrev = priorWeekRevenue == null;

  // Process POS sales
  for (final sale in sales) {
    final d = sale.saleDate;
    // Check previous week for comparison
    if (shouldComputePrev &&
        d.isAfter(pWeekStart.subtract(const Duration(milliseconds: 1))) &&
        d.isBefore(pWeekEnd.add(const Duration(milliseconds: 1)))) {
      calculatedPrevRevenue += sale.totalAmount;
    }

    // Check current selected week
    if (d.isAfter(weekStart.subtract(const Duration(milliseconds: 1))) &&
        d.isBefore(weekEnd.add(const Duration(milliseconds: 1)))) {
      final dayIndex = (d.weekday - 1).clamp(0, 6);
      dailyRevenues[dayIndex] += sale.totalAmount;
      dailyOrderCounts[dayIndex] += 1;
      totalRevenue += sale.totalAmount;
      totalOrders += 1;

      final method = sale.paymentMethod.trim().isNotEmpty
          ? sale.paymentMethod.trim()
          : 'Cash';
      paymentBreakdown[method] = (paymentBreakdown[method] ?? 0.0) + sale.totalAmount;

      for (final item in sale.items) {
        dailyItemCounts[dayIndex] += item.quantity;
        totalItems += item.quantity;

        final cost = (item.costPrice != null && item.costPrice! > 0)
            ? item.costPrice!
            : (productCostById[item.productId] ??
                productCostByName[item.productName.trim().toLowerCase()] ??
                0.0);
        final profit = (cost > 0) ? (item.unitPrice - cost) * item.quantity : 0.0;
        dailyProfits[dayIndex] += profit;
        totalProfit += profit;

        final pName = item.productName.trim().toUpperCase();
        productQtyMap[pName] = (productQtyMap[pName] ?? 0) + item.quantity;
        productRevenueMap[pName] =
            (productRevenueMap[pName] ?? 0.0) + (item.unitPrice * item.quantity);
        productProfitMap[pName] = (productProfitMap[pName] ?? 0.0) + profit;
      }
    }
  }

  // Process Sales Ledger entries (typeIndex == 1 is Sale)
  for (final e in ledgerEntries) {
    final d = e.date;
    if (e.typeIndex == 1) {
      if (shouldComputePrev &&
          d.isAfter(pWeekStart.subtract(const Duration(milliseconds: 1))) &&
          d.isBefore(pWeekEnd.add(const Duration(milliseconds: 1)))) {
        calculatedPrevRevenue += e.totalAmount;
      }

      if (d.isAfter(weekStart.subtract(const Duration(milliseconds: 1))) &&
          d.isBefore(weekEnd.add(const Duration(milliseconds: 1)))) {
        final dayIndex = (d.weekday - 1).clamp(0, 6);
        dailyRevenues[dayIndex] += e.totalAmount;
        dailyOrderCounts[dayIndex] += 1;
        totalRevenue += e.totalAmount;
        totalOrders += 1;

        final method = e.outItem?.trim().isNotEmpty == true ? e.outItem!.trim() : 'Sales Ledger';
        paymentBreakdown[method] = (paymentBreakdown[method] ?? 0.0) + e.totalAmount;

        final qty = (e.quantity ?? 1);
        dailyItemCounts[dayIndex] += qty;
        totalItems += qty;

        final cost = (e.costPrice != null && e.costPrice! > 0)
            ? e.costPrice!
            : (e.inItem != null
                ? (productCostByName[e.inItem!.trim().toLowerCase()] ?? 0.0)
                : 0.0);
        final unitPrice = e.price ?? (qty > 0 ? (e.totalAmount / qty) : e.totalAmount);
        final profit = (cost > 0) ? (unitPrice - cost) * qty : 0.0;
        dailyProfits[dayIndex] += profit;
        totalProfit += profit;

        if (e.inItem != null && e.inItem!.trim().isNotEmpty) {
          final pName = e.inItem!.trim().toUpperCase();
          productQtyMap[pName] = (productQtyMap[pName] ?? 0) + qty;
          productRevenueMap[pName] = (productRevenueMap[pName] ?? 0.0) + e.totalAmount;
          productProfitMap[pName] = (productProfitMap[pName] ?? 0.0) + profit;
        }
      }
    }
  }

  // Build daily points
  final dailyPoints = <DailySalesPoint>[];
  DailySalesPoint? bestDay;
  double maxDayRevenue = -1;

  for (int i = 0; i < 7; i++) {
    final dayDate = weekStart.add(Duration(days: i));
    final pt = DailySalesPoint(
      date: dayDate,
      dayName: dayShortNames[i],
      fullDayName: dayFullNames[i],
      revenue: dailyRevenues[i],
      profit: dailyProfits[i],
      orderCount: dailyOrderCounts[i],
      itemsCount: dailyItemCounts[i],
    );
    dailyPoints.add(pt);

    if (pt.revenue > maxDayRevenue && pt.revenue > 0) {
      maxDayRevenue = pt.revenue;
      bestDay = pt;
    }
  }

  // Rank top products
  final topProducts = productRevenueMap.entries.map((entry) {
    return ProductSalesRank(
      productName: entry.key,
      quantity: productQtyMap[entry.key] ?? 0,
      revenue: entry.value,
      profit: productProfitMap[entry.key] ?? 0.0,
    );
  }).toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final marginPercent = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
  final avgDaily = totalRevenue / 7.0;

  double? growthPercent;
  if (calculatedPrevRevenue > 0) {
    growthPercent = ((totalRevenue - calculatedPrevRevenue) / calculatedPrevRevenue) * 100;
  }

  return WeeklySalesSummary(
    weekStart: weekStart,
    weekEnd: weekEnd,
    weekOffset: weekOffset,
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    profitMarginPercent: marginPercent,
    totalOrders: totalOrders,
    totalItems: totalItems,
    averageDailyRevenue: avgDaily,
    bestDay: bestDay,
    prevWeekRevenue: calculatedPrevRevenue,
    revenueGrowthPercent: growthPercent,
    dailyPoints: dailyPoints,
    topProducts: topProducts.take(10).toList(),
    paymentMethodsBreakdown: paymentBreakdown,
  );
}

final weeklySalesProvider = Provider<WeeklySalesSummary>((ref) {
  final weekOffset = ref.watch(selectedWeekOffsetProvider);
  final sales = ref.watch(salesProvider).value ?? [];
  final ledgerEntries = ref.watch(salesLedgerEntriesProvider).value ?? [];
  final products = ref.watch(productsProvider).value ?? [];

  final productCostById = <String, double>{
    for (final p in products) p.id: p.costPrice,
  };
  final productCostByName = <String, double>{
    for (final p in products) p.name.trim().toLowerCase(): p.costPrice,
  };

  final now = DateTime.now();
  final weekStart = computeWeekStart(now, weekOffset);
  final weekEnd = computeWeekEnd(weekStart);
  final prevWeekStart = computeWeekStart(now, weekOffset - 1);
  final prevWeekEnd = computeWeekEnd(prevWeekStart);

  return calculateWeeklySummary(
    weekStart: weekStart,
    weekEnd: weekEnd,
    weekOffset: weekOffset,
    sales: sales,
    ledgerEntries: ledgerEntries,
    productCostById: productCostById,
    productCostByName: productCostByName,
    prevWeekStart: prevWeekStart,
    prevWeekEnd: prevWeekEnd,
  );
});
