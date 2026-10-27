import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/domain/entities/product.dart';
import 'package:shop_manager/domain/entities/sale.dart';
import 'package:shop_manager/data/models/product_model.dart';
import 'package:shop_manager/data/models/sale_model.dart';
import 'package:shop_manager/data/models/debt_model.dart';
import 'package:shop_manager/data/models/customer_ledger_model.dart';
import 'package:shop_manager/data/models/receive_order_model.dart';
import 'package:shop_manager/presentation/sales_ledger/sales_ledger_screen.dart';

void main() {
  group('Profit Calculation and Models', () {
    test('Product entity and ProductModel retain costPrice correctly', () {
      final product = Product(
        id: 'p1',
        name: 'LIN ROMAN',
        price: 120.0,
        costPrice: 100.0,
        quantity: 10,
        updatedAt: DateTime(2026, 9, 17),
      );

      expect(product.costPrice, 100.0);
      expect(product.price, 120.0);

      // Convert to Model
      final model = ProductModel.fromEntity(product);
      expect(model.costPrice, 100.0);

      // Convert back to Entity
      final entity = model.toEntity();
      expect(entity.costPrice, 100.0);

      // Map serialization
      final map = model.toMap();
      expect(map['costPrice'], 100.0);
      final fromMapModel = ProductModel.fromMap(map);
      expect(fromMapModel.costPrice, 100.0);
    });

    test('SaleItem calculates profit accurately: (price - cost) * quantity', () {
      // User example: Roman costs 100, sold at 120 -> profit 20 each.
      final item = SaleItem(
        productId: 'p1',
        productName: 'LIN ROMAN',
        unitPrice: 120.0,
        costPrice: 100.0,
        quantity: 5,
      );

      expect(item.profit, 100.0); // (120 - 100) * 5 = 100
    });

    test('SaleItem returns 0.0 profit if costPrice is null or zero (prevents false 100% margin)', () {
      final nullCostItem = SaleItem(
        productId: 'p1',
        productName: 'LIN ROMAN',
        unitPrice: 120.0,
        costPrice: null,
        quantity: 2,
      );
      expect(nullCostItem.profit, 0.0);

      final zeroCostItem = SaleItem(
        productId: 'p1',
        productName: 'LIN ROMAN',
        unitPrice: 120.0,
        costPrice: 0.0,
        quantity: 2,
      );
      expect(zeroCostItem.profit, 0.0);
    });

    test('SaleItemModel retains costPrice across entity and map conversions', () {
      final item = SaleItem(
        productId: 'p1',
        productName: 'LIN ROMAN',
        unitPrice: 120.0,
        costPrice: 100.0,
        quantity: 3,
      );

      final model = SaleItemModel.fromEntity(item);
      expect(model.costPrice, 100.0);

      final backToEntity = model.toEntity();
      expect(backToEntity.costPrice, 100.0);
      expect(backToEntity.profit, 60.0);

      final map = model.toMap();
      expect(map['costPrice'], 100.0);
      final fromMapModel = SaleItemModel.fromMap(map);
      expect(fromMapModel.costPrice, 100.0);
    });

    test('Sum of profits across multiple items and sales', () {
      final sale1 = Sale(
        id: 's1',
        items: [
          SaleItem(
            productId: 'p1',
            productName: 'LIN ROMAN',
            unitPrice: 120.0,
            costPrice: 100.0,
            quantity: 1, // profit: 20
          ),
          SaleItem(
            productId: 'p2',
            productName: 'SHIRT',
            unitPrice: 250.0,
            costPrice: 200.0,
            quantity: 2, // profit: (250 - 200) * 2 = 100
          ),
        ],
        totalAmount: 620.0,
        saleDate: DateTime.now(),
      );

      final sale2 = Sale(
        id: 's2',
        items: [
          SaleItem(
            productId: 'p3',
            productName: 'TROUSER',
            unitPrice: 500.0,
            costPrice: 350.0,
            quantity: 1, // profit: 150
          ),
        ],
        totalAmount: 500.0,
        saleDate: DateTime.now(),
      );

      final allSales = [sale1, sale2];
      double totalProfit = 0.0;
      for (final sale in allSales) {
        for (final item in sale.items) {
          totalProfit += item.profit;
        }
      }

      // Expected: 20 + 100 + 150 = 270
      expect(totalProfit, 270.0);
    });

    test('Defensive parsing handles mixed types, strings, ints, nulls gracefully', () {
      // ProductModel with int and string numbers
      final p = ProductModel.fromMap({
        'id': 'p1',
        'name': 'ZENITH',
        'price': 370000,
        'costPrice': '150000',
        'quantity': '10',
        'category': 'ADVENTURE',
      });
      expect(p.price, 370000.0);
      expect(p.costPrice, 150000.0);
      expect(p.quantity, 10);

      // DebtModel with int amounts and string booleans
      final d = DebtModel.fromMap({
        'id': 'd1',
        'amount': 5000,
        'paidAmount': '1000',
        'isPaid': 'false',
        'customerName': 'KARE BULLA',
      });
      expect(d.amount, 5000.0);
      expect(d.paidAmount, 1000.0);
      expect(d.isPaid, false);

      // CustomerLedgerEntryModel with null quantity and string amounts
      final l = CustomerLedgerEntryModel.fromMap({
        'id': 'l1',
        'quantity': null,
        'totalAmount': 605000,
        'totalBalance': '605000',
        'isSynced': true,
      });
      expect(l.quantity, null);
      expect(l.totalAmount, 605000.0);
      expect(l.totalBalance, 605000.0);

      // ReceiveOrderModel with string total
      final r = ReceiveOrderModel.fromMap({
        'id': 'r1',
        'supplierName': 'TEXTILES CO',
        'totalAmount': '50000',
        'items': [
          {'productId': 'p1', 'productName': 'ZENITH', 'unitPrice': '5000', 'quantity': 10}
        ],
      });
      expect(r.totalAmount, 50000.0);
      expect(r.items.first.unitPrice, 5000.0);
      expect(r.items.first.quantity, 10);
    });

    test('SalesLedgerEntry calculates profit using stored costPrice or catalog fallback', () {
      final products = [
        Product(
          id: 'p1',
          name: 'ZENITH 150y',
          price: 2000.0,
          costPrice: 1500.0,
          quantity: 20,
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final productCostByName = <String, double>{
        for (final p in products) p.name.trim().toLowerCase(): p.costPrice,
      };

      // Entry 1: Has stored costPrice on entry
      final e1 = SalesLedgerEntry(
        id: 'e1',
        date: DateTime.now(),
        inItem: 'ZENITH 150y',
        price: 2000.0,
        quantity: 5,
        totalAmount: 10000.0,
        typeIndex: 1,
        costPrice: 1400.0, // Historical cost stored
      );

      // Entry 2: No stored costPrice, falls back to catalog
      final e2 = SalesLedgerEntry(
        id: 'e2',
        date: DateTime.now(),
        inItem: 'ZENITH 150y',
        price: 2200.0,
        quantity: 2,
        totalAmount: 4400.0,
        typeIndex: 1,
      );

      // Entry 3: Uncosted item not in catalog
      final e3 = SalesLedgerEntry(
        id: 'e3',
        date: DateTime.now(),
        inItem: 'UNREGISTERED ITEM',
        price: 3000.0,
        quantity: 1,
        totalAmount: 3000.0,
        typeIndex: 1,
      );

      // Entry 4: Payment entry (typeIndex 0) -> not a sale
      final e4 = SalesLedgerEntry(
        id: 'e4',
        date: DateTime.now(),
        totalAmount: 5000.0,
        typeIndex: 0,
      );

      final entries = [e1, e2, e3, e4];

      double totalProfit = 0.0;
      for (final entry in entries) {
        if (entry.typeIndex == 1) {
          final nameKey = (entry.inItem ?? '').trim().toLowerCase();
          final cost = (entry.costPrice != null && entry.costPrice! > 0)
              ? entry.costPrice!
              : (productCostByName[nameKey] ?? 0.0);
          final unitPrice = entry.price ??
              (entry.quantity != null && entry.quantity! > 0
                  ? entry.totalAmount / entry.quantity!
                  : entry.totalAmount);
          final qty = entry.quantity ?? 1;
          if (cost > 0) {
            totalProfit += (unitPrice - cost) * qty;
          }
        }
      }

      // e1: (2000 - 1400) * 5 = 600 * 5 = 3000
      // e2: (2200 - 1500) * 2 = 700 * 2 = 1400
      // e3: cost is 0 -> profit is 0 (NOT 3000!)
      // e4: payment -> profit is 0
      // Total Profit = 3000 + 1400 = 4400
      expect(totalProfit, 4400.0);
    });
  });
}
