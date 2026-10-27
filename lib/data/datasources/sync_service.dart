import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../datasources/product_local_datasource.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/sale_local_datasource.dart';
import '../datasources/debt_local_datasource.dart';
import '../datasources/shop_customer_local_datasource.dart';
import '../../core/services/firestore_service.dart';

enum SyncStatus { synced, syncing, pending, error }

class SyncService {
  final ProductLocalDataSource _productDS;
  final CustomerLocalDataSource _customerDS;
  final SaleLocalDataSource _saleDS;
  final DebtLocalDataSource _debtDS;
  final ShopCustomerLocalDataSource _shopCustomerDS;
  final String activeShopId;

  VoidCallback? onSyncCompleted;

  String get effectiveShopId => FirestoreService.activeShopId;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncService(
    this._productDS,
    this._customerDS,
    this._saleDS,
    this._debtDS,
    this._shopCustomerDS,
    this.activeShopId,
  );

  void dispose() {
    _statusController.close();
  }

  bool _isSyncing = false;

  void _setStatus(SyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) {
      _statusController.add(s);
    }
  }

  Future<User?> _ensureAuth() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    const canonicalEmail = 'mlintex@gmail.com';
    const canonicalPass = 'mlintex123';
    return await FirestoreService.ensureAuthenticated(
      canonicalEmail: canonicalEmail,
      canonicalPassword: canonicalPass,
    );
  }

  Future<bool> syncAll({bool forcePull = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _lastSyncError = null;
    _setStatus(SyncStatus.syncing);

    try {
      final user = await _ensureAuth();
      if (user == null) {
        _lastSyncError = 'Not authenticated to cloud';
        _setStatus(SyncStatus.error);
        _isSyncing = false;
        return false;
      }

      // Ensure any legacy local Hive data is moved into Firestore
      await FirestoreService.migrateLocalHiveToFirestore();

      _setStatus(SyncStatus.synced);
      onSyncCompleted?.call();
      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint('[SYNC ERROR] $e');
      _lastSyncError = e.toString();
      _setStatus(SyncStatus.error);
      _isSyncing = false;
      return false;
    }
  }
}
