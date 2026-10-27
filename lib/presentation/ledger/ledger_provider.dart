import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/providers/repository_providers.dart';
import '../products/product_provider.dart';

LedgerEntry _fromMap(Map<String, dynamic> map) {
  final rawPrice = map['price'];
  final price = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '');

  final rawQty = map['quantity'];
  final quantity = (rawQty is num) ? rawQty.toInt() : int.tryParse(rawQty?.toString() ?? '');

  final rawTotal = map['totalAmount'];
  final totalAmount = (rawTotal is num) ? rawTotal.toDouble() : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0);

  final rawBal = map['runningBalance'];
  final runningBalance = (rawBal is num) ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '') ?? 0.0);

  final rawType = map['typeIndex'];
  final typeIndex = (rawType is num) ? rawType.toInt() : (int.tryParse(rawType?.toString() ?? '') ?? 1);

  return LedgerEntry(
    id: map['id']?.toString() ?? '',
    customerId: map['customerId']?.toString() ?? '',
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    inItem: map['inItem']?.toString(),
    outItem: map['outItem']?.toString(),
    price: price,
    quantity: quantity,
    totalAmount: totalAmount,
    runningBalance: runningBalance,
    typeIndex: typeIndex,
  );
}

Map<String, dynamic> _toMap(LedgerEntry e, String shopId) {
  return {
    'id': e.id,
    'customerId': e.customerId,
    'date': e.date.toIso8601String(),
    'inItem': e.inItem,
    'outItem': e.outItem,
    'price': e.price,
    'quantity': e.quantity,
    'totalAmount': e.totalAmount,
    'runningBalance': e.runningBalance,
    'typeIndex': e.typeIndex,
    'shopId': shopId,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

List<LedgerEntry> computeLedgerBalances(List<LedgerEntry> entries) {
  final list = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (final e in list) {
    if (e.type == LedgerEntryType.sale) {
      balance += e.totalAmount;
    } else {
      balance -= e.totalAmount;
    }
    e.runningBalance = balance;
  }
  return list;
}

List<LedgerEntry> entriesFor(dynamic boxOrList, String customerId) {
  final Iterable<LedgerEntry> source = boxOrList is Iterable<LedgerEntry>
      ? boxOrList
      : (boxOrList.values as Iterable).cast<LedgerEntry>();
  final filtered = source.where((e) => e.customerId == customerId).toList();
  return computeLedgerBalances(filtered);
}

// --- Customer Ledger Providers ---
final customerLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) {
  final shopId = ref.watch(activeShopIdProvider);
  final col = FirestoreService.userCollection('ledger_entries');

  return col.snapshots().map((snapshot) {
    final entries = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final sId = data['shopId']?.toString();
          final matchesShop =
              shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
          return matchesShop && data['customerId']?.toString() == customerId;
        })
        .map((doc) => _fromMap(doc.data()))
        .toList();

    return computeLedgerBalances(entries);
  });
});

final customerLedgerBalancesProvider = StreamProvider<Map<String, double>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  final col = FirestoreService.userCollection('ledger_entries');

  return col.snapshots().map((snapshot) {
    final balances = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final sId = data['shopId']?.toString();
      final matchesShop =
          shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
      if (!matchesShop) continue;

      final cid = data['customerId']?.toString() ?? '';
      final rawAmount = data['totalAmount'];
      final amount =
          (rawAmount is num) ? rawAmount.toDouble() : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);
      final rawType = data['typeIndex'];
      final typeIndex =
          (rawType is num) ? rawType.toInt() : (int.tryParse(rawType?.toString() ?? '') ?? 1);
      final isSale = typeIndex == LedgerEntryType.sale.index;

      balances[cid] = (balances[cid] ?? 0.0) + (isSale ? amount : -amount);
    }
    return balances;
  });
});

