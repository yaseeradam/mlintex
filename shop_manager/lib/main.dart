import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'data/models/product_model.dart';
import 'data/models/customer_model.dart';
import 'data/models/sale_model.dart';
import 'data/models/debt_model.dart';
import 'data/datasources/mock_data_seeder.dart';
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

  // Clear corrupted customer data if adapter changed
  final customerBox = await Hive.openBox<CustomerModel>('customers');
  if (customerBox.isNotEmpty) {
    final names = customerBox.values.map((c) => c.name).toSet();
    if (names.length == 1) await customerBox.clear(); // all same name = corrupted
  }

  // Ledger boxes
  Hive.registerAdapter(LedgerEntryAdapter());
  Hive.registerAdapter(ReceiveEntryAdapter());
  Hive.registerAdapter(SalesLedgerEntryAdapter());
  await Hive.openBox<LedgerEntry>('ledger_entries');
  await Hive.openBox<ReceiveEntry>('receive_entries');
  await Hive.openBox<SalesLedgerEntry>('sales_ledger');

  await NotificationService.init();

  final container = ProviderContainer();

  await container.read(mockSeederProvider).seedIfEmpty();

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
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'M Lin Tex',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
