import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../core/providers/repository_providers.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/sale_model.dart';
import '../models/debt_model.dart';
import '../../domain/entities/ledger_entry.dart';
import 'product_local_datasource.dart';
import 'customer_local_datasource.dart';
import 'sale_local_datasource.dart';
import 'debt_local_datasource.dart';

class MockDataSeeder {
  final ProductLocalDataSource _productDS;
  final CustomerLocalDataSource _customerDS;
  final SaleLocalDataSource _saleDS;
  final DebtLocalDataSource _debtDS;
  final _uuid = const Uuid();

  MockDataSeeder(this._productDS, this._customerDS, this._saleDS, this._debtDS);

  /// Seeds Hive with realistic retail mock data. Skips if data already exists.
  Future<void> seedIfEmpty() async {
    final existing = await _productDS.getAllProducts();
    
    // Check if the database contains the old generic/grocery mock data (e.g. beverages)
    final bool isOldGroceryData = existing.isNotEmpty && existing.any((p) => p.category == 'Beverages' || p.price < 50);
    
    if (isOldGroceryData) {
      // Clean up old data to allow a clean transition to premium textile items!
      for (final p in existing) {
        await _productDS.deleteProduct(p.id);
      }
      final customers = await _customerDS.getAllCustomers();
      for (final c in customers) {
        await _customerDS.deleteCustomer(c.id);
      }
      final sales = await _saleDS.getAllSales();
      for (final s in sales) {
        await _saleDS.deleteSale(s.id);
      }
      final debts = await _debtDS.getAllDebts();
      for (final d in debts) {
        await _debtDS.deleteDebt(d.id);
      }
    } else if (existing.isNotEmpty) {
      // Re-check customers — if they have corrupted names (e.g. all same name)
      // clear and re-seed customers only
      final customers = await _customerDS.getAllCustomers();
      if (customers.isNotEmpty) {
        final names = customers.map((c) => c.name).toSet();
        // If all customers have the same name, data is corrupted — re-seed
        if (names.length == 1) {
          for (final c in customers) {
            await _customerDS.deleteCustomer(c.id);
          }
          await _seedCustomers();
        }
      }
      // Seed ledger entries for existing customers if empty
      final currentCustomers = await _customerDS.getAllCustomers();
      await _seedLedger(currentCustomers);
      return;
    }

    await _seedProducts();
    final customers = await _seedCustomers();
    await _seedSales(customers);
    await _seedDebts(customers);
    await _seedLedger(customers);
  }