// --- Shop Ledger Providers ---
final shopLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) {
  final shopId = ref.watch(activeShopIdProvider);
  final col = FirestoreService.userCollection('shop_ledger_entries');

  return col.snapshots().map((snapshot) {
    final entries = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final sId = data['shopId']?.toString();
          final matchesShop =
              shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
          return matchesShop && data['customerId']?.toString() == customerId;
        })
        .map((doc) => _fromMap(doc.data()))
        .toList();

    return computeLedgerBalances(entries);
  });
});

final shopLedgerBalancesProvider = StreamProvider<Map<String, double>>((ref) {
  final shopId = ref.watch(activeShopIdProvider);
  final col = FirestoreService.userCollection('shop_ledger_entries');

  return col.snapshots().map((snapshot) {
    final balances = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final sId = data['shopId']?.toString();
      final matchesShop =
          shopId == '1' ? (sId == null || sId == '1' || sId == 'default') : sId == shopId;
      if (!matchesShop) continue;

      final cid = data['customerId']?.toString() ?? '';
      final rawAmount = data['totalAmount'];
      final amount =
          (rawAmount is num) ? rawAmount.toDouble() : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);
      final rawType = data['typeIndex'];
      final typeIndex =
          (rawType is num) ? rawType.toInt() : (int.tryParse(rawType?.toString() ?? '') ?? 1);
      final isSale = typeIndex == LedgerEntryType.sale.index;

      balances[cid] = (balances[cid] ?? 0.0) + (isSale ? amount : -amount);
    }
    return balances;
  });
});

class CustomerLedgerNotifier extends Notifier<void> {
  @override
  void build() {}

  final _uuid = const Uuid();
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreService.userCollection('ledger_entries');
  String get _shopId => FirestoreService.activeShopId;

  Future<void> addSaleEntry({
    required String customerId,
    required String itemName,
    required double price,
    required int quantity,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: itemName,
      price: price,
      quantity: quantity,
      totalAmount: price * quantity,
      typeIndex: LedgerEntryType.sale.index,
    );

    await _collection.doc(entry.id).set(_toMap(entry, _shopId), SetOptions(merge: true));

    // Automatically deduct store product stock if matching product exists
    try {
      final allProds = await ref.read(productRepositoryProvider).getAllProducts();
      final matches = allProds.where(
        (p) => p.name.trim().toLowerCase() == itemName.trim().toLowerCase(),
      );
      if (matches.isNotEmpty) {
        await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, -quantity);
      }
    } catch (_) {}
  }

  Future<void> addPaymentEntry({
    required String customerId,
    required String bankOrCash,
    required double amount,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: null,
      outItem: bankOrCash,
      price: amount,
      quantity: null,
      totalAmount: amount,
      typeIndex: LedgerEntryType.payment.index,
    );

    await _collection.doc(entry.id).set(_toMap(entry, _shopId), SetOptions(merge: true));
  }

  Future<void> updateEntry(LedgerEntry updated) async {
    final docRef = _collection.doc(updated.id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromMap(oldDoc.data()!);
      if (old.type == LedgerEntryType.sale && updated.type == LedgerEntryType.sale) {
        final oldQty = old.quantity ?? 0;
        final newQty = updated.quantity ?? 0;
        final delta = newQty - oldQty;
        final itemName = updated.inItem ?? old.inItem;
        if (delta != 0 && itemName != null && itemName.trim().isNotEmpty) {
          try {
            final allProds = await ref.read(productRepositoryProvider).getAllProducts();
            final matches = allProds.where(
              (p) => p.name.trim().toLowerCase() == itemName.trim().toLowerCase(),
            );
            if (matches.isNotEmpty) {
              await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, -delta);
            }
          } catch (_) {}
        }
      }
    }

    await docRef.set(_toMap(updated, _shopId), SetOptions(merge: true));
  }

  Future<void> deleteEntry(String id) async {
    final docRef = _collection.doc(id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromMap(oldDoc.data()!);
      if (old.type == LedgerEntryType.sale && (old.quantity ?? 0) > 0 && old.inItem != null) {
        try {
          final allProds = await ref.read(productRepositoryProvider).getAllProducts();
          final matches = allProds.where(
            (p) => p.name.trim().toLowerCase() == old.inItem!.trim().toLowerCase(),
          );
          if (matches.isNotEmpty) {
            await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, old.quantity!);
          }
        } catch (_) {}
      }
    }
    await docRef.delete();
  }
}

