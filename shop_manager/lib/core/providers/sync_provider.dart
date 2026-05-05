import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/sync_service.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/customer_local_datasource.dart';
import '../../data/datasources/sale_local_datasource.dart';
import '../../data/datasources/debt_local_datasource.dart';
import 'repository_providers.dart';

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(productLocalDataSourceProvider),
    ref.watch(customerLocalDataSourceProvider),
    ref.watch(saleLocalDataSourceProvider),
    ref.watch(debtLocalDataSourceProvider),
  ),
);

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncServiceProvider).statusStream;
});
