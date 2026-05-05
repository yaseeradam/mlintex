import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/sale_local_datasource.dart';
import '../datasources/debt_local_datasource.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/sale_model.dart';
import '../models/debt_model.dart';

enum SyncStatus { synced, syncing, pending, error }

class SyncService {
  final ProductLocalDataSource _productDS;
  final CustomerLocalDataSource _customerDS;
  final SaleLocalDataSource _saleDS;
  final DebtLocalDataSource _debtDS;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncService(
    this._productDS,
    this._customerDS,
    this._saleDS,
    this._debtDS,
  );

  void dispose() {
    _statusController.close();
  }

  Future<void> syncAll() async {
    _setStatus(SyncStatus.syncing);
    try {
      // In a real app, push unsynced items to Firestore here.
      // For now, we simulate a brief sync delay and mark all as synced.
      await Future.delayed(const Duration(seconds: 1));

      final unsyncedProducts = await _productDS.getUnsyncedProducts();
      for (final p in unsyncedProducts) {
        await _productDS.markAsSynced(p.id);
      }

      final unsyncedCustomers = await _customerDS.getUnsyncedCustomers();
      for (final c in unsyncedCustomers) {
        await _customerDS.markAsSynced(c.id);
      }

      // Sales and debts also would be synced here with Firestore
      _setStatus(SyncStatus.synced);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }

  Future<bool> hasPendingSync() async {
    final products = await _productDS.getUnsyncedProducts();
    if (products.isNotEmpty) return true;
    final customers = await _customerDS.getUnsyncedCustomers();
    if (customers.isNotEmpty) return true;
    final sales = await _saleDS.getUnsyncedSales();
    if (sales.isNotEmpty) return true;
    final debts = await _debtDS.getUnsyncedDebts();
    return debts.isNotEmpty;
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
