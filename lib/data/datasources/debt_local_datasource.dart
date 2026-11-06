import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt_model.dart';
import '../../core/services/firestore_service.dart';

class DebtLocalDataSource {
  static const String _collectionName = 'debts';

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreService.userCollection(_collectionName);

  String get _activeShopId => FirestoreService.activeShopId;

  bool _matchesShop(Map<String, dynamic> data) {
    final sId = data['shopId']?.toString();
    if (_activeShopId == '1') {
      return sId == null || sId == '1' || sId == 'default';
    }
    return sId == _activeShopId;
  }

  bool _firstFetchDone = false;

  Future<List<DebtModel>> getAllDebts() async {
    try {
      final source = (!_firstFetchDone && FirestoreService.isAuthReady)
          ? Source.server
          : Source.serverAndCache;
      _firstFetchDone = true;
      final snapshot = await _collection.get(GetOptions(source: source));
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => DebtModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      try {
        final snapshot = await _collection.get(const GetOptions(source: Source.cache));
        return snapshot.docs
            .where((doc) => _matchesShop(doc.data()))
            .map((doc) => DebtModel.fromMap(doc.data()))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<DebtModel>> getDebtsByCustomer(String customerId) async {
    final all = await getAllDebts();
    return all.where((d) => d.customerId == customerId).toList();
  }

  Future<void> saveDebt(DebtModel debt) async {
    final map = debt.toMap();
    map['shopId'] = _activeShopId;
    map['updatedAt'] = debt.updatedAt.toIso8601String();
    await _collection.doc(debt.id).set(map, SetOptions(merge: true));
  }

  Future<void> deleteDebt(String id) async {
    await _collection.doc(id).delete();
  }

  Stream<List<DebtModel>> watchDebts() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => DebtModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<DebtModel>> getUnsyncedDebts() async => [];
  Future<void> markAsSynced(String id) async {}
}
