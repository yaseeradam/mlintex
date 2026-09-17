import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../datasources/product_local_datasource.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/sale_local_datasource.dart';
import '../datasources/debt_local_datasource.dart';
import '../datasources/shop_customer_local_datasource.dart';
import '../../core/services/pending_sync_tracker.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../presentation/receive/receive_screen.dart';
import '../../presentation/sales_ledger/sales_ledger_screen.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/sale_model.dart';
import '../models/debt_model.dart';
import '../models/customer_ledger_model.dart';
import '../models/receive_order_model.dart';

enum SyncStatus { synced, syncing, pending, error }

class SyncService {
  final ProductLocalDataSource _productDS;
  final CustomerLocalDataSource _customerDS;
  final SaleLocalDataSource _saleDS;
  final DebtLocalDataSource _debtDS;
  final ShopCustomerLocalDataSource _shopCustomerDS;
  final String activeShopId;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

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

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        _setStatus(SyncStatus.synced);
        return;
      }

      final userId = user.uid;
      final db = FirebaseFirestore.instance;

      // ============================================
      // 1. PUSH: ALL UNSYNCED LOCAL DATA TO FIRESTORE
      // ============================================

      // Model-based types (using DataSources)
      final unsyncedProducts = await _productDS.getUnsyncedProducts();
      for (final p in unsyncedProducts) {
        await db.collection('users').doc(userId).collection('products').doc(p.id)
            .set(p.toMap(), SetOptions(merge: true));
        await _productDS.markAsSynced(p.id);
      }

      final unsyncedCustomers = await _customerDS.getUnsyncedCustomers();
      for (final c in unsyncedCustomers) {
        await db.collection('users').doc(userId).collection('customers').doc(c.id)
            .set(c.toMap(), SetOptions(merge: true));
        await _customerDS.markAsSynced(c.id);
      }

      final unsyncedSales = await _saleDS.getUnsyncedSales();
      for (final s in unsyncedSales) {
        await db.collection('users').doc(userId).collection('sales').doc(s.id)
            .set(s.toMap(), SetOptions(merge: true));
        await _saleDS.markAsSynced(s.id);
      }

      final unsyncedDebts = await _debtDS.getUnsyncedDebts();
      for (final d in unsyncedDebts) {
        await db.collection('users').doc(userId).collection('debts').doc(d.id)
            .set(d.toMap(), SetOptions(merge: true));
        await _debtDS.markAsSynced(d.id);
      }

      final unsyncedShopCustomers = await _shopCustomerDS.getUnsyncedCustomers();
      for (final c in unsyncedShopCustomers) {
        await db.collection('users').doc(userId).collection('shop_customers').doc(c.id)
            .set(c.toMap(), SetOptions(merge: true));
        await _shopCustomerDS.markAsSynced(c.id);
      }

      // Hive-native types via PendingSyncTracker
      await _pushHiveNative<LedgerEntry>(db, userId, 'ledger_entries_$activeShopId', 'ledger_entries', (e) => {
        'id': e.id, 'customerId': e.customerId, 'date': e.date.toIso8601String(),
        'inItem': e.inItem, 'outItem': e.outItem, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await _pushHiveNative<LedgerEntry>(db, userId, 'shop_ledger_entries_$activeShopId', 'shop_ledger_entries', (e) => {
        'id': e.id, 'customerId': e.customerId, 'date': e.date.toIso8601String(),
        'inItem': e.inItem, 'outItem': e.outItem, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await _pushHiveNative<ReceiveEntry>(db, userId, 'receive_entries_$activeShopId', 'receive_entries', (e) => {
        'id': e.id, 'date': e.date.toIso8601String(), 'productName': e.productName,
        'companyName': e.companyName, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'payment': e.payment,
        'paymentDate': e.paymentDate?.toIso8601String(), 'description': e.description,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await _pushHiveNative<SalesLedgerEntry>(db, userId, 'sales_ledger_$activeShopId', 'sales_ledger', (e) => {
        'id': e.id, 'date': e.date.toIso8601String(), 'inItem': e.inItem, 'outItem': e.outItem,
        'price': e.price, 'quantity': e.quantity, 'totalAmount': e.totalAmount,
        'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex, 'personName': e.personName,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Map types via PendingSyncTracker
      await _pushMap(db, userId, 'customer_ledger_$activeShopId', 'customer_ledger');
      await _pushMap(db, userId, 'receive_orders_$activeShopId', 'receive_orders');

      // ============================================
      // 2. PULL: ALL CLOUD DATA BACK TO LOCAL HIVE
      // ============================================
      await _pullData<ProductModel>(
        db: db, userId: userId, collection: 'products', boxName: 'products_$activeShopId',
        fromMap: (map) => ProductModel.fromMap(map),
        getUpdatedAt: (item) => item.updatedAt,
      );

      await _pullData<CustomerModel>(
        db: db, userId: userId, collection: 'customers', boxName: 'customers_$activeShopId',
        fromMap: (map) => CustomerModel.fromMap(map),
        getUpdatedAt: (item) => item.updatedAt,
      );

      await _pullData<SaleModel>(
        db: db, userId: userId, collection: 'sales', boxName: 'sales_$activeShopId',
        fromMap: (map) => SaleModel.fromMap(map),
        getUpdatedAt: (item) => item.saleDate,
      );

      await _pullData<DebtModel>(
        db: db, userId: userId, collection: 'debts', boxName: 'debts_$activeShopId',
        fromMap: (map) => DebtModel.fromMap(map),
        getUpdatedAt: (item) => item.updatedAt,
      );

      await _pullData<CustomerModel>(
        db: db, userId: userId, collection: 'shop_customers', boxName: 'shop_customers_$activeShopId',
        fromMap: (map) => CustomerModel.fromMap(map),
        getUpdatedAt: (item) => item.updatedAt,
      );

      await _pullHiveNative<LedgerEntry>(db, userId, 'ledger_entries', 'ledger_entries_$activeShopId', (map) {
        return LedgerEntry(
          id: map['id'], customerId: map['customerId'], date: DateTime.parse(map['date']),
          inItem: map['inItem'], outItem: map['outItem'], price: map['price'], quantity: map['quantity'],
          totalAmount: (map['totalAmount'] as num).toDouble(), runningBalance: (map['runningBalance'] as num).toDouble(), typeIndex: map['typeIndex'],
        );
      });

      await _pullHiveNative<LedgerEntry>(db, userId, 'shop_ledger_entries', 'shop_ledger_entries_$activeShopId', (map) {
        return LedgerEntry(
          id: map['id'], customerId: map['customerId'], date: DateTime.parse(map['date']),
          inItem: map['inItem'], outItem: map['outItem'], price: map['price'], quantity: map['quantity'],
          totalAmount: (map['totalAmount'] as num).toDouble(), runningBalance: (map['runningBalance'] as num).toDouble(), typeIndex: map['typeIndex'],
        );
      });

      await _pullHiveNative<ReceiveEntry>(db, userId, 'receive_entries', 'receive_entries_$activeShopId', (map) {
        return ReceiveEntry(
          id: map['id'], date: DateTime.parse(map['date']), productName: map['productName'],
          companyName: map['companyName'], price: (map['price'] as num).toDouble(), quantity: map['quantity'],
          totalAmount: (map['totalAmount'] as num).toDouble(), payment: map['payment'] != null ? (map['payment'] as num).toDouble() : null, 
          paymentDate: map['paymentDate'] != null ? DateTime.parse(map['paymentDate']) : null, 
          description: map['description'],
        );
      });

      await _pullHiveNative<SalesLedgerEntry>(db, userId, 'sales_ledger', 'sales_ledger_$activeShopId', (map) {
        return SalesLedgerEntry(
          id: map['id'], date: DateTime.parse(map['date']), inItem: map['inItem'], outItem: map['outItem'],
          price: map['price'] != null ? (map['price'] as num).toDouble() : null, quantity: map['quantity'], totalAmount: (map['totalAmount'] as num).toDouble(),
          runningBalance: (map['runningBalance'] as num).toDouble(), typeIndex: map['typeIndex'], personName: map['personName'],
        );
      });

      await _pullMapType(db, userId, 'customer_ledger', 'customer_ledger_$activeShopId', (map) {
        return CustomerLedgerEntryModel.fromMap(map).toMap();
      });

      await _pullMapType(db, userId, 'receive_orders', 'receive_orders_$activeShopId', (map) {
        return ReceiveOrderModel.fromMap(map).toMap();
      });

      _setStatus(SyncStatus.synced);
    } catch (e) {
      _setStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushHiveNative<T>(FirebaseFirestore db, String userId, String boxName, String collection, Map<String, dynamic> Function(T) toMap) async {
    final pendingIds = PendingSyncTracker.getPendingIds(boxName);
    if (pendingIds.isEmpty) return;

    final box = Hive.box<T>(boxName);
    for (final id in pendingIds) {
      final item = box.get(id);
      if (item != null) {
        await db.collection('users').doc(userId).collection(collection).doc(id)
            .set(toMap(item), SetOptions(merge: true));
      }
      PendingSyncTracker.markSynced(boxName, id);
    }
  }

  Future<void> _pushMap(FirebaseFirestore db, String userId, String boxName, String collection) async {
    final pendingIds = PendingSyncTracker.getPendingIds(boxName);
    if (pendingIds.isEmpty) return;

    final box = Hive.box(boxName);
    for (final id in pendingIds) {
      final itemMap = box.get(id);
      if (itemMap != null) {
        final data = Map<String, dynamic>.from(itemMap as Map);
        await db.collection('users').doc(userId).collection(collection).doc(id)
            .set(data, SetOptions(merge: true));
      }
      PendingSyncTracker.markSynced(boxName, id);
    }
  }

  Future<void> _pullData<T>({
    required FirebaseFirestore db,
    required String userId,
    required String collection,
    required String boxName,
    required T Function(Map<String, dynamic>) fromMap,
    required DateTime Function(T) getUpdatedAt,
  }) async {
    final box = Hive.box<T>(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();
    
    for (final doc in snapshot.docs) {
      final remoteData = doc.data();
      if (!remoteData.containsKey('updatedAt') || remoteData['updatedAt'] == null) continue;
      
      final remoteUpdatedAt = DateTime.parse(remoteData['updatedAt']);
      final id = doc.id;

      final localItem = box.get(id);
      if (localItem == null) {
        await box.put(id, fromMap(remoteData));
      } else {
        final localUpdatedAt = getUpdatedAt(localItem);
        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          await box.put(id, fromMap(remoteData));
        }
      }
    }
  }

  Future<void> _pullHiveNative<T>(FirebaseFirestore db, String userId, String collection, String boxName, T Function(Map<String, dynamic>) fromMap) async {
    final box = Hive.box<T>(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();
    
    for (final doc in snapshot.docs) {
      final remoteData = doc.data();
      final id = doc.id;
      final isPending = PendingSyncTracker.getPendingIds(boxName).contains(id);
      
      if (box.get(id) == null || !isPending) {
         await box.put(id, fromMap(remoteData));
      }
    }
  }

  Future<void> _pullMapType(FirebaseFirestore db, String userId, String collection, String boxName, Map<String, dynamic> Function(Map<String, dynamic>) fromMap) async {
    final box = Hive.box(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();
    
    for (final doc in snapshot.docs) {
      final remoteData = doc.data();
      if (!remoteData.containsKey('updatedAt') || remoteData['updatedAt'] == null) continue;
      
      final remoteUpdatedAt = DateTime.parse(remoteData['updatedAt']);
      final id = doc.id;

      final localItemMap = box.get(id);
      if (localItemMap == null) {
        await box.put(id, fromMap(remoteData));
      } else {
        final localData = Map<String, dynamic>.from(localItemMap as Map);
        final localUpdatedAtStr = localData['updatedAt'];
        if (localUpdatedAtStr != null) {
           final localUpdatedAt = DateTime.parse(localUpdatedAtStr);
           if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
             await box.put(id, fromMap(remoteData));
           }
        } else {
           await box.put(id, fromMap(remoteData));
        }
      }
    }
  }

  Future<bool> hasPendingSync() async {
    if (PendingSyncTracker.hasPending()) return true;

    final products = await _productDS.getUnsyncedProducts();
    if (products.isNotEmpty) return true;
    final customers = await _customerDS.getUnsyncedCustomers();
    if (customers.isNotEmpty) return true;
    final sales = await _saleDS.getUnsyncedSales();
    if (sales.isNotEmpty) return true;
    final debts = await _debtDS.getUnsyncedDebts();
    if (debts.isNotEmpty) return true;
    final shopCustomers = await _shopCustomerDS.getUnsyncedCustomers();
    return shopCustomers.isNotEmpty;
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
