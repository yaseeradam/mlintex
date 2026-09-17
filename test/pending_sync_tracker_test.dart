import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shop_manager/core/services/pending_sync_tracker.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await PendingSyncTracker.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  test('markPending adds to pending and removes from pending delete', () {
    PendingSyncTracker.markPendingDelete('col1', 'id1');
    expect(PendingSyncTracker.isPendingDelete('col1', 'id1'), isTrue);

    PendingSyncTracker.markPending('col1', 'id1');
    expect(PendingSyncTracker.isPendingDelete('col1', 'id1'), isFalse);
    expect(PendingSyncTracker.getPendingIds('col1').contains('id1'), isTrue);
  });

  test('markPendingDelete removes from pending and adds to pending delete', () {
    PendingSyncTracker.markPending('col2', 'id2');
    expect(PendingSyncTracker.getPendingIds('col2').contains('id2'), isTrue);

    PendingSyncTracker.markPendingDelete('col2', 'id2');
    expect(PendingSyncTracker.getPendingIds('col2').contains('id2'), isFalse);
    expect(PendingSyncTracker.isPendingDelete('col2', 'id2'), isTrue);
  });

  test('markSynced removes from pending', () {
    PendingSyncTracker.markPending('col3', 'id3');
    expect(PendingSyncTracker.getPendingIds('col3').contains('id3'), isTrue);

    PendingSyncTracker.markSynced('col3', 'id3');
    expect(PendingSyncTracker.getPendingIds('col3').contains('id3'), isFalse);
  });

  test('markDeleteSynced removes from pending delete', () {
    PendingSyncTracker.markPendingDelete('col4', 'id4');
    expect(PendingSyncTracker.isPendingDelete('col4', 'id4'), isTrue);

    PendingSyncTracker.markDeleteSynced('col4', 'id4');
    expect(PendingSyncTracker.isPendingDelete('col4', 'id4'), isFalse);
  });

  test('hasPending returns correct status', () {
    expect(PendingSyncTracker.hasPending(), isFalse);
    PendingSyncTracker.markPending('c1', '1');
    expect(PendingSyncTracker.hasPending(), isTrue);
    PendingSyncTracker.markSynced('c1', '1');
    expect(PendingSyncTracker.hasPending(), isFalse);
  });
}
