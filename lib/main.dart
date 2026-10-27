import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/firestore_service.dart';
import 'data/models/product_model.dart';
import 'data/models/customer_model.dart';
import 'data/models/sale_model.dart';
import 'data/models/debt_model.dart';
import 'domain/entities/ledger_entry.dart';
import 'presentation/receive/receive_screen.dart';
import 'presentation/sales_ledger/sales_ledger_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp error: $e');
  }

  // Pre-authenticate canonical Firebase Auth session so Firestore queries are ready immediately
  try {
    await FirestoreService.ensureAuthenticated(
      canonicalEmail: 'mlintex@gmail.com',
      canonicalPassword: 'mlintex123',
    );
  } catch (e) {
    debugPrint('Firebase Auth bootstrap error: $e');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(CustomerModelAdapter());
  Hive.registerAdapter(SaleItemModelAdapter());
  Hive.registerAdapter(SaleModelAdapter());
  Hive.registerAdapter(DebtModelAdapter());
  Hive.registerAdapter(LedgerEntryAdapter());
  Hive.registerAdapter(ReceiveEntryAdapter());
  Hive.registerAdapter(SalesLedgerEntryAdapter());

  await Hive.openBox('auth');
  await Hive.openBox('settings');

  final authBox = Hive.box('auth');
  final rawActiveShopId = authBox.get('active_shop_id', defaultValue: '1')?.toString() ?? '1';
  final activeShopId = (rawActiveShopId.isEmpty || rawActiveShopId == 'default') ? '1' : rawActiveShopId;
  await authBox.put('active_shop_id', activeShopId);

  await NotificationService.init();

  // One-time migration of any legacy Hive records into Firestore
  try {
    await FirestoreService.migrateLocalHiveToFirestore();
  } catch (e) {
    debugPrint('Migration error: $e');
  }

  runApp(
    const ProviderScope(
      child: ShopManagerApp(),
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
