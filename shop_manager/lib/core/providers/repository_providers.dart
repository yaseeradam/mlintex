import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/customer_local_datasource.dart';
import '../../data/datasources/debt_local_datasource.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/sale_local_datasource.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/debt_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/sale_repository.dart';

// ─── Data Source Providers ───────────────────────────────────────────────────
final productLocalDataSourceProvider = Provider<ProductLocalDataSource>(
  (ref) => ProductLocalDataSource(),
);

final customerLocalDataSourceProvider = Provider<CustomerLocalDataSource>(
  (ref) => CustomerLocalDataSource(),
);

final saleLocalDataSourceProvider = Provider<SaleLocalDataSource>(
  (ref) => SaleLocalDataSource(),
);

final debtLocalDataSourceProvider = Provider<DebtLocalDataSource>(
  (ref) => DebtLocalDataSource(),
);

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
