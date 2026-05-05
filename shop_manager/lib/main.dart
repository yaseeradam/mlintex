import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/product_model.dart';
import 'data/models/customer_model.dart';
import 'data/models/sale_model.dart';
import 'data/models/debt_model.dart';
import 'data/datasources/mock_data_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(CustomerModelAdapter());
  Hive.registerAdapter(SaleItemModelAdapter());
  Hive.registerAdapter(SaleModelAdapter());
  Hive.registerAdapter(DebtModelAdapter());

  // Open auth box before runApp
  await Hive.openBox('auth');

  final container = ProviderContainer();

  // Run mock seeder if empty
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

    return MaterialApp.router(
      title: 'Shop Manager',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
