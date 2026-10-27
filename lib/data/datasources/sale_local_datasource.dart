import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_model.dart';
import '../../core/services/firestore_service.dart';

class SaleLocalDataSource {
  static const String _collectionName = 'sales';

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

  Future<List<SaleModel>> getAllSales() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => SaleModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSale(SaleModel sale) async {
    final map = sale.toMap();
    map['shopId'] = _activeShopId;
    map['updatedAt'] = sale.saleDate.toIso8601String();
    await _collection.doc(sale.id).set(map, SetOptions(merge: true));
  }

  Future<void> deleteSale(String id) async {
    await _collection.doc(id).delete();
  }

  Stream<List<SaleModel>> watchSales() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => SaleModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<SaleModel>> getUnsyncedSales() async => [];

  Future<List<SaleModel>> getSalesByDateRange(DateTime start, DateTime end) async {
    final all = await getAllSales();
    return all.where((s) => s.saleDate.isAfter(start) && s.saleDate.isBefore(end)).toList();
  }

  Future<void> markAsSynced(String id) async {}
}