  Future<void> _seedLedger(List<CustomerModel> customers) async {
    final authBox = Hive.box('auth');
    final shopId = authBox.get('active_shop_id', defaultValue: '1') as String;
    final ledgerBox = Hive.box<LedgerEntry>('ledger_entries_$shopId');

    if (ledgerBox.isNotEmpty) return;

    CustomerModel? findCustomer(String name) {
      try {
        return customers.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();

    // 1. Amara Diallo (₦100,000 outstanding)
    final amara = findCustomer('Amara Diallo');
    if (amara != null) {
      final saleId = _uuid.v4();
      await ledgerBox.put(saleId, LedgerEntry(
        id: saleId,
        customerId: amara.id,
        date: now.subtract(const Duration(days: 3)),
        inItem: 'Swiss Voile Lace (Swiss Blue)',
        price: 45000,
        quantity: 4,
        totalAmount: 180000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
      final paymentId = _uuid.v4();
      await ledgerBox.put(paymentId, LedgerEntry(
        id: paymentId,
        customerId: amara.id,
        date: now.subtract(const Duration(days: 2)),
        outItem: 'Cash',
        totalAmount: 80000.0,
        typeIndex: LedgerEntryType.payment.index,
      ));
    }

    // 2. Fatimah Bello (₦85,000 outstanding)
    final fatimah = findCustomer('Fatimah Bello');
    if (fatimah != null) {
      final saleId = _uuid.v4();
      await ledgerBox.put(saleId, LedgerEntry(
        id: saleId,
        customerId: fatimah.id,
        date: now.subtract(const Duration(days: 8)),
        inItem: 'High Target Wax Ankara (Vibrant)',
        price: 8500,
        quantity: 10,
        totalAmount: 85000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
    }

    // 3. Chukwuemeka Obi (₦150,000 paid / ₦0 outstanding)
    final emeka = findCustomer('Chukwuemeka Obi');
    if (emeka != null) {
      final saleId = _uuid.v4();
      await ledgerBox.put(saleId, LedgerEntry(
        id: saleId,
        customerId: emeka.id,
        date: now.subtract(const Duration(days: 10)),
        inItem: 'Super Guinea Brocade (White)',
        price: 35000,
        quantity: 4,
        totalAmount: 140000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
      final extraSaleId = _uuid.v4();
      await ledgerBox.put(extraSaleId, LedgerEntry(
        id: extraSaleId,
        customerId: emeka.id,
        date: now.subtract(const Duration(days: 10)),
        inItem: 'Soft Polish Cotton (Sky Blue)',
        price: 5000,
        quantity: 2,
        totalAmount: 10000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
      final paymentId = _uuid.v4();
      await ledgerBox.put(paymentId, LedgerEntry(
        id: paymentId,
        customerId: emeka.id,
        date: now.subtract(const Duration(days: 1)),
        outItem: 'Bank Transfer',
        totalAmount: 150000.0,
        typeIndex: LedgerEntryType.payment.index,
      ));
    }

    // 4. Ngozi Adeyemi (₦95,000 outstanding)
    final ngozi = findCustomer('Ngozi Adeyemi');
    if (ngozi != null) {
      final saleId = _uuid.v4();
      await ledgerBox.put(saleId, LedgerEntry(
        id: saleId,
        customerId: ngozi.id,
        date: now.subtract(const Duration(days: 2)),
        inItem: 'Imperial Jacquard Brocade (Grey)',
        price: 40000,
        quantity: 2,
        totalAmount: 80000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
      final extraSaleId = _uuid.v4();
      await ledgerBox.put(extraSaleId, LedgerEntry(
        id: extraSaleId,
        customerId: ngozi.id,
        date: now.subtract(const Duration(days: 2)),
        inItem: 'Premium Royal Velvet (Burgundy)',
        price: 15000,
        quantity: 1,
        totalAmount: 15000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
    }

    // 5. Ibrahim Hassan (₦45,000 outstanding)
    final ibrahim = findCustomer('Ibrahim Hassan');
    if (ibrahim != null) {
      final saleId = _uuid.v4();
      await ledgerBox.put(saleId, LedgerEntry(
        id: saleId,
        customerId: ibrahim.id,
        date: now.subtract(const Duration(days: 5)),
        inItem: 'Premium Royal Velvet (Burgundy)',
        price: 15000,
        quantity: 3,
        totalAmount: 45000.0,
        typeIndex: LedgerEntryType.sale.index,
      ));
    }
  }


  // ─── Products ───────────────────────────────────────────────────────────────

  Future<void> _seedProducts() async {
    final items = [
      _product('Swiss Voile Lace (Swiss Blue)', 45000, 25, 'Lace'),
      _product('Heavy Beaded Cord Lace (Coral)', 65000, 12, 'Lace'),
      _product('French Organza Lace (Gold)', 38000, 18, 'Lace'),
      _product('Sequined Tulle Lace (Silver)', 28000, 30, 'Lace'),
      _product('Premium Vlisco Ankara (Classic)', 22000, 40, 'Ankara'),
      _product('High Target Wax Ankara (Vibrant)', 8500, 75, 'Ankara'),
      _product('Gold Metallic Ankara (Royal)', 12500, 50, 'Ankara'),
      _product('Da Viva Expression Wax (Teal)', 14000, 35, 'Ankara'),
      _product('Super Guinea Brocade (White)', 35000, 20, 'Brocade'),
      _product('Soft Cashmere Atiku (Navy)', 25000, 45, 'Atiku'),
      _product('Imperial Jacquard Brocade (Grey)', 40000, 15, 'Brocade'),
      _product('German Wool Atiku (Black)', 32000, 28, 'Atiku'),
      _product('Pure Mulberry Silk (Emerald)', 18000, 60, 'Silk'),
      _product('Premium Royal Velvet (Burgundy)', 15000, 40, 'Velvet'),
      _product('Floral Silk Chiffon (Multi)', 7500, 80, 'Chiffon'),
      _product('Crushed Silk Satin (Rose)', 9000, 100, 'Silk'),
      _product('Premium Wool Suiting (Charcoal)', 20000, 35, 'Wool'),
      _product('Soft Polish Cotton (Sky Blue)', 6000, 120, 'Cotton'),
      _product('Pure Italian Linen (Beige)', 16500, 50, 'Linen'),
      _product('Classic Crepe Fabric (Peach)', 5000, 150, 'Polyester'),
    ];
    for (final p in items) {
      await _productDS.saveProduct(p);
    }
  }

  // ─── Customers ──────────────────────────────────────────────────────────────

  Future<List<CustomerModel>> _seedCustomers() async {
    final list = [
      _customer('Amara Diallo', '+234 802 345 6789'),
      _customer('Fatimah Bello', '+234 803 456 7890'),
      _customer('Chukwuemeka Obi', '+234 804 567 8901'),
      _customer('Ngozi Adeyemi', '+234 805 678 9012'),
      _customer('Ibrahim Hassan', '+234 806 789 0123'),
      _customer('Blessing Eze', '+234 807 890 1234'),
      _customer('Taiwo Adebayo', '+234 808 901 2345'),
      _customer('Chiamaka Okafor', '+234 809 012 3456'),
    ];
    for (final c in list) {
      await _customerDS.saveCustomer(c);
    }
    return list;
  }

  // ─── Sales ──────────────────────────────────────────────────────────────────

  Future<void> _seedSales(List<CustomerModel> customers) async {
    final now = DateTime.now();
    final products = await _productDS.getAllProducts();
    if (products.isEmpty) return;

    // Today
    await _saleDS.saveSale(_sale([
      _item(products[0], 4), _item(products[2], 2), _item(products[12], 3),
    ], now.subtract(const Duration(hours: 1)), customers[0]));

    await _saleDS.saveSale(_sale([
      _item(products[5], 2), _item(products[6], 1), _item(products[10], 2),
    ], now.subtract(const Duration(hours: 2)), null));

    await _saleDS.saveSale(_sale([
      _item(products[15], 3), _item(products[16], 2),
    ], now.subtract(const Duration(hours: 3)), customers[2]));

    await _saleDS.saveSale(_sale([
      _item(products[18], 2), _item(products[19], 1), _item(products[20], 1),
    ], now.subtract(const Duration(hours: 5)), null));

    // Yesterday
    final yest = now.subtract(const Duration(days: 1));
    await _saleDS.saveSale(_sale([
      _item(products[0], 6), _item(products[1], 4), _item(products[3], 8),
    ], yest.subtract(const Duration(hours: 2)), customers[1]));

    await _saleDS.saveSale(_sale([
      _item(products[7], 3), _item(products[8], 2), _item(products[9], 4),
    ], yest.subtract(const Duration(hours: 6)), customers[3]));

    // Past 7 days
    for (int i = 2; i <= 7; i++) {
      final date = now.subtract(Duration(days: i));
      await _saleDS.saveSale(_sale([
        _item(products[i % products.length], 3 + i),
        _item(products[(i + 5) % products.length], 2),
      ], date, i % 3 == 0 ? customers[i % customers.length] : null));
    }
  }

  // ─── Debts ──────────────────────────────────────────────────────────────────

  Future<void> _seedDebts(List<CustomerModel> customers) async {
    final now = DateTime.now();
    final debts = [
      DebtModel(
        id: _uuid.v4(),
        customerId: customers[0].id,
        customerName: customers[0].name,
        amount: 180000.00,
        paidAmount: 80000.00,
        dueDate: now.add(const Duration(days: 5)),
        note: 'Swiss Voile Lace purchase balance',
        isPaid: false,
        updatedAt: now.subtract(const Duration(days: 3)),
        isSynced: true,
      ),
      DebtModel(
        id: _uuid.v4(),
        customerId: customers[1].id,
        customerName: customers[1].name,
        amount: 85000.00,
        paidAmount: 0,
        dueDate: now.subtract(const Duration(days: 2)),
        note: 'High Target Wax Ankara order',
        isPaid: false,
        updatedAt: now.subtract(const Duration(days: 8)),
        isSynced: true,
      ),
      DebtModel(
        id: _uuid.v4(),
        customerId: customers[2].id,
        customerName: customers[2].name,
        amount: 150000.00,
        paidAmount: 150000.00,
        dueDate: now.subtract(const Duration(days: 10)),
        note: 'Super Guinea Brocade fully settled',
        isPaid: true,
        updatedAt: now.subtract(const Duration(days: 1)),
        isSynced: true,
      ),
      DebtModel(
        id: _uuid.v4(),
        customerId: customers[3].id,
        customerName: customers[3].name,
        amount: 95000.00,
        paidAmount: 0,
        dueDate: now.add(const Duration(days: 12)),
        note: 'Imperial Jacquard Brocade order',
        isPaid: false,
        updatedAt: now.subtract(const Duration(days: 2)),
        isSynced: true,
      ),
      DebtModel(
        id: _uuid.v4(),
        customerId: customers[4].id,
        customerName: customers[4].name,
        amount: 45000.00,
        paidAmount: 0,
        dueDate: now.subtract(const Duration(days: 1)),
        note: 'Premium Royal Velvet yards balance',
        isPaid: false,
        updatedAt: now.subtract(const Duration(days: 5)),
        isSynced: true,
      ),
    ];
    for (final d in debts) {
      await _debtDS.saveDebt(d);
    }
  }

  // ─── Factory helpers ─────────────────────────────────────────────────────────

  ProductModel _product(String name, double price, int qty, String category) =>
      ProductModel(
        id: _uuid.v4(),
        name: name,
        price: price,
        quantity: qty,
        category: category,
        updatedAt: DateTime.now(),
        isSynced: true,
      );

  CustomerModel _customer(String name, String phone) =>
      CustomerModel(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        updatedAt: DateTime.now(),
        isSynced: true,
      );

  SaleItemModel _item(ProductModel product, int qty) =>
      SaleItemModel(
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
        quantity: qty,
      );

  SaleModel _sale(List<SaleItemModel> items, DateTime date, CustomerModel? c) {
    final total = items.fold<double>(0, (s, i) => s + i.unitPrice * i.quantity);
    return SaleModel(
      id: _uuid.v4(),
      items: items,
      totalAmount: total,
      customerId: c?.id,
      customerName: c?.name,
      saleDate: date,
      isSynced: true,
    );
  }
}

final mockSeederProvider = Provider<MockDataSeeder>((ref) => MockDataSeeder(
      ref.watch(productLocalDataSourceProvider),
      ref.watch(customerLocalDataSourceProvider),
      ref.watch(saleLocalDataSourceProvider),
      ref.watch(debtLocalDataSourceProvider),
    ));
