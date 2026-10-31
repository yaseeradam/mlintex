import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/sync_service.dart';
import 'auth_provider.dart';
import '../../presentation/customers/customer_provider.dart';
import '../../presentation/shop/shop_customer_provider.dart';
import '../../presentation/dashboard/debt_provider.dart';
import '../../presentation/products/product_provider.dart';
import '../../presentation/sales/sale_provider.dart';
import '../../presentation/ledger/ledger_provider.dart';

final syncServiceProvider = Provider<SyncService>(
  (ref) {
    final service = SyncService(
      ref.watch(activeShopIdProvider),
    );

    service.onSyncCompleted = () {
      try {
        ref.invalidate(customersProvider);
        ref.invalidate(shopCustomersProvider);
        ref.invalidate(debtsProvider);
        ref.invalidate(overdueDebtsProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(salesProvider);
        ref.invalidate(customerLedgerBalancesProvider);
        ref.invalidate(shopLedgerBalancesProvider);
        ref.invalidate(totalOutstandingProvider);
      } catch (_) {}
    };

    return service;
  },
);

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});
