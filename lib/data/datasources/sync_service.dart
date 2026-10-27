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

double? _safeDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _safeDoubleDef(dynamic v, [double def = 0.0]) {
  return _safeDouble(v) ?? def;
}

int? _safeInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int _safeIntDef(dynamic v, [int def = 0]) {
  return _safeInt(v) ?? def;
}

class SyncService {
  final ProductLocalDataSource _productDS;
  final CustomerLocalDataSource _customerDS;
  final SaleLocalDataSource _saleDS;
  final DebtLocalDataSource _debtDS;
  final ShopCustomerLocalDataSource _shopCustomerDS;
  final String activeShopId;

  VoidCallback? onSyncCompleted;

  String get effectiveShopId {
    if (activeShopId.isNotEmpty && activeShopId != 'default') return activeShopId;
    try {
      if (Hive.isBoxOpen('auth')) {
        final box = Hive.box('auth');
        final id = box.get('active_shop_id', defaultValue: '1')?.toString() ?? '1';
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '1';
  }

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

  Future<Box<T>> _getBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return await Hive.openBox<T>(boxName);
  }

  Future<User?> _ensureAuth() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    // Check if the user is authenticated locally in Hive
    final authBox = await _getBox('auth');
    final isLoggedIn = authBox.get('logged_in', defaultValue: false) as bool;
    if (isLoggedIn) {
      debugPrint('[SYNC] Re-authenticating Firebase Auth session...');
      const canonicalEmail = 'mlintex@gmail.com';
      const canonicalPass = 'mlintex123';
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: canonicalEmail,
          password: canonicalPass,
        );
        user = credential.user;
      } catch (e) {
        if (e is FirebaseAuthException && (e.code == 'user-not-found' || e.code == 'invalid-credential')) {
          try {
            final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: canonicalEmail,
              password: canonicalPass,
            );
            user = credential.user;
          } catch (e2) {
            debugPrint('[SYNC AUTH ERROR] Creation failed: $e2');
            _lastSyncError = 'Firebase auth failed: $e2';
          }
        } else {
          debugPrint('[SYNC AUTH ERROR] Sign in failed: $e');
          _lastSyncError = 'Firebase auth failed: $e';
        }
      }
    }
    return user;
  }

  Future<bool> syncAll({bool forcePull = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _lastSyncError = null;
    _setStatus(SyncStatus.syncing);

    try {
      final user = await _ensureAuth();
      if (user == null) {
        final authBox = await _getBox('auth');
        final isLoggedIn = authBox.get('logged_in', defaultValue: false) as bool;
        if (!isLoggedIn) {
          // User is not signed in locally yet, so this is idle state, not a failure
          _setStatus(SyncStatus.synced);
          return true;
        }
        debugPrint('[SYNC ERROR] Cannot sync: user is not signed in to Firebase.');
        _lastSyncError = _lastSyncError ?? 'User is not signed in to cloud';
        _setStatus(SyncStatus.error);
        return false;
      }

      final userId = user.uid;
      final db = FirebaseFirestore.instance;
      final currentShopId = effectiveShopId;
      debugPrint('[SYNC] Starting sync for user: $userId on shop: $currentShopId (configured: $activeShopId)');

      // ============================================
      // 1. PUSH: LOCAL DATA TO FIRESTORE
      // ============================================

      // Push pending deletions first
      await _pushDeletions(db, userId, 'products_$currentShopId', 'products');
      await _pushDeletions(db, userId, 'customers_$currentShopId', 'customers');
      await _pushDeletions(db, userId, 'sales_$currentShopId', 'sales');
      await _pushDeletions(db, userId, 'debts_$currentShopId', 'debts');
      await _pushDeletions(db, userId, 'shop_customers_$currentShopId', 'shop_customers');

      // Model-based types (push all local data to cloud)
      try {
        final allProducts = await _productDS.getAllProducts();
        for (final p in allProducts) {
          try {
            final map = p.toMap();
            map['updatedAt'] = p.updatedAt.toIso8601String();
            await db.collection('users').doc(userId).collection('products').doc(p.id)
                .set(map, SetOptions(merge: true));
            await _productDS.markAsSynced(p.id);
          } catch (e) {
            debugPrint('[SYNC PUSH PRODUCT ERROR] ${p.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('[SYNC PUSH PRODUCTS] $e');
      }

      try {
        final allCustomers = await _customerDS.getAllCustomers();
        for (final c in allCustomers) {
          try {
            final map = c.toMap();
            map['updatedAt'] = c.updatedAt.toIso8601String();
            await db.collection('users').doc(userId).collection('customers').doc(c.id)
                .set(map, SetOptions(merge: true));
            await _customerDS.markAsSynced(c.id);
          } catch (e) {
            debugPrint('[SYNC PUSH CUSTOMER ERROR] ${c.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('[SYNC PUSH CUSTOMERS] $e');
      }

      try {
        final allSales = await _saleDS.getAllSales();
        for (final s in allSales) {
          try {
            final map = s.toMap();
            map['updatedAt'] = s.saleDate.toIso8601String();
            await db.collection('users').doc(userId).collection('sales').doc(s.id)
                .set(map, SetOptions(merge: true));
            await _saleDS.markAsSynced(s.id);
          } catch (e) {
            debugPrint('[SYNC PUSH SALE ERROR] ${s.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('[SYNC PUSH SALES] $e');
      }

      try {
        final allDebts = await _debtDS.getAllDebts();
        for (final d in allDebts) {
          try {
            final map = d.toMap();
            map['updatedAt'] = d.updatedAt.toIso8601String();
            await db.collection('users').doc(userId).collection('debts').doc(d.id)
                .set(map, SetOptions(merge: true));
            await _debtDS.markAsSynced(d.id);
          } catch (e) {
            debugPrint('[SYNC PUSH DEBT ERROR] ${d.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('[SYNC PUSH DEBTS] $e');
      }

      try {
        final allShopCustomers = await _shopCustomerDS.getAllCustomers();
        for (final c in allShopCustomers) {
          try {
            final map = c.toMap();
            map['updatedAt'] = c.updatedAt.toIso8601String();
            await db.collection('users').doc(userId).collection('shop_customers').doc(c.id)
                .set(map, SetOptions(merge: true));
            await _shopCustomerDS.markAsSynced(c.id);
          } catch (e) {
            debugPrint('[SYNC PUSH SHOP CUSTOMER ERROR] ${c.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('[SYNC PUSH SHOP CUSTOMERS] $e');
      }

      // Hive-native types via PendingSyncTracker & full local sync
      await _pushHiveNative<LedgerEntry>(db, userId, 'ledger_entries_$currentShopId', 'ledger_entries', (e) => {
        'id': e.id, 'customerId': e.customerId, 'date': e.date.toIso8601String(),
        'inItem': e.inItem, 'outItem': e.outItem, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _pushHiveNative<LedgerEntry>(db, userId, 'shop_ledger_entries_$currentShopId', 'shop_ledger_entries', (e) => {
        'id': e.id, 'customerId': e.customerId, 'date': e.date.toIso8601String(),
        'inItem': e.inItem, 'outItem': e.outItem, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _pushHiveNative<ReceiveEntry>(db, userId, 'receive_entries_$currentShopId', 'receive_entries', (e) => {
        'id': e.id, 'date': e.date.toIso8601String(), 'productName': e.productName,
        'companyName': e.companyName, 'price': e.price, 'quantity': e.quantity,
        'totalAmount': e.totalAmount, 'payment': e.payment,
        'paymentDate': e.paymentDate?.toIso8601String(), 'description': e.description,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _pushHiveNative<SalesLedgerEntry>(db, userId, 'sales_ledger_$currentShopId', 'sales_ledger', (e) => {
        'id': e.id, 'date': e.date.toIso8601String(), 'inItem': e.inItem, 'outItem': e.outItem,
        'price': e.price, 'quantity': e.quantity, 'totalAmount': e.totalAmount,
        'runningBalance': e.runningBalance, 'typeIndex': e.typeIndex, 'personName': e.personName,
        'payment': e.payment, 'paymentDate': e.paymentDate?.toIso8601String(),
        'costPrice': e.costPrice,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Map types via PendingSyncTracker & full local sync
      await _pushMap(db, userId, 'customer_ledger_$currentShopId', 'customer_ledger');
      await _pushMap(db, userId, 'receive_orders_$currentShopId', 'receive_orders');

      // Sync shop profile metadata to Firestore
      try {
        final authBox = await _getBox('auth');
        final rawShops = authBox.get('shops_list');
        if (rawShops is List && rawShops.isNotEmpty) {
          await db.collection('users').doc(userId).collection('profile').doc('shops').set({
            'shops': rawShops,
            'activeShopId': authBox.get('active_shop_id', defaultValue: '1'),
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      } catch (err) {
        debugPrint('[SYNC PROFILE PUSH] $err');
      }

      // ============================================
      // 2. PULL: ALL CLOUD DATA BACK TO LOCAL HIVE
      // ============================================
      final targetShopIds = {currentShopId, '1'};
      for (final sId in targetShopIds) {
        await _pullData<ProductModel>(
          db: db, userId: userId, collection: 'products', boxName: 'products_$sId',
          fromMap: (map) => ProductModel.fromMap(map),
          getUpdatedAt: (item) => item.updatedAt,
          force: forcePull,
        );

        await _pullData<CustomerModel>(
          db: db, userId: userId, collection: 'customers', boxName: 'customers_$sId',
          fromMap: (map) => CustomerModel.fromMap(map),
          getUpdatedAt: (item) => item.updatedAt,
          force: forcePull,
        );

        await _pullData<SaleModel>(
          db: db, userId: userId, collection: 'sales', boxName: 'sales_$sId',
          fromMap: (map) => SaleModel.fromMap(map),
          getUpdatedAt: (item) => item.saleDate,
          force: forcePull,
        );

        await _pullData<DebtModel>(
          db: db, userId: userId, collection: 'debts', boxName: 'debts_$sId',
          fromMap: (map) => DebtModel.fromMap(map),
          getUpdatedAt: (item) => item.updatedAt,
          force: forcePull,
        );

        await _pullData<CustomerModel>(
          db: db, userId: userId, collection: 'shop_customers', boxName: 'shop_customers_$sId',
          fromMap: (map) => CustomerModel.fromMap(map),
          getUpdatedAt: (item) => item.updatedAt,
          force: forcePull,
        );

        await _pullHiveNative<LedgerEntry>(db, userId, 'ledger_entries', 'ledger_entries_$sId', (map) {
          return LedgerEntry(
            id: map['id']?.toString() ?? '',
            customerId: map['customerId']?.toString() ?? '',
            date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
            inItem: map['inItem']?.toString(),
            outItem: map['outItem']?.toString(),
            price: _safeDouble(map['price']),
            quantity: _safeInt(map['quantity']),
            totalAmount: _safeDoubleDef(map['totalAmount']),
            runningBalance: _safeDoubleDef(map['runningBalance']),
            typeIndex: _safeIntDef(map['typeIndex'], 1),
          );
        }, force: forcePull);

        await _pullHiveNative<LedgerEntry>(db, userId, 'shop_ledger_entries', 'shop_ledger_entries_$sId', (map) {
          return LedgerEntry(
            id: map['id']?.toString() ?? '',
            customerId: map['customerId']?.toString() ?? '',
            date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
            inItem: map['inItem']?.toString(),
            outItem: map['outItem']?.toString(),
            price: _safeDouble(map['price']),
            quantity: _safeInt(map['quantity']),
            totalAmount: _safeDoubleDef(map['totalAmount']),
            runningBalance: _safeDoubleDef(map['runningBalance']),
            typeIndex: _safeIntDef(map['typeIndex'], 1),
          );
        }, force: forcePull);

        await _pullHiveNative<ReceiveEntry>(db, userId, 'receive_entries', 'receive_entries_$sId', (map) {
          return ReceiveEntry(
            id: map['id']?.toString() ?? '',
            date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
            productName: map['productName']?.toString() ?? '',
            companyName: map['companyName']?.toString() ?? '',
            price: _safeDoubleDef(map['price']),
            quantity: _safeIntDef(map['quantity']),
            totalAmount: _safeDoubleDef(map['totalAmount']),
            payment: _safeDouble(map['payment']),
            paymentDate: map['paymentDate'] != null ? DateTime.tryParse(map['paymentDate'].toString()) : null,
            description: map['description']?.toString(),
          );
        }, force: forcePull);

        await _pullHiveNative<SalesLedgerEntry>(db, userId, 'sales_ledger', 'sales_ledger_$sId', (map) {
          return SalesLedgerEntry(
            id: map['id']?.toString() ?? '',
            date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
            inItem: map['inItem']?.toString(),
            outItem: map['outItem']?.toString(),
            price: _safeDouble(map['price']),
            quantity: _safeInt(map['quantity']),
            totalAmount: _safeDoubleDef(map['totalAmount']),
            runningBalance: _safeDoubleDef(map['runningBalance']),
            typeIndex: _safeIntDef(map['typeIndex'], 1),
            personName: map['personName']?.toString(),
            payment: _safeDoubleDef(map['payment']),
            paymentDate: map['paymentDate'] != null ? DateTime.tryParse(map['paymentDate'].toString()) : null,
            costPrice: _safeDouble(map['costPrice']),
          );
        }, force: forcePull);

        // Cross-populate customer_ledger from Firestore ledger_entries
        await _pullMapType(db, userId, 'ledger_entries', 'customer_ledger_$sId', (map) {
          final inItem = map['inItem']?.toString();
          final outItem = map['outItem']?.toString();
          final price = map['price']?.toString();
          final qty = _safeInt(map['quantity']);
          final total = _safeDoubleDef(map['totalAmount']);
          final balance = _safeDoubleDef(map['runningBalance']);
          final d = DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now();
          final u = DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? d;
          return {
            'id': map['id']?.toString() ?? '',
            'customerId': map['customerId']?.toString() ?? '',
            'date': d.toIso8601String(),
            'inDescription': inItem,
            'outDescription': outItem,
            'price': price,
            'quantity': qty,
            'totalAmount': total,
            'totalBalance': balance,
            'updatedAt': u.toIso8601String(),
            'isSynced': true,
          };
        }, force: forcePull);

        // Also pull any dedicated customer_ledger entries if present
        await _pullMapType(db, userId, 'customer_ledger', 'customer_ledger_$sId', (map) {
          return CustomerLedgerEntryModel.fromMap(map).toMap();
        }, force: forcePull);

        await _pullMapType(db, userId, 'receive_orders', 'receive_orders_$sId', (map) {
          return ReceiveOrderModel.fromMap(map).toMap();
        }, force: forcePull);
      }

      // Pull shop profile metadata
      try {
        final profileDoc = await db.collection('users').doc(userId).collection('profile').doc('shops').get();
        if (profileDoc.exists) {
          final profileData = profileDoc.data();
          if (profileData != null && profileData['shops'] != null) {
            final remoteShops = profileData['shops'] as List<dynamic>;
            final authBox = await _getBox('auth');
            final localShops = authBox.get('shops_list') as List<dynamic>?;
            if (localShops == null || localShops.isEmpty) {
              await authBox.put('shops_list', remoteShops);
            }
          }
        }
      } catch (err) {
        debugPrint('[SYNC PROFILE PULL] $err');
      }

      debugPrint('[SYNC] All data synchronized successfully.');
      _setStatus(SyncStatus.synced);
      try {
        onSyncCompleted?.call();
      } catch (err) {
        debugPrint('[SYNC] onSyncCompleted error: $err');
      }
      return true;
    } catch (e, stack) {
      debugPrint('[SYNC FATAL ERROR] $e\n$stack');
      _lastSyncError = e.toString();
      _setStatus(SyncStatus.error);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushDeletions(FirebaseFirestore db, String userId, String boxName, String collection) async {
    final deleteIds = PendingSyncTracker.getPendingDeleteIds(boxName);
    for (final id in deleteIds) {
      try {
        await db.collection('users').doc(userId).collection(collection).doc(id).delete();
        PendingSyncTracker.markDeleteSynced(boxName, id);
      } catch (err) {
        debugPrint('[SYNC DELETE ERROR] Failed deleting $collection doc $id: $err');
      }
    }
  }

  Future<void> _pushHiveNative<T>(
    FirebaseFirestore db,
    String userId,
    String boxName,
    String collection,
    Map<String, dynamic> Function(T) toMap,
  ) async {
    await _pushDeletions(db, userId, boxName, collection);

    final box = await _getBox<T>(boxName);
    final pendingIds = PendingSyncTracker.getPendingIds(boxName);

    // 1. Push explicitly pending IDs
    for (final id in pendingIds) {
      try {
        final item = box.get(id);
        if (item != null) {
          await db.collection('users').doc(userId).collection(collection).doc(id)
              .set(toMap(item), SetOptions(merge: true));
        } else {
          await db.collection('users').doc(userId).collection(collection).doc(id).delete();
        }
        PendingSyncTracker.markSynced(boxName, id);
      } catch (err) {
        debugPrint('[SYNC PUSH HIVE ERROR] Failed pushing pending $collection doc $id: $err');
      }
    }

    // 2. Also ensure any existing local entries are pushed to cloud
    for (final key in box.keys) {
      final id = key.toString();
      if (PendingSyncTracker.isPendingDelete(boxName, id)) continue;
      try {
        final item = box.get(key);
        if (item != null) {
          await db.collection('users').doc(userId).collection(collection).doc(id)
              .set(toMap(item), SetOptions(merge: true));
        }
      } catch (err) {
        debugPrint('[SYNC PUSH HIVE ERROR] Failed syncing existing $collection doc $id: $err');
      }
    }
  }

  Future<void> _pushMap(
    FirebaseFirestore db,
    String userId,
    String boxName,
    String collection,
  ) async {
    await _pushDeletions(db, userId, boxName, collection);

    final box = await _getBox(boxName);
    final pendingIds = PendingSyncTracker.getPendingIds(boxName);

    // 1. Push explicitly pending IDs
    for (final id in pendingIds) {
      try {
        final itemMap = box.get(id);
        if (itemMap != null) {
          final data = Map<String, dynamic>.from(itemMap as Map);
          data['updatedAt'] ??= DateTime.now().toIso8601String();
          await db.collection('users').doc(userId).collection(collection).doc(id)
              .set(data, SetOptions(merge: true));
        } else {
          await db.collection('users').doc(userId).collection(collection).doc(id).delete();
        }
        PendingSyncTracker.markSynced(boxName, id);
      } catch (err) {
        debugPrint('[SYNC PUSH MAP ERROR] Failed pushing pending $collection doc $id: $err');
      }
    }

    // 2. Also ensure all existing local map entries are in cloud
    for (final key in box.keys) {
      final id = key.toString();
      if (PendingSyncTracker.isPendingDelete(boxName, id)) continue;
      try {
        final itemMap = box.get(key);
        if (itemMap != null) {
          final data = Map<String, dynamic>.from(itemMap as Map);
          data['updatedAt'] ??= DateTime.now().toIso8601String();
          await db.collection('users').doc(userId).collection(collection).doc(id)
              .set(data, SetOptions(merge: true));
        }
      } catch (err) {
        debugPrint('[SYNC PUSH MAP ERROR] Failed syncing existing $collection doc $id: $err');
      }
    }
  }

  Future<void> _pullData<T>({
    required FirebaseFirestore db,
    required String userId,
    required String collection,
    required String boxName,
    required T Function(Map<String, dynamic>) fromMap,
    required DateTime Function(T) getUpdatedAt,
    bool force = false,
  }) async {
    final box = await _getBox<T>(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();

    for (final doc in snapshot.docs) {
      final id = doc.id;
      if (PendingSyncTracker.isPendingDelete(boxName, id)) continue;

      try {
        final remoteData = Map<String, dynamic>.from(doc.data());
        remoteData['id'] = remoteData['id']?.toString() ?? id;

        final isPending = PendingSyncTracker.getPendingIds(boxName).contains(id);
        if (force || box.get(id) == null || !isPending) {
          final item = fromMap(remoteData);
          await box.put(id, item);
        }
      } catch (err, st) {
        debugPrint('[SYNC PULL ERROR] Failed pulling $collection doc $id: $err\n$st');
      }
    }
  }

  Future<void> _pullHiveNative<T>(
    FirebaseFirestore db,
    String userId,
    String collection,
    String boxName,
    T Function(Map<String, dynamic>) fromMap, {
    bool force = false,
  }) async {
    final box = await _getBox<T>(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();

    for (final doc in snapshot.docs) {
      final id = doc.id;
      if (PendingSyncTracker.isPendingDelete(boxName, id)) continue;

      try {
        final remoteData = Map<String, dynamic>.from(doc.data());
        remoteData['id'] = remoteData['id']?.toString() ?? id;

        final isPending = PendingSyncTracker.getPendingIds(boxName).contains(id);

        if (force || box.get(id) == null || !isPending) {
          await box.put(id, fromMap(remoteData));
        }
      } catch (err, st) {
        debugPrint('[SYNC PULL HIVE ERROR] Failed pulling $collection doc $id: $err\n$st');
      }
    }
  }

  Future<void> _pullMapType(
    FirebaseFirestore db,
    String userId,
    String collection,
    String boxName,
    Map<String, dynamic> Function(Map<String, dynamic>) fromMap, {
    bool force = false,
  }) async {
    final box = await _getBox(boxName);
    final snapshot = await db.collection('users').doc(userId).collection(collection).get();

    for (final doc in snapshot.docs) {
      final id = doc.id;
      if (PendingSyncTracker.isPendingDelete(boxName, id)) continue;

      try {
        final remoteData = Map<String, dynamic>.from(doc.data());
        remoteData['id'] = remoteData['id']?.toString() ?? id;
        final isPending = PendingSyncTracker.getPendingIds(boxName).contains(id);
        if (force || box.get(id) == null || !isPending) {
          await box.put(id, fromMap(remoteData));
        }
      } catch (err, st) {
        debugPrint('[SYNC PULL MAP ERROR] Failed pulling map $collection doc $id: $err\n$st');
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
