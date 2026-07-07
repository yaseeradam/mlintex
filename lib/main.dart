import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'data/models/product_model.dart';
import 'data/models/customer_model.dart';
import 'data/models/sale_model.dart';
import 'data/models/debt_model.dart';
import 'domain/entities/ledger_entry.dart';
import 'presentation/receive/receive_screen.dart';
import 'presentation/sales_ledger/sales_ledger_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(CustomerModelAdapter());
  Hive.registerAdapter(SaleItemModelAdapter());
  Hive.registerAdapter(SaleModelAdapter());
  Hive.registerAdapter(DebtModelAdapter());

  await Hive.openBox('auth');
  await Hive.openBox('settings');

  final authBox = Hive.box('auth');
  final activeShopId = authBox.get('active_shop_id', defaultValue: '1') as String;

  // Shop-specific boxes
  await Hive.openBox<ProductModel>('products_$activeShopId');

  // Clear corrupted customer data if adapter changed
  final customerBox = await Hive.openBox<CustomerModel>('customers_$activeShopId');
  if (customerBox.isNotEmpty) {
    final names = customerBox.values.map((c) => c.name).toSet();
    if (names.length == 1) await customerBox.clear(); // all same name = corrupted
  }

  await Hive.openBox<DebtModel>('debts_$activeShopId');
  await Hive.openBox<SaleModel>('sales_$activeShopId');
  await Hive.openBox('customer_ledger_$activeShopId');
  await Hive.openBox('receive_orders_$activeShopId');

  // Ledger boxes
  Hive.registerAdapter(LedgerEntryAdapter());
  Hive.registerAdapter(ReceiveEntryAdapter());
  Hive.registerAdapter(SalesLedgerEntryAdapter());
  await Hive.openBox<LedgerEntry>('ledger_entries_$activeShopId');
  await Hive.openBox<LedgerEntry>('shop_ledger_entries_$activeShopId');
  await Hive.openBox<ReceiveEntry>('receive_entries_$activeShopId');
  await Hive.openBox<SalesLedgerEntry>('sales_ledger_$activeShopId');

  await NotificationService.init();

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ShopManagerApp(),
    ),
  );
}

class ShopManagerApp extends ConsumerWidget {
  const ShopManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'M Lin Tex',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
