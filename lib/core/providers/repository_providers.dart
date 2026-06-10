import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/customer_local_datasource.dart';
import '../../data/datasources/debt_local_datasource.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/sale_local_datasource.dart';
import '../../data/datasources/receive_order_local_datasource.dart';
import '../../data/datasources/customer_ledger_local_datasource.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/debt_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../data/repositories/receive_order_repository_impl.dart';
import '../../data/repositories/customer_ledger_repository_impl.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/receive_order_repository.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import 'auth_provider.dart';

// ─── Data Source Providers ───────────────────────────────────────────────────
final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return ProductLocalDataSource();
});

final customerLocalDataSourceProvider = Provider<CustomerLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return CustomerLocalDataSource();
});

final saleLocalDataSourceProvider = Provider<SaleLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return SaleLocalDataSource();
});

final debtLocalDataSourceProvider = Provider<DebtLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return DebtLocalDataSource();
});

// ─── Repository Providers ─────────────────────────────────────────────────────
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.watch(productLocalDataSourceProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepositoryImpl(ref.watch(customerLocalDataSourceProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepositoryImpl(ref.watch(saleLocalDataSourceProvider)),
);

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepositoryImpl(ref.watch(debtLocalDataSourceProvider)),
);

// ─── Receive Orders ───────────────────────────────────────────────────────────
final receiveOrderLocalDataSourceProvider = Provider<ReceiveOrderLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return ReceiveOrderLocalDataSource();
});

final receiveOrderRepositoryProvider = Provider<ReceiveOrderRepository>(
  (ref) => ReceiveOrderRepositoryImpl(
      ref.watch(receiveOrderLocalDataSourceProvider)),
);

// ─── Customer Ledger ──────────────────────────────────────────────────────────
final customerLedgerLocalDataSourceProvider = Provider<CustomerLedgerLocalDataSource>((ref) {
  ref.watch(activeShopIdProvider);
  return CustomerLedgerLocalDataSource();
});

final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>(
  (ref) => CustomerLedgerRepositoryImpl(
      ref.watch(customerLedgerLocalDataSourceProvider)),
);
