import 'package:hive_flutter/hive_flutter.dart';

class PendingSyncTracker {
  static const _boxName = 'pending_sync_ids';
  static const _deleteBoxName = 'pending_delete_ids';

  static Future<void> init() async {
    await Hive.openBox<List<String>>(_boxName);
    await Hive.openBox<List<String>>(_deleteBoxName);
  }

  static Box<List<String>> get _box => Hive.box<List<String>>(_boxName);
  static Box<List<String>> get _deleteBox => Hive.box<List<String>>(_deleteBoxName);

  /// Mark a record as needing sync.
  /// [collection] is the Firestore collection name, e.g. 'ledger_entries'
  /// [id] is the record's unique ID
  static void markPending(String collection, String id) {
    // If it was queued for deletion, cancel deletion
    final pendingDeletes = _deleteBox.get(collection) ?? <String>[];
    if (pendingDeletes.contains(id)) {
      pendingDeletes.remove(id);
      _deleteBox.put(collection, pendingDeletes);
    }

    final existing = _box.get(collection) ?? <String>[];
    if (!existing.contains(id)) {
      _box.put(collection, [...existing, id]);
    }
  }

  /// Mark a record as synced (remove from pending list)
  static void markSynced(String collection, String id) {
    final existing = _box.get(collection) ?? <String>[];
    existing.remove(id);
    _box.put(collection, existing);
  }

  /// Mark a record as pending deletion from cloud
  static void markPendingDelete(String collection, String id) {
    final pendingUpserts = _box.get(collection) ?? <String>[];
    if (pendingUpserts.contains(id)) {
      pendingUpserts.remove(id);
      _box.put(collection, pendingUpserts);
    }

    final existing = _deleteBox.get(collection) ?? <String>[];
    if (!existing.contains(id)) {
      _deleteBox.put(collection, [...existing, id]);
    }
  }

  /// Mark a deleted record as synced with cloud
  static void markDeleteSynced(String collection, String id) {
    final existing = _deleteBox.get(collection) ?? <String>[];
    existing.remove(id);
    _deleteBox.put(collection, existing);
  }

  /// Get all IDs pending deletion for a given collection
  static List<String> getPendingDeleteIds(String collection) {
    return _deleteBox.get(collection) ?? <String>[];
  }

  /// Check if a specific item is queued for deletion
  static bool isPendingDelete(String collection, String id) {
    return getPendingDeleteIds(collection).contains(id);
  }

  /// Get all IDs pending sync for a given collection
  static List<String> getPendingIds(String collection) {
    return _box.get(collection) ?? <String>[];
  }

  /// Mark all IDs in a collection as synced
  static void clearCollection(String collection) {
    _box.put(collection, <String>[]);
    _deleteBox.put(collection, <String>[]);
  }

  /// Check if there are any pending records across all collections
  static bool hasPending() {
    for (final key in _box.keys) {
      final ids = _box.get(key) ?? <String>[];
      if (ids.isNotEmpty) return true;
    }
    for (final key in _deleteBox.keys) {
      final ids = _deleteBox.get(key) ?? <String>[];
      if (ids.isNotEmpty) return true;
    }
    return false;
  }
}
