import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp error: $e');
  }

  // Pre-authenticate canonical Firebase Auth and migrate legacy Hive records in background
  unawaited(
    FirestoreService.ensureAuthenticated(
      canonicalEmail: 'mlintex@gmail.com',
      canonicalPassword: 'mlintex123',
    ).then((_) async {
      try {
        await FirestoreService.migrateLocalHiveToFirestore();
      } catch (e) {
        debugPrint('Migration error: $e');
      }
    }).catchError((e) {
      debugPrint('Firebase Auth bootstrap error: $e');
    }),
  );

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
