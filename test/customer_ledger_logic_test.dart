import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shop_manager/domain/entities/ledger_entry.dart';
import 'package:shop_manager/presentation/ledger/ledger_provider.dart';

void main() {
  group('Customer Ledger Logic', () {
    late Directory tempDir;
    late Box<LedgerEntry> mockBox;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);
      Hive.registerAdapter(LedgerEntryAdapter());
      mockBox = await Hive.openBox<LedgerEntry>('test_ledger');
    });

    tearDown(() async {
      await mockBox.clear();
      await mockBox.close();
      await Hive.deleteFromDisk();
      await Hive.close();
    });

    test('Running balance correctly increases with sales and decreases with payments', () async {
      final entries = [
        LedgerEntry(
          id: '1',
          customerId: 'c1',
          date: DateTime(2023, 1, 1),
          inItem: 'Item 1',
          price: 100,
          quantity: 2,
          totalAmount: 200,
          typeIndex: LedgerEntryType.sale.index,
        ),
        LedgerEntry(
          id: '2',
          customerId: 'c1',
          date: DateTime(2023, 1, 2),
          outItem: 'Cash',
          totalAmount: 50,
          typeIndex: LedgerEntryType.payment.index,
        ),
        LedgerEntry(
          id: '3',
          customerId: 'c1',
          date: DateTime(2023, 1, 3),
          inItem: 'Item 2',
          price: 150,
          quantity: 1,
          totalAmount: 150,
          typeIndex: LedgerEntryType.sale.index,
        ),
        LedgerEntry(
          id: '4',
          customerId: 'c2', // different customer, should be ignored
          date: DateTime(2023, 1, 4),
          totalAmount: 500,
          typeIndex: LedgerEntryType.sale.index,
        ),
      ];

      for (var e in entries) {
        await mockBox.put(e.id, e);
      }

      final results = entriesFor(mockBox, 'c1');
      
      expect(results.length, 3);
      
      // 1st entry: Sale of 200 -> balance 200
      expect(results[0].runningBalance, 200);
      
      // 2nd entry: Payment of 50 -> balance 150
      expect(results[1].runningBalance, 150);
      
      // 3rd entry: Sale of 150 -> balance 300
      expect(results[2].runningBalance, 300);
    });
  });
}
