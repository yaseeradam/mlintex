import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/domain/entities/product.dart';
import 'package:shop_manager/domain/entities/sale.dart';
import 'package:shop_manager/data/models/product_model.dart';
import 'package:shop_manager/data/models/sale_model.dart';

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

    test('SaleItem falls back to 0.0 costPrice if null', () {
      final legacyItem = SaleItem(
        productId: 'p1',
        productName: 'LIN ROMAN',
        unitPrice: 120.0,
        costPrice: null,
        quantity: 2,
      );

      // (120 - 0) * 2 = 240
      expect(legacyItem.profit, 240.0);
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
  });
}