final customerLedgerNotifierProvider =
    NotifierProvider<CustomerLedgerNotifier, void>(CustomerLedgerNotifier.new);

class ShopLedgerNotifier extends Notifier<void> {
  @override
  void build() {}

  final _uuid = const Uuid();
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreService.userCollection('shop_ledger_entries');
  String get _shopId => FirestoreService.activeShopId;

  Future<void> addSaleEntry({
    required String customerId,
    required String itemName,
    required double price,
    required int quantity,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: itemName,
      price: price,
      quantity: quantity,
      totalAmount: price * quantity,
      typeIndex: LedgerEntryType.sale.index,
    );

    await _collection.doc(entry.id).set(_toMap(entry, _shopId), SetOptions(merge: true));

    // Automatically deduct store product stock if matching product exists
    try {
      final allProds = await ref.read(productRepositoryProvider).getAllProducts();
      final matches = allProds.where(
        (p) => p.name.trim().toLowerCase() == itemName.trim().toLowerCase(),
      );
      if (matches.isNotEmpty) {
        await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, -quantity);
      }
    } catch (_) {}
  }

  Future<void> addPaymentEntry({
    required String customerId,
    required String bankOrCash,
    required double amount,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      date: DateTime.now(),
      inItem: null,
      outItem: bankOrCash,
      price: amount,
      quantity: null,
      totalAmount: amount,
      typeIndex: LedgerEntryType.payment.index,
    );

    await _collection.doc(entry.id).set(_toMap(entry, _shopId), SetOptions(merge: true));
  }

  Future<void> updateEntry(LedgerEntry updated) async {
    final docRef = _collection.doc(updated.id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromMap(oldDoc.data()!);
      if (old.type == LedgerEntryType.sale && updated.type == LedgerEntryType.sale) {
        final oldQty = old.quantity ?? 0;
        final newQty = updated.quantity ?? 0;
        final delta = newQty - oldQty;
        final itemName = updated.inItem ?? old.inItem;
        if (delta != 0 && itemName != null && itemName.trim().isNotEmpty) {
          try {
            final allProds = await ref.read(productRepositoryProvider).getAllProducts();
            final matches = allProds.where(
              (p) => p.name.trim().toLowerCase() == itemName.trim().toLowerCase(),
            );
            if (matches.isNotEmpty) {
              await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, -delta);
            }
          } catch (_) {}
        }
      }
    }

    await docRef.set(_toMap(updated, _shopId), SetOptions(merge: true));
  }

  Future<void> deleteEntry(String id) async {
    final docRef = _collection.doc(id);
    final oldDoc = await docRef.get();
    if (oldDoc.exists && oldDoc.data() != null) {
      final old = _fromMap(oldDoc.data()!);
      if (old.type == LedgerEntryType.sale && (old.quantity ?? 0) > 0 && old.inItem != null) {
        try {
          final allProds = await ref.read(productRepositoryProvider).getAllProducts();
          final matches = allProds.where(
            (p) => p.name.trim().toLowerCase() == old.inItem!.trim().toLowerCase(),
          );
          if (matches.isNotEmpty) {
            await ref.read(productNotifierProvider.notifier).updateQuantity(matches.first.id, old.quantity!);
          }
        } catch (_) {}
      }
    }
    await docRef.delete();
  }
}

final shopLedgerNotifierProvider =
    NotifierProvider<ShopLedgerNotifier, void>(ShopLedgerNotifier.new);
