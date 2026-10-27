import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../../core/services/firestore_service.dart';

class ProductLocalDataSource {
  static const String _collectionName = 'products';

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

  Future<List<ProductModel>> getAllProducts() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => ProductModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ProductModel?> getProductById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return ProductModel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProduct(ProductModel product) async {
    final map = product.toMap();
    map['shopId'] = _activeShopId;
    map['updatedAt'] = product.updatedAt.toIso8601String();
    await _collection.doc(product.id).set(map, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
  }

  Stream<List<ProductModel>> watchProducts() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => ProductModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<ProductModel>> getUnsyncedProducts() async => [];
  Future<void> markAsSynced(String id) async {}
}
