import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/product_local_datasource.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/sale_local_datasource.dart';
import '../datasources/debt_local_datasource.dart';

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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final db = FirebaseFirestore.instance;

        // 1. Sync Products
        final unsyncedProducts = await _productDS.getUnsyncedProducts();
        for (final p in unsyncedProducts) {
          await db
              .collection('users')
              .doc(userId)
              .collection('products')
              .doc(p.id)
              .set(p.toMap(), SetOptions(merge: true));
          await _productDS.markAsSynced(p.id);
        }

        // 2. Sync Customers
        final unsyncedCustomers = await _customerDS.getUnsyncedCustomers();
        for (final c in unsyncedCustomers) {
          await db
              .collection('users')
              .doc(userId)
              .collection('customers')
              .doc(c.id)
              .set(c.toMap(), SetOptions(merge: true));
          await _customerDS.markAsSynced(c.id);
        }

        // 3. Sync Sales
        final unsyncedSales = await _saleDS.getUnsyncedSales();
        for (final s in unsyncedSales) {
          await db
              .collection('users')
              .doc(userId)
              .collection('sales')
              .doc(s.id)
              .set(s.toMap(), SetOptions(merge: true));
          await _saleDS.markAsSynced(s.id);
        }

        // 4. Sync Debts
        final unsyncedDebts = await _debtDS.getUnsyncedDebts();
        for (final d in unsyncedDebts) {
          await db
              .collection('users')
              .doc(userId)
              .collection('debts')
              .doc(d.id)
              .set(d.toMap(), SetOptions(merge: true));
          await _debtDS.markAsSynced(d.id);
        }
      } else {
        // Local simulation if user not logged in via Firebase Auth yet
        await Future.delayed(const Duration(milliseconds: 600));
        final unsyncedProducts = await _productDS.getUnsyncedProducts();
        for (final p in unsyncedProducts) {
          await _productDS.markAsSynced(p.id);
        }
        final unsyncedCustomers = await _customerDS.getUnsyncedCustomers();
        for (final c in unsyncedCustomers) {
          await _customerDS.markAsSynced(c.id);
        }
      }

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
