import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../../core/services/firestore_service.dart';

class CustomerLocalDataSource {
  static const String _collectionName = 'customers';

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

  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => CustomerModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return CustomerModel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    final map = customer.toMap();
    map['shopId'] = _activeShopId;
    map['updatedAt'] = customer.updatedAt.toIso8601String();
    await _collection.doc(customer.id).set(map, SetOptions(merge: true));
  }

  Future<void> deleteCustomer(String id) async {
    await _collection.doc(id).delete();
  }

  Stream<List<CustomerModel>> watchCustomers() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => _matchesShop(doc.data()))
          .map((doc) => CustomerModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<CustomerModel>> getUnsyncedCustomers() async => [];
  Future<void> markAsSynced(String id) async {}
}
