import 'package:hive_flutter/hive_flutter.dart';

class PendingSyncTracker {
  static const _boxName = 'pending_sync_ids';

  static Future<void> init() async {
    await Hive.openBox<List<String>>(_boxName);
  }

  static Box<List<String>> get _box => Hive.box<List<String>>(_boxName);

  /// Mark a record as needing sync.
  /// [collection] is the Firestore collection name, e.g. 'ledger_entries'
  /// [id] is the record's unique ID
  static void markPending(String collection, String id) {
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

  /// Get all IDs pending sync for a given collection
  static List<String> getPendingIds(String collection) {
    return _box.get(collection) ?? <String>[];
  }

  /// Mark all IDs in a collection as synced
  static void clearCollection(String collection) {
    _box.put(collection, <String>[]);
  }

  /// Check if there are any pending records across all collections
  static bool hasPending() {
    for (final key in _box.keys) {
      final ids = _box.get(key) ?? <String>[];
      if (ids.isNotEmpty) return true;
    }
    return false;
  }
}
