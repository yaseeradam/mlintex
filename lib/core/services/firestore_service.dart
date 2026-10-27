import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/product_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/debt_model.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../presentation/receive/receive_screen.dart';
import '../../presentation/sales_ledger/sales_ledger_screen.dart';

class FirestoreService {
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static String get currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? '';
  }

  static String get activeShopId {
    try {
      if (Hive.isBoxOpen('auth')) {
        final box = Hive.box('auth');
        final id = box.get('active_shop_id', defaultValue: '1')?.toString() ?? '1';
        if (id.isNotEmpty && id != 'default') return id;
      }
    } catch (_) {}
    return '1';
  }

  static CollectionReference<Map<String, dynamic>> userCollection(String collectionName) {
    final uid = currentUserId;
    return db.collection('users').doc(uid).collection(collectionName);
  }

  /// Ensures a user is signed in to Firebase Auth with canonical credentials.
  static Future<User?> ensureAuthenticated({
    required String canonicalEmail,
    required String canonicalPassword,
  }) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: canonicalEmail,
        password: canonicalPassword,
      );
      return credential.user;
    } catch (e) {
      if (e is FirebaseAuthException &&
          (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'channel-error')) {
        try {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: canonicalEmail,
            password: canonicalPassword,
          );
          return credential.user;
        } catch (e2) {
          debugPrint('[FIRESTORE AUTH ERROR] Create user failed: $e2');
        }
      } else {
        debugPrint('[FIRESTORE AUTH ERROR] Sign in failed: $e');
      }
    }
    return FirebaseAuth.instance.currentUser;
  }

  /// One-time migration of any local Hive data into Firestore.
  static Future<void> migrateLocalHiveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    Box authBox;
    if (Hive.isBoxOpen('auth')) {
      authBox = Hive.box('auth');
    } else {
      authBox = await Hive.openBox('auth');
    }

    final isMigrated = authBox.get('hive_to_firestore_migrated', defaultValue: false) as bool;
    if (isMigrated) return;

    debugPrint('[MIGRATION] Checking for local Hive records to upload to Firestore for user: $uid...');

    final shopId = activeShopId;
    final targetShopIds = {shopId, '1'};

    for (final sId in targetShopIds) {
      // Products
      try {
        final boxName = 'products_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<ProductModel>(boxName)
              : await Hive.openBox<ProductModel>(boxName);
          for (final p in box.values) {
            final map = p.toMap();
            map['shopId'] = sId;
            map['updatedAt'] = p.updatedAt.toIso8601String();
            await db.collection('users').doc(uid).collection('products').doc(p.id).set(map, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Products: $e');
      }

      // Customers
      try {
        final boxName = 'customers_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<CustomerModel>(boxName)
              : await Hive.openBox<CustomerModel>(boxName);
          for (final c in box.values) {
            final map = c.toMap();
            map['shopId'] = sId;
            map['updatedAt'] = c.updatedAt.toIso8601String();
            await db.collection('users').doc(uid).collection('customers').doc(c.id).set(map, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Customers: $e');
      }

      // Shop Customers
      try {
        final boxName = 'shop_customers_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<CustomerModel>(boxName)
              : await Hive.openBox<CustomerModel>(boxName);
          for (final c in box.values) {
            final map = c.toMap();
            map['shopId'] = sId;
            map['updatedAt'] = c.updatedAt.toIso8601String();
            await db.collection('users').doc(uid).collection('shop_customers').doc(c.id).set(map, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Shop Customers: $e');
      }

      // Sales
      try {
        final boxName = 'sales_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<SaleModel>(boxName)
              : await Hive.openBox<SaleModel>(boxName);
          for (final s in box.values) {
            final map = s.toMap();
            map['shopId'] = sId;
            map['updatedAt'] = s.saleDate.toIso8601String();
            await db.collection('users').doc(uid).collection('sales').doc(s.id).set(map, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Sales: $e');
      }

      // Debts
      try {
        final boxName = 'debts_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<DebtModel>(boxName)
              : await Hive.openBox<DebtModel>(boxName);
          for (final d in box.values) {
            final map = d.toMap();
            map['shopId'] = sId;
            map['updatedAt'] = d.updatedAt.toIso8601String();
            await db.collection('users').doc(uid).collection('debts').doc(d.id).set(map, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Debts: $e');
      }

      // Ledger Entries
      try {
        final boxName = 'ledger_entries_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<LedgerEntry>(boxName)
              : await Hive.openBox<LedgerEntry>(boxName);
          for (final l in box.values) {
            await db.collection('users').doc(uid).collection('ledger_entries').doc(l.id).set({
              'id': l.id,
              'customerId': l.customerId,
              'date': l.date.toIso8601String(),
              'inItem': l.inItem,
              'outItem': l.outItem,
              'price': l.price,
              'quantity': l.quantity,
              'totalAmount': l.totalAmount,
              'runningBalance': l.runningBalance,
              'typeIndex': l.typeIndex,
              'shopId': sId,
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Ledger Entries: $e');
      }

      // Shop Ledger Entries
      try {
        final boxName = 'shop_ledger_entries_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<LedgerEntry>(boxName)
              : await Hive.openBox<LedgerEntry>(boxName);
          for (final l in box.values) {
            await db.collection('users').doc(uid).collection('shop_ledger_entries').doc(l.id).set({
              'id': l.id,
              'customerId': l.customerId,
              'date': l.date.toIso8601String(),
              'inItem': l.inItem,
              'outItem': l.outItem,
              'price': l.price,
              'quantity': l.quantity,
              'totalAmount': l.totalAmount,
              'runningBalance': l.runningBalance,
              'typeIndex': l.typeIndex,
              'shopId': sId,
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Shop Ledger Entries: $e');
      }

      // Receive Entries
      try {
        final boxName = 'receive_entries_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<ReceiveEntry>(boxName)
              : await Hive.openBox<ReceiveEntry>(boxName);
          for (final r in box.values) {
            await db.collection('users').doc(uid).collection('receive_entries').doc(r.id).set({
              'id': r.id,
              'date': r.date.toIso8601String(),
              'productName': r.productName,
              'companyName': r.companyName,
              'price': r.price,
              'quantity': r.quantity,
              'totalAmount': r.totalAmount,
              'payment': r.payment,
              'paymentDate': r.paymentDate?.toIso8601String(),
              'description': r.description,
              'shopId': sId,
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Receive Entries: $e');
      }

      // Sales Ledger Entries
      try {
        final boxName = 'sales_ledger_$sId';
        if (await Hive.boxExists(boxName)) {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box<SalesLedgerEntry>(boxName)
              : await Hive.openBox<SalesLedgerEntry>(boxName);
          for (final sl in box.values) {
            await db.collection('users').doc(uid).collection('sales_ledger').doc(sl.id).set({
              'id': sl.id,
              'date': sl.date.toIso8601String(),
              'inItem': sl.inItem,
              'outItem': sl.outItem,
              'price': sl.price,
              'quantity': sl.quantity,
              'totalAmount': sl.totalAmount,
              'runningBalance': sl.runningBalance,
              'typeIndex': sl.typeIndex,
              'personName': sl.personName,
              'payment': sl.payment,
              'paymentDate': sl.paymentDate?.toIso8601String(),
              'costPrice': sl.costPrice,
              'shopId': sId,
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MIGRATION] Sales Ledger: $e');
      }
    }

    await authBox.put('hive_to_firestore_migrated', true);
    debugPrint('[MIGRATION] Completed local Hive data migration to Firestore.');
  }
}
